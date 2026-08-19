import {
  Injectable,
  BadRequestException,
  NotFoundException,
  Logger,
} from '@nestjs/common';
import { InjectRepository, InjectDataSource } from '@nestjs/typeorm';
import { Repository, DataSource, LessThan } from 'typeorm';
import {
  DailyReport,
  DailyReportItem,
  LeaveRequest,
} from '../entities/index.js';
import {
  CreateDailyReportDto,
  PublicDailyReportQueryDto,
} from '../dto/daily-report.dto.js';
import { ChatService } from '../../chat/services/chat.service.js';
import { RewardsService } from '../../rewards/rewards.service.js';
import { OdooService } from '../../auth/services/odoo.service.js';
import { AuditLogService } from '../../auth/services/audit-log.service.js';
import { User } from '../../auth/entities/user.entity.js';

type StageSyncCandidate = {
  projectId: number;
  projectName: string;
  task: CreateDailyReportDto['projects'][number]['tasks'][number];
};

type ReportTaskSnapshot = {
  taskId: string;
  stageId: number | null;
  status: string | null;
};

@Injectable()
export class DailyReportService {
  private readonly logger = new Logger(DailyReportService.name);
  private readonly TARGET_CONV_ID = '35353995-517b-4fcb-b4d7-e0f23c5f4042';
  private readonly BOT_USER_ID = '00000000-0000-0000-0000-000000000001';

  constructor(
    @InjectRepository(DailyReport)
    private readonly reportRepo: Repository<DailyReport>,
    @InjectRepository(DailyReportItem)
    private readonly itemRepo: Repository<DailyReportItem>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    @InjectRepository(LeaveRequest)
    private readonly leaveRepo: Repository<LeaveRequest>,
    private readonly chatService: ChatService,
    private readonly rewardsService: RewardsService,
    private readonly odooService: OdooService,
    private readonly auditLogService: AuditLogService,
    @InjectDataSource()
    private readonly dataSource: DataSource,
  ) {}

  async submitReport(userId: string, dto: CreateDailyReportDto) {
    const today = new Date().toISOString().split('T')[0];

    // 1. Validate unique report type for today
    const existing = await this.reportRepo.findOne({
      where: {
        user_id: userId,
        report_date: today,
        report_type: dto.report_type,
      },
    });
    if (existing) {
      throw new BadRequestException(
        `You already submitted a ${dto.report_type} report for today`,
      );
    }

    // 2. Validation constraints based on type
    if (dto.report_type === 'evening') {
      const morning = await this.reportRepo.findOne({
        where: { user_id: userId, report_date: today, report_type: 'morning' },
      });
      if (!morning) {
        throw new BadRequestException(
          'Evening report requires a morning report first',
        );
      }
    }

    const user = await this.userRepo.findOneOrFail({ where: { id: userId } });
    const userRole = user.job_title || '';

    // 3. Save report and items in a transaction
    const savedReport = await this.dataSource.transaction(async (manager) => {
      const reportRepo = manager.getRepository(DailyReport);
      const itemRepo = manager.getRepository(DailyReportItem);

      const report = reportRepo.create({
        user_id: userId,
        report_date: today,
        report_type: dto.report_type,
        report_role: dto.report_role,
        projects: dto.projects,
        note: dto.note,
      });

      const saved = await reportRepo.save(report);

      const items: DailyReportItem[] = [];
      for (const project of dto.projects) {
        for (const task of project.tasks) {
          items.push(
            itemRepo.create({
              report_id: saved.id,
              task_id: String(task.id),
              task_name: task.name,
              project_id: project.project_id,
              project_name: project.project_name,
              status: task.status,
              progress: task.progress,
              qc_done: task.qc_done,
              qc_miss: task.qc_miss,
              qc_fail: task.qc_fail,
              qc_note: task.qc_note,
            }),
          );
        }
      }
      await itemRepo.save(items);
      return saved;
    });

    await this.auditLogService.logDailyReportEvent({
      type: 'daily_report.submitted',
      userId,
      reportId: savedReport.id,
      status: 'success',
      metadata: {
        reportType: dto.report_type,
        reportRole: dto.report_role,
        projectCount: dto.projects.length,
        taskCount: dto.projects.reduce(
          (sum, project) => sum + project.tasks.length,
          0,
        ),
      },
    });

    await this.syncTaskStagesToOdoo(savedReport.id, userId, today, dto);

    // 4. Trigger Rewards for Evening and OT
    let taskPointsMap:
      | Map<string, { points: number; reason?: string }>
      | undefined;
    let totalCurrentBalance = 0;
    if (dto.report_type === 'evening' || dto.report_type === 'ot') {
      const allTasks = dto.projects.flatMap((p) => p.tasks);
      const result = await this.rewardsService.applyDailyReportPoints(
        userId,
        userRole,
        savedReport.id,
        allTasks,
      );
      savedReport.total_points_earned = result.totalPoints;
      taskPointsMap = result.taskPointsMap;
      await this.reportRepo.save(savedReport);

      // Get user's current total balance after points are added
      const wallet = await this.rewardsService.getOrCreateWallet(userId);
      totalCurrentBalance = wallet.balance;
    }

    // 5. Broadcast to Chat
    await this.ensureBotSetup();
    const messageContent = this.formatReportMessage(
      user,
      dto,
      taskPointsMap,
      savedReport.total_points_earned,
      totalCurrentBalance,
    );
    const message = await this.chatService.sendMessage(this.BOT_USER_ID, {
      conv_id: this.TARGET_CONV_ID,
      content: messageContent,
      type: 'text',
      id: crypto.randomUUID(),
    });

    savedReport.chat_message_id = message.id;
    return this.reportRepo.save(savedReport);
  }

  private async syncTaskStagesToOdoo(
    reportId: string,
    userId: string,
    reportDate: string,
    dto: CreateDailyReportDto,
    trigger: 'submit' | 'update' = 'submit',
  ): Promise<void> {
    const candidates = await this.getSubmitStageSyncCandidates(
      reportId,
      userId,
      reportDate,
      dto,
      trigger,
    );
    await this.syncTaskStageCandidates(
      reportId,
      dto.report_type,
      candidates,
      trigger,
    );
  }

  private async getSubmitStageSyncCandidates(
    reportId: string,
    userId: string,
    reportDate: string,
    dto: CreateDailyReportDto,
    trigger: 'submit' | 'update',
  ): Promise<StageSyncCandidate[]> {
    const nextCandidates = this.getStageSyncCandidates(dto);
    if (dto.report_type !== 'morning') {
      return nextCandidates;
    }

    const previousTasks = await this.getPreviousReportTaskSnapshots(
      userId,
      reportDate,
    );
    if (previousTasks.size === 0) {
      return nextCandidates;
    }

    const eligibleCandidates: StageSyncCandidate[] = [];
    for (const candidate of nextCandidates) {
      const taskId = String(candidate.task.id);
      if (!previousTasks.has(taskId)) {
        eligibleCandidates.push(candidate);
        continue;
      }

      await this.logStageSyncOutcome('skipped', reportId, {
        reportId,
        reportType: dto.report_type,
        trigger,
        taskId,
        taskName: candidate.task.name,
        projectId: candidate.projectId,
        projectName: candidate.projectName,
        reason: 'carry_over_previous_report',
      });
    }

    return eligibleCandidates;
  }

  private async syncTaskStageCandidates(
    reportId: string,
    reportType: CreateDailyReportDto['report_type'],
    candidates: StageSyncCandidate[],
    trigger: 'submit' | 'update' = 'submit',
  ): Promise<void> {
    for (const candidate of candidates) {
      await this.syncTaskStageCandidate(
        reportId,
        reportType,
        candidate,
        trigger,
      );
    }
  }

  private getStageSyncCandidates(
    dto: CreateDailyReportDto,
  ): StageSyncCandidate[] {
    return dto.projects.flatMap((project) =>
      project.tasks
        .filter((task) =>
          this.shouldAdvanceTask(
            dto.report_type,
            dto.report_role,
            task.status,
          ),
        )
        .map((task) => ({
          projectId: project.project_id,
          projectName: project.project_name,
          task,
        })),
    );
  }

  private shouldAdvanceTask(
    reportType: CreateDailyReportDto['report_type'],
    reportRole: CreateDailyReportDto['report_role'],
    status?: string,
  ): boolean {
    if (reportType === 'morning') {
      return reportRole !== 'qc';
    }

    return (
      (reportType === 'evening' || reportType === 'ot') && status === 'done'
    );
  }

  private async syncTaskStageCandidate(
    reportId: string,
    reportType: CreateDailyReportDto['report_type'],
    candidate: {
      projectId: number;
      projectName: string;
      task: CreateDailyReportDto['projects'][number]['tasks'][number];
    },
    trigger: 'submit' | 'update' = 'submit',
  ): Promise<void> {
    const { projectId, projectName, task } = candidate;
    const expectedStageId = Array.isArray(task.stage_id)
      ? task.stage_id[0]
      : null;
    const taskId = Number(task.id);

    if (!Number.isFinite(taskId)) {
      await this.logStageSyncOutcome('skipped', reportId, {
        reportId,
        reportType,
        trigger,
        taskId: String(task.id),
        taskName: task.name,
        projectId,
        projectName,
        reason: 'invalid_task_id',
      });
      return;
    }

    if (expectedStageId === null) {
      await this.logStageSyncOutcome('skipped', reportId, {
        reportId,
        reportType,
        trigger,
        taskId,
        taskName: task.name,
        projectId,
        projectName,
        reason: 'missing_stage_snapshot',
      });
      return;
    }

    try {
      const liveTask = await this.odooService.fetchTaskById(taskId);
      if (!liveTask || !Array.isArray(liveTask.stage_id)) {
        await this.logStageSyncOutcome('skipped', reportId, {
          reportId,
          reportType,
          trigger,
          taskId,
          taskName: task.name,
          projectId,
          projectName,
          reason: 'missing_live_stage',
        });
        return;
      }

      const liveStageId = liveTask.stage_id[0];
      if (liveStageId !== expectedStageId) {
        await this.logStageSyncOutcome('skipped', reportId, {
          reportId,
          reportType,
          trigger,
          taskId,
          taskName: task.name,
          projectId,
          projectName,
          reason: 'stale_snapshot',
          expectedStageId,
          liveStageId,
        });
        return;
      }

      const liveProjectId = Array.isArray(liveTask.project_id)
        ? liveTask.project_id[0]
        : projectId;
      const stageDecision = await this.odooService.inspectNextTaskStage(
        liveProjectId,
        liveStageId,
      );
      if (stageDecision.status !== 'advance') {
        await this.logStageSyncOutcome('skipped', reportId, {
          reportId,
          reportType,
          trigger,
          taskId,
          taskName: task.name,
          projectId: liveProjectId,
          projectName,
          reason: stageDecision.status,
          liveStageId,
        });
        return;
      }

      const nextStage = stageDecision.nextStage;
      const advanced = await this.odooService.advanceTaskStage(
        taskId,
        nextStage.id,
      );
      if (!advanced) {
        await this.logStageSyncOutcome('skipped', reportId, {
          reportId,
          reportType,
          trigger,
          taskId,
          taskName: task.name,
          projectId: liveProjectId,
          projectName,
          reason: 'stage_write_failed',
          liveStageId,
          nextStageId: nextStage.id,
        });
        return;
      }

      await this.logStageSyncOutcome('advanced', reportId, {
        reportId,
        reportType,
        trigger,
        taskId,
        taskName: task.name,
        projectId: liveProjectId,
        projectName,
        fromStageId: liveStageId,
        toStageId: nextStage.id,
        toStageName: nextStage.name,
      });
    } catch (error) {
      this.logger.error(
        `Daily report stage sync failed ${JSON.stringify({
          reportId,
          reportType,
          taskId,
          taskName: task.name,
          projectId,
          projectName,
          error: error instanceof Error ? error.message : String(error),
        })}`,
      );
      await this.auditLogService.logDailyReportEvent({
        type: 'daily_report.stage_sync.failed',
        reportId,
        status: 'failed',
        reason: 'exception',
        metadata: {
          reportType,
          trigger,
          taskId,
          taskName: task.name,
          projectId,
          projectName,
          error: error instanceof Error ? error.message : String(error),
        },
      });
    }
  }

  private async logStageSyncOutcome(
    outcome: 'advanced' | 'skipped',
    reportId: string,
    metadata: Record<string, unknown>,
  ): Promise<void> {
    const message = `Daily report stage sync ${outcome} ${JSON.stringify(metadata)}`;
    if (outcome === 'advanced') {
      this.logger.log(message);
    } else {
      this.logger.warn(message);
    }

    await this.auditLogService.logDailyReportEvent({
      type: `daily_report.stage_sync.${outcome}`,
      reportId,
      status: outcome,
      reason: typeof metadata.reason === 'string' ? metadata.reason : undefined,
      metadata,
    });
  }

  private async ensureBotSetup() {
    // 1. Ensure Bot User exists
    let bot = await this.userRepo.findOne({ where: { id: this.BOT_USER_ID } });
    if (!bot) {
      bot = this.userRepo.create({
        id: this.BOT_USER_ID,
        name: 'Daily Report Bot',
        email: 'bot-daily-report@19t.vn',
        is_active: true,
      });
      await this.userRepo.save(bot);
    }

    // 2. Ensure Conversation exists
    const convRepo = this.dataSource.getRepository('conversations');
    const conv = await convRepo.findOne({ where: { id: this.TARGET_CONV_ID } });
    if (!conv) {
      await convRepo.insert({
        id: this.TARGET_CONV_ID,
        type: 'GROUP',
        name: 'Báo cáo hàng ngày',
        created_at: new Date(),
      });
    }

    // 3. Ensure Membership
    const memberRepo = this.dataSource.getRepository('conversation_members');
    const membership = await memberRepo.findOne({
      where: { conv_id: this.TARGET_CONV_ID, user_id: this.BOT_USER_ID },
    });
    if (!membership) {
      await memberRepo.insert({
        conv_id: this.TARGET_CONV_ID,
        user_id: this.BOT_USER_ID,
        role: 'admin',
        joined_at: new Date(),
      });
    }
  }

  async updateReport(userId: string, id: string, dto: CreateDailyReportDto) {
    const report = await this.reportRepo.findOne({
      where: { id, user_id: userId },
    });
    if (!report) throw new NotFoundException('Report not found');
    if (dto.report_type !== report.report_type) {
      throw new BadRequestException('Report type cannot be changed');
    }

    const user = await this.userRepo.findOneOrFail({ where: { id: userId } });
    const previousItems = await this.itemRepo.find({
      where: { report_id: id },
    });
    const previousProjects = report.projects;
    const previousTotalPoints = report.total_points_earned;
    const userRole = user.job_title || '';
    const updateSyncCandidates = this.getUpdateStageSyncCandidates(
      report.report_type,
      previousProjects,
      dto,
    );

    await this.ensureBotSetup();

    await this.dataSource.transaction(async (manager) => {
      const reportRepo = manager.getRepository(DailyReport);
      const itemRepo = manager.getRepository(DailyReportItem);

      report.projects = dto.projects;
      report.note = dto.note ?? report.note;
      report.report_role = dto.report_role;
      await reportRepo.save(report);

      // Re-create items
      await itemRepo.delete({ report_id: id });
      const items: DailyReportItem[] = [];
      for (const project of dto.projects) {
        for (const task of project.tasks) {
          items.push(
            itemRepo.create({
              report_id: report.id,
              task_id: String(task.id),
              task_name: task.name,
              project_id: project.project_id,
              project_name: project.project_name,
              status: task.status,
              progress: task.progress,
              qc_done: task.qc_done,
              qc_miss: task.qc_miss,
              qc_fail: task.qc_fail,
              qc_note: task.qc_note,
            }),
          );
        }
      }
      await itemRepo.save(items);
    });

    await this.auditLogService.logDailyReportEvent({
      type: 'daily_report.updated',
      userId,
      reportId: report.id,
      status: 'success',
      metadata: {
        reportType: report.report_type,
        reportRole: dto.report_role,
        previousProjectCount: this.getProjectCount(previousProjects),
        previousTaskCount: previousItems.length,
        updatedProjectCount: dto.projects.length,
        updatedTaskCount: dto.projects.reduce(
          (sum, project) => sum + project.tasks.length,
          0,
        ),
      },
    });

    await this.syncTaskStageCandidates(
      report.id,
      dto.report_type,
      updateSyncCandidates,
      'update',
    );

    let taskPointsMap:
      | Map<string, { points: number; reason?: string }>
      | undefined;
    let totalCurrentBalance = 0;
    if (dto.report_type === 'evening' || dto.report_type === 'ot') {
      try {
        const allTasks = dto.projects.flatMap((project) => project.tasks);
        const reconciliation =
          await this.rewardsService.reconcileDailyReportPoints(
            userId,
            userRole,
            report.id,
            allTasks,
          );

        report.total_points_earned = reconciliation.totalPoints;
        taskPointsMap = reconciliation.taskPointsMap;
        await this.reportRepo.save(report);

        await this.auditLogService.logDailyReportEvent({
          type: 'daily_report.reward_reconciliation.applied',
          userId,
          reportId: report.id,
          status: reconciliation.adjustedTaskCount > 0 ? 'adjusted' : 'noop',
          reason:
            reconciliation.adjustedTaskCount > 0
              ? undefined
              : 'no_reward_delta',
          metadata: {
            reportType: dto.report_type,
            previousTotalPoints,
            totalPoints: reconciliation.totalPoints,
            netDelta: reconciliation.netDelta,
            adjustedTaskCount: reconciliation.adjustedTaskCount,
          },
        });

        const wallet = await this.rewardsService.getOrCreateWallet(userId);
        totalCurrentBalance = wallet.balance;
      } catch (error) {
        await this.auditLogService.logDailyReportEvent({
          type: 'daily_report.reward_reconciliation.failed',
          userId,
          reportId: report.id,
          status: 'failed',
          reason: 'exception',
          metadata: {
            reportType: dto.report_type,
            previousTotalPoints,
            error: error instanceof Error ? error.message : String(error),
          },
        });
        throw error;
      }
    }

    // Send updated message
    const messageContent = `[Đã sửa]\n${this.formatReportMessage(
      user,
      dto,
      taskPointsMap,
      report.total_points_earned,
      totalCurrentBalance,
    )}`;
    const message = await this.chatService.sendMessage(this.BOT_USER_ID, {
      conv_id: this.TARGET_CONV_ID,
      content: messageContent,
      type: 'text',
      id: crypto.randomUUID(),
    });
    report.chat_message_id = message.id;
    return this.reportRepo.save(report);
  }

  private getProjectCount(projects: unknown): number {
    return Array.isArray(projects) ? projects.length : 0;
  }

  private getUpdateStageSyncCandidates(
    reportType: CreateDailyReportDto['report_type'],
    previousProjects: unknown,
    dto: CreateDailyReportDto,
  ): StageSyncCandidate[] {
    const previousTasks = this.flattenReportProjects(previousProjects);
    const nextCandidates = this.getStageSyncCandidates(dto);

    if (reportType === 'morning') {
      return nextCandidates.filter((candidate) => {
        const taskId = String(candidate.task.id);
        const previous = previousTasks.get(taskId);
        const nextStageId = Array.isArray(candidate.task.stage_id)
          ? candidate.task.stage_id[0]
          : null;

        return !previous || previous.stageId !== nextStageId;
      });
    }

    return nextCandidates.filter((candidate) => {
      const taskId = String(candidate.task.id);
      const previous = previousTasks.get(taskId);
      return previous?.status !== 'done';
    });
  }

  private flattenReportProjects(
    projects: unknown,
  ): Map<string, ReportTaskSnapshot> {
    const taskMap = new Map<string, ReportTaskSnapshot>();
    if (!Array.isArray(projects)) {
      return taskMap;
    }

    for (const project of projects) {
      if (typeof project !== 'object' || project === null) {
        continue;
      }

      const projectRecord = project as {
        tasks?: unknown;
      };
      if (!Array.isArray(projectRecord.tasks)) {
        continue;
      }

      for (const task of projectRecord.tasks) {
        if (typeof task !== 'object' || task === null) {
          continue;
        }

        const taskRecord = task as {
          id?: unknown;
          stage_id?: unknown;
          status?: unknown;
        };
        if (
          typeof taskRecord.id !== 'string' &&
          typeof taskRecord.id !== 'number'
        ) {
          continue;
        }

        const stageId =
          Array.isArray(taskRecord.stage_id) &&
          typeof taskRecord.stage_id[0] === 'number'
            ? taskRecord.stage_id[0]
            : null;
        const status =
          typeof taskRecord.status === 'string' ? taskRecord.status : null;

        taskMap.set(String(taskRecord.id), {
          taskId: String(taskRecord.id),
          stageId,
          status,
        });
      }
    }

    return taskMap;
  }

  private async getPreviousReportTaskSnapshots(
    userId: string,
    reportDate: string,
  ): Promise<Map<string, ReportTaskSnapshot>> {
    const previousReport = await this.reportRepo.findOne({
      where: {
        user_id: userId,
        report_date: LessThan(reportDate),
      },
      order: {
        report_date: 'DESC',
        created_at: 'DESC',
      },
    });

    return this.flattenReportProjects(previousReport?.projects);
  }

  async getTodayReports(userId: string) {
    const today = new Date().toISOString().split('T')[0];
    return this.reportRepo.find({
      where: { user_id: userId, report_date: today },
      order: { created_at: 'ASC' },
    });
  }

  async listPublicReports(query: PublicDailyReportQueryDto) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 100;
    const offset = (page - 1) * limit;

    const qb = this.reportRepo
      .createQueryBuilder('report')
      .leftJoin('report.user', 'user')
      .select([
        'report.id AS id',
        'report.user_id AS user_id',
        'user.name AS user_name',
        'report.report_date AS report_date',
        'report.report_type AS report_type',
        'report.report_role AS report_role',
        'report.projects AS projects',
        'report.note AS note',
        'report.chat_message_id AS chat_message_id',
        'report.total_points_earned AS total_points_earned',
        'report.created_at AS created_at',
        'report.updated_at AS updated_at',
      ]);

    if (query.report_type) {
      qb.andWhere('report.report_type = :reportType', {
        reportType: query.report_type,
      });
    }

    if (query.report_role) {
      qb.andWhere('report.report_role = :reportRole', {
        reportRole: query.report_role,
      });
    }

    if (query.user_id) {
      qb.andWhere('report.user_id = :userId', { userId: query.user_id });
    }

    if (query.user_name) {
      qb.andWhere('user.name ILIKE :userName', {
        userName: `%${query.user_name}%`,
      });
    }

    if (query.from_date) {
      qb.andWhere('report.report_date >= :fromDate', {
        fromDate: query.from_date,
      });
    }

    if (query.to_date) {
      qb.andWhere('report.report_date <= :toDate', {
        toDate: query.to_date,
      });
    }

    const total = await qb.getCount();
    const rows = await qb
      .orderBy('report.report_date', 'DESC')
      .addOrderBy('report.created_at', 'DESC')
      .offset(offset)
      .limit(limit)
      .getRawMany<Record<string, unknown>>();

    return {
      items: rows.map((row) => this.mapPublicReportRow(row)),
      total,
      page,
      limit,
      has_more: offset + rows.length < total,
    };
  }

  async getPublicReportById(id: string) {
    const row = await this.reportRepo
      .createQueryBuilder('report')
      .leftJoin('report.user', 'user')
      .select([
        'report.id AS id',
        'report.user_id AS user_id',
        'user.name AS user_name',
        'report.report_date AS report_date',
        'report.report_type AS report_type',
        'report.report_role AS report_role',
        'report.projects AS projects',
        'report.note AS note',
        'report.chat_message_id AS chat_message_id',
        'report.total_points_earned AS total_points_earned',
        'report.created_at AS created_at',
        'report.updated_at AS updated_at',
      ])
      .where('report.id = :id', { id })
      .getRawOne<Record<string, unknown>>();

    return row ? this.mapPublicReportRow(row) : null;
  }

  private mapPublicReportRow(row: Record<string, unknown>) {
    return {
      id: this.getStringField(row.id),
      user_id: this.getStringField(row.user_id),
      user_name: this.getOptionalStringField(row.user_name) ?? '',
      report_date: this.getStringField(row.report_date),
      report_type: this.getStringField(row.report_type),
      report_role: this.getStringField(row.report_role),
      projects: this.parseProjectsField(row.projects),
      note: typeof row.note === 'string' ? row.note : null,
      chat_message_id:
        typeof row.chat_message_id === 'string' ? row.chat_message_id : null,
      total_points_earned: Number(row.total_points_earned ?? 0),
      created_at:
        row.created_at instanceof Date
          ? row.created_at
          : new Date(this.getStringField(row.created_at)),
      updated_at:
        row.updated_at instanceof Date
          ? row.updated_at
          : new Date(this.getStringField(row.updated_at)),
    };
  }

  private getStringField(value: unknown): string {
    if (
      typeof value === 'string' ||
      typeof value === 'number' ||
      typeof value === 'boolean'
    ) {
      return String(value);
    }

    return '';
  }

  private getOptionalStringField(value: unknown): string | null {
    if (
      typeof value === 'string' ||
      typeof value === 'number' ||
      typeof value === 'boolean'
    ) {
      return String(value);
    }

    return null;
  }

  private parseProjectsField(value: unknown): unknown[] {
    if (Array.isArray(value)) {
      return value;
    }

    if (typeof value === 'string') {
      try {
        const parsed: unknown = JSON.parse(value);
        return Array.isArray(parsed) ? parsed : [];
      } catch {
        return [];
      }
    }

    return [];
  }

  private formatReportMessage(
    user: User,
    dto: CreateDailyReportDto,
    taskPointsMap?: Map<string, { points: number; reason?: string }>,
    totalPoints?: number,
    totalCurrentBalance?: number,
  ): string {
    const dateStr = new Date().toLocaleDateString('vi-VN');
    const roleLabel =
      user.job_title || (dto.report_role === 'qc' ? 'QC' : 'Developer');

    let header = '';
    if (dto.report_type === 'morning') {
      header = `📝 BÁO CÁO SÁNG - ${dateStr}`;
    } else if (dto.report_type === 'evening') {
      header = `📊 BÁO CÁO CUỐI NGÀY - ${dateStr}`;
    } else if (dto.report_type === 'ot') {
      header = `🌙 BÁO CÁO OT NGOÀI GIỜ - ${dateStr}`;
    }

    let body = `${header}\n👤 ${user.name} (${roleLabel})\n\n`;

    for (const project of dto.projects) {
      body += `📌 Dự án: ${project.project_name}\n`;
      let taskIndex = 1;
      for (const task of project.tasks) {
        const stage = task.stage_id ? ` [${task.stage_id[1]}]` : '';

        let pointText = '';
        if (
          (dto.report_type === 'evening' || dto.report_type === 'ot') &&
          taskPointsMap
        ) {
          const reward = taskPointsMap.get(String(task.id));
          const points = reward?.points ?? 0;
          const reason = reward?.reason ?? '';
          if (points > 0) {
            pointText = reason
              ? ` (+${points}p - ${reason})`
              : ` (+${points}p)`;
          } else if (reason) {
            pointText = ` (0p - ${reason})`;
          }
        }

        if (dto.report_type === 'morning') {
          body += `${taskIndex}. ${task.name}${stage}\n`;
        } else if (dto.report_role !== 'qc') {
          const statusIcon = task.status === 'done' ? '✅' : '🔄';
          const progress =
            task.status === 'doing' && task.progress !== undefined
              ? ` (${task.progress}%)`
              : '';
          const statusText = task.status === 'done' ? 'Done' : 'Doing';
          body += `${taskIndex}. ${statusIcon} ${task.name}${stage} → ${statusText}${progress}${pointText}\n`;
        } else if (dto.report_role === 'qc') {
          let qcStatus = 'Done';
          if (task.qc_miss) qcStatus = 'Miss';
          else if (task.qc_fail) qcStatus = 'Fail';

          let noteStr = '';
          if ((qcStatus === 'Miss' || qcStatus === 'Fail') && task.qc_note) {
            noteStr = `: ${task.qc_note}`;
          }

          body += `${taskIndex}. 🔍 ${task.name}${stage} → ${qcStatus}${noteStr}${pointText}\n`;
        }
        taskIndex++;
      }
      body += '\n';
    }

    if (dto.note) {
      body += `📝 Ghi chú: ${dto.note}\n`;
    }

    if (totalPoints && totalPoints > 0) {
      body += `\n💰 Cộng điểm: +${totalPoints} tim`;
      if (totalCurrentBalance && totalCurrentBalance > 0) {
        body += `\n🏆 Tổng tim hiện tại: ${totalCurrentBalance} tim`;
      }
    }

    return body.trim();
  }
}
