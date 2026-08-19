import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { InjectDataSource, InjectRepository } from '@nestjs/typeorm';
import {
  DataSource,
  EntityManager,
  In,
  MoreThan,
  QueryFailedError,
  Repository,
} from 'typeorm';
import { UserSession } from '../auth/entities/user-session.entity.js';
import { User } from '../auth/entities/user.entity.js';
import {
  PointRule,
  PointTransaction,
  RewardItem,
  RewardRedemption,
  UserPointWallet,
  PointPeriodHistory,
  OdooTaskTagConfig,
  JobTitleMultiplier,
  OdooTaskRewardLog,
  InternalRole,
  JobTitleMapping,
} from './entities/index.js';
import {
  AdminAdjustPointsDto,
  AdminGrantPointsDto,
  CreatePointRuleDto,
  CreateRedemptionDto,
  CreateRewardItemDto,
  RewardCatalogQueryDto,
  RedemptionListQueryDto,
  UpdatePointRuleDto,
  UpdateRedemptionStatusDto,
  UpdateRewardItemDto,
  CreateTaskTagConfigDto,
  UpdateTaskTagConfigDto,
  CreateJobTitleMultiplierDto,
  UpdateJobTitleMultiplierDto,
  CreateInternalRoleDto,
  UpdateInternalRoleDto,
  CreateJobTitleMappingDto,
  UpdateJobTitleMappingDto,
} from './dto/rewards.dto.js';
import { Role } from '../auth/entities/role.entity.js';
import { UserRole } from '../auth/entities/user-role.entity.js';
import { LeaveRequest } from '../hr/entities/leave-request.entity.js';
import { FirebaseService } from '../notification/services/firebase.service.js';
import { OdooService } from '../auth/services/odoo.service.js';
import { RedisPubSubService } from '../chat/services/redis-pubsub.service.js';
import { ChatService } from '../chat/services/chat.service.js';
import { TaskService } from '../task/services/task.service.js';
import { AuthService } from '../auth/services/auth.service.js';

type TransactionMutationInput = {
  userId: string;
  points: number;
  type: string;
  sourceType: string;
  sourceRefId?: string | null;
  eventKey?: string | null;
  note?: string | null;
  ruleId?: string | null;
  actorUserId?: string | null;
  metadata?: Record<string, unknown> | null;
  allowNegativeBalance?: boolean;
  skipRankingUpdate?: boolean;
  countTowardLifetimeSpent?: boolean;
  deductFromLifetimeEarned?: boolean;
};

type DailyReportTaskReward = {
  points: number;
  reason?: string;
};

type DailyReportRewardContext = {
  user: User;
  internalRoleName: string;
  roleMultiplier: number;
  tagMap: Map<string, number>;
  tagIdMap: Map<number, number>;
  multiplierMap: Map<string, number>;
  qcJobTitles: Set<string>;
  odooTagMap: Map<number, string>;
};

type DailyReportTaskRewardDecision = {
  taskId: string;
  taskName: string;
  desiredPoints: number;
  reason: string;
  metadata: Record<string, unknown>;
};
const LEADERBOARD_ROLE_NAMES = ['employee', 'manager'] as const;

export const ATTENDANCE_REWARD_TRIGGER_TYPES = [
  'attendance_checkin',
  'attendance_checkout',
  'attendance_auto_checkout',
] as const;

const REDEMPTION_REFUND_STATUSES = new Set(['rejected', 'cancelled']);

@Injectable()
export class RewardsService {
  private readonly logger = new Logger(RewardsService.name);
  private readonly DAILY_REPORT_CONV_ID =
    '35353995-517b-4fcb-b4d7-e0f23c5f4042';
  private readonly DAILY_REPORT_BOT_USER_ID =
    '00000000-0000-0000-0000-000000000001';

  constructor(
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    @InjectRepository(UserSession)
    private readonly sessionRepo: Repository<UserSession>,
    @InjectRepository(Role)
    private readonly roleRepo: Repository<Role>,
    @InjectRepository(UserRole)
    private readonly userRoleRepo: Repository<UserRole>,
    @InjectRepository(LeaveRequest)
    private readonly leaveRequestRepo: Repository<LeaveRequest>,
    @InjectRepository(UserPointWallet)
    private readonly walletRepo: Repository<UserPointWallet>,
    @InjectRepository(PointRule)
    private readonly pointRuleRepo: Repository<PointRule>,
    @InjectRepository(PointTransaction)
    private readonly pointTransactionRepo: Repository<PointTransaction>,
    @InjectRepository(PointPeriodHistory)
    private readonly pointPeriodHistoryRepo: Repository<PointPeriodHistory>,
    @InjectRepository(RewardItem)
    private readonly rewardItemRepo: Repository<RewardItem>,
    @InjectRepository(RewardRedemption)
    private readonly rewardRedemptionRepo: Repository<RewardRedemption>,
    @InjectRepository(OdooTaskTagConfig)
    private readonly taskTagConfigRepo: Repository<OdooTaskTagConfig>,
    @InjectRepository(JobTitleMultiplier)
    private readonly jobTitleMultiplierRepo: Repository<JobTitleMultiplier>,
    @InjectRepository(OdooTaskRewardLog)
    private readonly taskRewardLogRepo: Repository<OdooTaskRewardLog>,
    @InjectRepository(InternalRole)
    private readonly internalRoleRepo: Repository<InternalRole>,
    @InjectRepository(JobTitleMapping)
    private readonly jobTitleMappingRepo: Repository<JobTitleMapping>,
    @InjectDataSource()
    private readonly dataSource: DataSource,
    private readonly firebaseService: FirebaseService,
    private readonly odooService: OdooService,
    private readonly chatService: ChatService,
    private readonly redisPubSubService: RedisPubSubService,
    private readonly taskService: TaskService,
    private readonly authService: AuthService,
  ) { }

  async getMyWallet(userId: string) {
    // kiểm tra xem có phải tk admin khong
    const user = await this.getActiveUserOrThrow(userId);
    const admin = await this.roleRepo.findOne({ where: { name: 'admin' } });
    if (admin) {
      const userRole = await this.userRoleRepo.findOne({
        where: { user_id: user.id, role_id: admin.id },
      });
      if (!userRole) {
        throw new BadRequestException('Only admin can access this feature');
      }
    }
    const wallet = await this.getOrCreateWallet(userId);
    const recentTransactions = await this.pointTransactionRepo.find({
      where: { user_id: userId },
      order: { created_at: 'DESC' },
      take: 20,
    });
    return {
      ...wallet,
      recent_transactions: recentTransactions,
    };
  }

  async getTopPeriod(period?: string, limit = 2) {
    const targetPeriod = period ?? this.getActiveMonthlyLeaderboardPeriod(new Date());

    const rows = await this.pointPeriodHistoryRepo
      .createQueryBuilder('history')
      .innerJoinAndSelect('history.user', 'user')
      .where('history.period = :period', { period: targetPeriod })
      .orderBy('history.points_earned', 'DESC')
      .addOrderBy('history.created_at', 'ASC')
      .getMany();

    // Chia thành 2 nhóm: Kỹ thuật và Phòng ban khác
    const techDept = rows.filter(
      (h) =>
        h.user?.job_title === 'QC' ||
        h.user?.job_title?.includes('Fullstack Developer'),
    );
    const otherDept = rows.filter(
      (h) =>
        h.user?.job_title !== 'QC' &&
        !h.user?.job_title?.includes('Fullstack Developer'),
    );

    const mapUser = (h: typeof rows[0]) => ({
      user_id: h.user_id,
      name: h.user?.name ?? null,
      avatar_url: h.user?.avatar_url ?? null,
      points_earned: h.points_earned,
      period: h.period,
    });

    return {
      tech: techDept.slice(0, limit).map(mapUser),
      other: otherDept.slice(0, limit).map(mapUser),
    };
  }

  async getMyTransactions(userId: string, limit = 50) {
    await this.getActiveUserOrThrow(userId);
    const transactions = await this.pointTransactionRepo.find({
      where: { user_id: userId },
      order: { created_at: 'DESC' },
      take: limit,
    });
    const typeTran = transactions.map((tx) => {
      if (tx.type === 'earn') {
        return '+';
      } else if (tx.type === 'spend') {
        return '-';
      } else if (tx.type === 'adjust') {
        return '+';
      } else {
        return tx.type;
      }
    });

    return transactions.map((tx) => ({
      id: tx.id,
      type: tx.type,
      points: tx.points,
      note: tx.note,
      balance_after: tx.balance_after,
      created_at: tx.created_at,
    }));
  }

  async getOverview(limit = 20, department?: string) {
    const qb = this.userRepo
      .createQueryBuilder('user')
      .innerJoin(UserRole, 'userRole', 'userRole.user_id = user.id')
      .innerJoin(
        Role,
        'role',
        'role.id = userRole.role_id AND role.name IN (:...roleNames)',
        {
          roleNames: LEADERBOARD_ROLE_NAMES,
        },
      )
      .leftJoin(UserPointWallet, 'wallet', 'wallet.user_id = user.id')
      .select([
        'user.id AS user_id',
        'user.name AS name',
        'user.email AS email',
        'user.avatar_url AS avatar_url',
        'user.odoo_uid AS odoo_uid',
        'user.odoo_employee_id AS odoo_employee_id',
        'user.job_title AS job_title',
        'user.department AS department',
        'COALESCE(wallet.balance, 0) AS balance',
        'COALESCE(wallet.lifetime_earned, 0) AS lifetime_earned',
        'COALESCE(wallet.lifetime_spent, 0) AS lifetime_spent',
        'wallet.updated_at AS updated_at',
      ])
      .where('user.is_active = true');

    const normalizedDepartment = department?.trim();

    if (normalizedDepartment === 'Phát triển sản phẩm') {
      qb.andWhere('user.department = :department', {
        department: 'Development',
      });
    } else if (normalizedDepartment) {
      qb.andWhere('(user.department IS NULL OR user.department != :department)', {
        department: 'Development',
      });
    }

    const rows = await qb
      .orderBy(
        'COALESCE(wallet.lifetime_earned, 0) - COALESCE(wallet.lifetime_spent, 0)',
        'DESC',
      )
      .addOrderBy('COALESCE(wallet.balance, 0)', 'DESC')
      .addOrderBy('user.name', 'ASC')
      .take(limit)
      .getRawMany<{
        user_id: string;
        name: string;
        email: string;
        avatar_url: string | null;
        odoo_uid: string | null;
        odoo_employee_id: string | null;
        job_title: string | null;
        department: string | null;
        balance: string;
        lifetime_earned: string;
        lifetime_spent: string;
        updated_at: Date | null;
      }>();

    const pendingLeaveRequests = await this.leaveRequestRepo.find({
      where: { status: 'submitted' },
      relations: ['requester'],
      order: { created_at: 'DESC' },
    });
    const todayCheckinUserCount = await this.getTodayCheckinUserCount(rows);

    return {
      today_checkin_user_count: todayCheckinUserCount,
      leaderboard: rows.map((row, index) => ({
        rank: index + 1,
        user_id: row.user_id,
        name: row.name,
        email: row.email,
        avatar_url: row.avatar_url,
        job_title: row.job_title,
        department: row.department,
        balance: Number(row.balance ?? 0),
        wallet_balance: Number(row.balance ?? 0),
        ranking_points:
          Number(row.lifetime_earned ?? 0) - Number(row.lifetime_spent ?? 0),
        lifetime_earned: Number(row.lifetime_earned ?? 0),
        lifetime_spent: Number(row.lifetime_spent ?? 0),
        updated_at: row.updated_at,
      })),
      pending_leave_requests: pendingLeaveRequests.map((request) => ({
        id: request.id,
        user_id: request.user_id,
        user_name: request.requester?.name ?? null,
        user_email: request.requester?.email ?? null,
        type: request.type,
        start_date: request.start_date,
        end_date: request.end_date,
        start_time: request.start_time,
        end_time: request.end_time,
        is_half_day: request.is_half_day,
        half_day_part: request.half_day_part,
        requested_days: Number(request.requested_days ?? 0),
        reason: request.reason,
        status: request.status,
        created_at: request.created_at,
      })),
    };
  }

  private async getTodayCheckinUserCount(
    rows: Array<{ odoo_uid: string | null; odoo_employee_id: string | null }>,
  ) {
    const cacheKey = 'rewards:today_checkin_count';
    try {
      const cached = await this.redisPubSubService.getCache(cacheKey);
      if (cached !== null) {
        return parseInt(cached, 10);
      }

      const results = await Promise.all(
        rows.map(async (row) => {
          const employeeId = await this.resolveOverviewEmployeeId(row);
          if (!employeeId) return false;
          const sessions =
            await this.odooService.fetchTodayAttendance(employeeId);
          return sessions.length > 0;
        }),
      );
      const count = results.filter(Boolean).length;
      await this.redisPubSubService.setCache(cacheKey, count.toString(), 300); // 5 minutes
      return count;
    } catch (error) {
      this.logger.warn(
        `Failed to calculate today_checkin_user_count: ${String(error)}`,
      );
      return 0;
    }
  }

  private async resolveOverviewEmployeeId(row: {
    odoo_uid: string | null;
    odoo_employee_id: string | null;
  }) {
    if (row.odoo_employee_id) {
      return Number(row.odoo_employee_id);
    }
    if (!row.odoo_uid) {
      return null;
    }
    return this.odooService.findEmployeeIdByUserUidOrEmployeeId(
      Number(row.odoo_uid),
    );
  }

  async adjustPoints(adminUserId: string, dto: AdminAdjustPointsDto) {
    if (dto.points === 0) {
      throw new BadRequestException('Points adjustment cannot be zero');
    }
    await this.getActiveUserOrThrow(adminUserId);
    await this.getActiveUserOrThrow(dto.user_id);
    const result = await this.applyPointMutation({
      userId: dto.user_id,
      points: dto.points,
      type: 'adjust',
      sourceType: 'admin_manual',
      note: dto.reason.trim(),
      actorUserId: adminUserId,
    });
    await this.notifyUserPointChange(dto.user_id, {
      ...result.transaction,
      type: 'adjust',
      source_type: 'admin_manual',
      note: dto.reason.trim(),
    });
    return {
      ...result,
      recipient_total_points: result.wallet.balance,
    };
  }

  async grantPoints(adminUserId: string, dto: AdminGrantPointsDto) {
    await this.getActiveUserOrThrow(adminUserId);
    const recipientUser = await this.getActiveUserOrThrow(dto.user_id);
    const recipientName = recipientUser.name?.trim() || dto.user_id;
    const grantNote = dto.note ? dto.note : 'Admin grant points';

    console.log(
      `Admin ${adminUserId} is granting ${dto.points} points to user ${dto.user_id} with note: ${dto.note}`,
    );

    // kiểm tra xem dto.user_id không?
    const keyAdmin = await this.roleRepo.findOne({ where: { name: 'admin' } });

    const user = await this.userRoleRepo.findOne({
      where: { user_id: dto.user_id },
    });

    if (user?.role_id === keyAdmin?.id) {
      // cộng điểm cho admin nếu grant điểm dương
      if (dto.points > 0) {
        await this.applyPointMutation({
          userId: adminUserId,
          points: dto.points,
          type: 'earn',
          sourceType: 'admin_grant',
          note: dto.note ? dto.note : 'Admin tự update điểm của chính mình',
          actorUserId: adminUserId,
        });
      } else {
        throw new BadRequestException(
          'Cannot deduct points from another admin',
        );
      }
    }

    const wallet = await this.getOrCreateWallet(adminUserId);

    if (dto.points > 0) {
      if (wallet.balance < dto.points) {
        throw new BadRequestException('Admin không đủ điểm để cộng');
      } else {
        //trừ điểm của admin
        await this.applyPointMutation({
          userId: adminUserId,
          points: -dto.points,
          type: 'spend',
          sourceType: 'admin_grant',
          note: 'Admin grant points',
          actorUserId: adminUserId,
        });
      }
    } else {
      // cộng  điểm cho admin nếu grant điểm âm
      await this.applyPointMutation({
        userId: adminUserId,
        points: -dto.points,
        type: 'spend',
        sourceType: 'admin_grant',
        note: grantNote,
        actorUserId: adminUserId,
      });
    }
    const result = await this.applyPointMutation({
      userId: dto.user_id,
      points: dto.points,
      type: 'earn',
      sourceType: 'admin_grant',
      note: grantNote,
      actorUserId: adminUserId,
      deductFromLifetimeEarned: dto.points < 0,
    });

    // notify user
    await this.notifyUserPointChange(dto.user_id, {
      ...result.transaction,
      type: 'earn',
      source_type: 'admin_grant',
      note: grantNote,
    });

    try {
      await this.sendGrantPointReportMessage(
        recipientName,
        dto.points,
        grantNote,
        result.wallet.balance,
      );
    } catch (error: any) {
      this.logger.error(
        `Failed to send grant point report message: ${error.message}`,
      );
    }

    return {
      ...result,
      recipient_total_points: result.wallet.balance,
    };
  }

  async resetPoints(adminUserId: string) {
    await this.getActiveUserOrThrow(adminUserId);

    const adminRole = await this.roleRepo.findOne({ where: { name: 'admin' } });
    const adminUserIds = new Set(
      adminRole
        ? (
          await this.userRoleRepo.find({
            where: { role_id: adminRole.id },
            select: ['user_id'],
          })
        ).map((userRole) => userRole.user_id)
        : [],
    );

    const usersToReset = (
      await this.userRepo.find({
        select: ['id'],
      })
    )
      .map((user) => user.id)
      .filter((userId) => !adminUserIds.has(userId));

    const result = await this.dataSource.transaction(async (manager) => {
      const walletRepo = manager.getRepository(UserPointWallet);
      const transactionRepo = manager.getRepository(PointTransaction);
      const redemptionRepo = manager.getRepository(RewardRedemption);
      const wallets = [];
      let pointTransactionsAffected = 0;
      let rewardRedemptionsAffected = 0;

      for (const userId of usersToReset) {
        let wallet = await walletRepo.findOne({ where: { user_id: userId } });
        if (!wallet) {
          wallet = walletRepo.create({ user_id: userId });
        }

        wallet.balance = 0;
        wallet.lifetime_earned = 0;
        wallet.lifetime_spent = 0;
        wallet = await walletRepo.save(wallet);
        wallets.push(wallet);

        const transactionResult = await transactionRepo.update(
          { user_id: userId },
          {
            rule_id: null,
            created_by: adminUserId,
            source_ref_id: null,
            event_key: null,
            points: 0,
            balance_after: 0,
            note: null,
            metadata: null,
          },
        );
        const redemptionResult = await redemptionRepo.update(
          { user_id: userId },
          {
            unit_points_cost: 0,
            total_points_cost: 0,
          },
        );

        pointTransactionsAffected += transactionResult.affected ?? 0;
        rewardRedemptionsAffected += redemptionResult.affected ?? 0;
      }

      return {
        users_reset: usersToReset.length,
        user_ids: usersToReset,
        wallets,
        point_transactions_affected: pointTransactionsAffected,
        reward_redemptions_affected: rewardRedemptionsAffected,
      };
    });

    for (const userId of usersToReset) {
      await this.publishWalletSyncEvent(userId, {
        transactionId: null,
        sourceType: 'reward_points_reset',
        transactionType: 'reset',
        points: 0,
        balance: 0,
        updatedAt: new Date(),
      });
      await this.notifyUser(
        userId,
        'Điểm đã được reset',
        'Số điểm và dữ liệu điểm liên quan của bạn đã được reset về 0.',
        {
          type: 'reward_points_reset',
          user_id: userId,
        },
      );
    }

    return result;
  }

  async listEmployees() {
    const rows = await this.userRepo
      .createQueryBuilder('user')
      .innerJoin(UserRole, 'userRole', 'userRole.user_id = user.id')
      .innerJoin(
        Role,
        'role',
        'role.id = userRole.role_id AND role.name = :roleName',
        {
          roleName: 'employee',
        },
      )
      .select(['user.id AS id', 'user.name AS name'])
      .where('user.is_active = true')
      .distinct(true)
      .orderBy('user.name', 'ASC')
      .addOrderBy('user.id', 'ASC')
      .getRawMany<{ id: string; name: string }>();

    return rows.map((row) => ({
      id: row.id,
      name: row.name,
    }));
  }

  async listPointRules() {
    return this.pointRuleRepo.find({
      order: { created_at: 'ASC' },
    });
  }

  async createPointRule(adminUserId: string, dto: CreatePointRuleDto) {
    await this.getActiveUserOrThrow(adminUserId);
    const existing = await this.pointRuleRepo.findOne({
      where: { code: dto.code.trim() },
    });
    if (existing) {
      throw new BadRequestException('Point rule code already exists');
    }

    const rule = this.pointRuleRepo.create({
      code: dto.code.trim(),
      name: dto.name.trim(),
      description: dto.description?.trim() || null,
      trigger_type: dto.trigger_type.trim(),
      points: dto.points,
      is_active: dto.is_active ?? false,
      created_by: adminUserId,
    });
    return this.pointRuleRepo.save(rule);
  }

  async updatePointRule(id: string, dto: UpdatePointRuleDto) {
    const rule = await this.pointRuleRepo.findOne({ where: { id } });
    if (!rule) {
      throw new NotFoundException('Point rule not found');
    }

    if (dto.name !== undefined) rule.name = dto.name.trim();
    if (dto.description !== undefined) {
      rule.description = dto.description?.trim() || null;
    }
    if (dto.points !== undefined) rule.points = dto.points;
    if (dto.is_active !== undefined) rule.is_active = dto.is_active;

    return this.pointRuleRepo.save(rule);
  }

  async awardAttendanceEvent(
    userId: string,
    triggerType: (typeof ATTENDANCE_REWARD_TRIGGER_TYPES)[number],
    sourceRefId: string,
    metadata?: Record<string, unknown>,
  ) {
    const rule = await this.pointRuleRepo.findOne({
      where: { trigger_type: triggerType, is_active: true },
      order: { created_at: 'ASC' },
    });
    if (!rule || rule.points <= 0) {
      return { awarded: false, reason: 'no_active_rule' as const };
    }

    const eventKey = `${triggerType}:${sourceRefId}`;
    const existing = await this.pointTransactionRepo.findOne({
      where: { event_key: eventKey },
    });
    if (existing) {
      return {
        awarded: false,
        reason: 'duplicate' as const,
        transaction: existing,
      };
    }

    try {
      const result = await this.applyPointMutation({
        userId,
        points: rule.points,
        type: 'earn',
        sourceType: triggerType,
        sourceRefId,
        eventKey,
        note: rule.name,
        ruleId: rule.id,
        metadata: metadata ?? null,
      });
      await this.notifyUserPointChange(userId, {
        ...result.transaction,
        type: 'earn',
        source_type: triggerType,
        note: rule.name,
      });
      return { awarded: true, reason: 'awarded' as const, ...result };
    } catch (error) {
      if (this.isUniqueViolation(error)) {
        const duplicate = await this.pointTransactionRepo.findOne({
          where: { event_key: eventKey },
        });
        return {
          awarded: false,
          reason: 'duplicate' as const,
          transaction: duplicate,
        };
      }
      this.logger.error(
        `Failed to award attendance event ${eventKey} for user ${userId}: ${String(error)}`,
      );
      throw error;
    }
  }

  async listRewardItems(query: RewardCatalogQueryDto, isAdmin = true) {
    const qb = this.rewardItemRepo.createQueryBuilder('item');
    const shouldIncludeInactive =
      isAdmin === true && query.include_inactive === true;
    if (!shouldIncludeInactive) {
      qb.where('item.is_active = true');
    }
    qb.orderBy('item.sort_order', 'ASC').addOrderBy('item.created_at', 'ASC');
    return qb.getMany();
  }

  async createRewardItem(adminUserId: string, dto: CreateRewardItemDto) {
    await this.getActiveUserOrThrow(adminUserId);
    const stockTotal = dto.stock_total === undefined ? null : dto.stock_total;
    const item = this.rewardItemRepo.create({
      name: dto.name.trim(),
      description: dto.description?.trim() || null,
      image_url: dto.image_url?.trim() || null,
      points_cost: dto.points_cost,
      stock_total: stockTotal,
      stock_remaining: stockTotal,
      is_active: dto.is_active ?? true,
      sort_order: dto.sort_order ?? 0,
      metadata: dto.metadata ?? null,
      created_by: adminUserId,
    });
    return this.rewardItemRepo.save(item);
  }

  async updateRewardItem(id: string, dto: UpdateRewardItemDto) {
    const item = await this.rewardItemRepo.findOne({ where: { id } });
    if (!item) {
      throw new NotFoundException('Reward item not found');
    }

    if (dto.name !== undefined) item.name = dto.name.trim();
    if (dto.description !== undefined) {
      item.description = dto.description?.trim() || null;
    }
    if (dto.image_url !== undefined) {
      item.image_url = dto.image_url?.trim() || null;
    }
    if (dto.points_cost !== undefined) item.points_cost = dto.points_cost;
    if (dto.stock_total !== undefined) item.stock_total = dto.stock_total;
    if (dto.stock_remaining !== undefined) {
      item.stock_remaining = dto.stock_remaining;
    } else if (dto.stock_total !== undefined && dto.stock_total === null) {
      item.stock_remaining = null;
    }
    if (dto.is_active !== undefined) item.is_active = dto.is_active;
    if (dto.sort_order !== undefined) item.sort_order = dto.sort_order;
    if (dto.metadata !== undefined) item.metadata = dto.metadata;

    if (
      item.stock_total !== null &&
      item.stock_remaining !== null &&
      item.stock_remaining > item.stock_total
    ) {
      throw new BadRequestException(
        'stock_remaining cannot exceed stock_total',
      );
    }

    return this.rewardItemRepo.save(item);
  }

  async deleteRewardItem(adminUserId: string, id: string) {
    await this.getActiveUserOrThrow(adminUserId);

    const item = await this.rewardItemRepo.findOne({ where: { id } });
    if (!item) {
      throw new NotFoundException('Reward item not found');
    }

    await this.rewardItemRepo.delete({ id });
  }

  async redeemReward(userId: string, dto: CreateRedemptionDto) {
    const user = await this.getActiveUserOrThrow(userId);
    const quantity = dto.quantity ?? 1;

    const { redemption, transaction } = await this.dataSource.transaction(
      async (manager) => {
        const itemRepo = manager.getRepository(RewardItem);
        const redemptionRepo = manager.getRepository(RewardRedemption);
        const item = await itemRepo.findOne({
          where: { id: dto.reward_item_id },
        });
        if (!item || !item.is_active) {
          throw new BadRequestException('Reward item is unavailable');
        }

        if (item.stock_remaining !== null && item.stock_remaining < quantity) {
          throw new BadRequestException('Reward item is out of stock');
        }

        const totalCost = item.points_cost * quantity;
        const redemption = redemptionRepo.create({
          user_id: userId,
          reward_item_id: item.id,
          quantity,
          unit_points_cost: item.points_cost,
          total_points_cost: totalCost,
          status: 'pending',
          requested_note: dto.requested_note?.trim() || null,
        });
        const savedRedemption = await redemptionRepo.save(redemption);

        if (item.stock_remaining !== null) {
          item.stock_remaining -= quantity;
          await itemRepo.save(item);
        }

        const mutation = await this.applyPointMutationWithManager(manager, {
          userId,
          points: -totalCost,
          type: 'spend',
          sourceType: 'reward_redemption',
          sourceRefId: savedRedemption.id,
          eventKey: `reward_redemption:${savedRedemption.id}:spend`,
          note: `Redeemed ${item.name}`,
          metadata: {
            reward_item_id: item.id,
            quantity,
          },
        });

        return {
          redemption: await redemptionRepo.findOneOrFail({
            where: { id: savedRedemption.id },
            relations: ['reward_item'],
          }),
          transaction: mutation.transaction,
        };
      },
    );

    await this.publishWalletSyncEvent(userId, {
      transactionId: transaction.id,
      sourceType: transaction.source_type ?? 'reward_redemption',
      transactionType: transaction.type ?? 'spend',
      points: transaction.points ?? -(redemption.total_points_cost ?? 0),
      balance: transaction.balance_after ?? 0,
      updatedAt: transaction.created_at,
    });
    await this.notifyUserPointChange(userId, {
      id: transaction.id,
      type: transaction.type,
      source_type: transaction.source_type,
      points: transaction.points,
      balance_after: transaction.balance_after,
      note: transaction.note,
    });

    await this.notifyUser(
      userId,
      'Yêu cầu đổi quà đã được gửi',
      `Bạn đã gửi yêu cầu đổi ${redemption.quantity} x ${redemption.reward_item.name}.`,
      {
        type: 'reward_redemption_created',
        redemption_id: redemption.id,
        reward_item_id: redemption.reward_item_id,
        status: redemption.status,
      },
    );
    await this.notifyAdmins(
      'Có yêu cầu đổi vật phẩm',
      `${user.name ?? 'Nhân viên'} vừa gửi yêu cầu đổi ${redemption.quantity} x ${redemption.reward_item.name}.`,
      {
        type: 'reward_redemption_created',
        redemption_id: redemption.id,
        reward_item_id: redemption.reward_item_id,
        user_id: redemption.user_id,
        status: redemption.status,
      },
    );

    return redemption;
  }

  async listMyRedemptions(userId: string, query: RedemptionListQueryDto) {
    await this.getActiveUserOrThrow(userId);
    return this.listRedemptions({
      user_id: userId,
      status: query.status,
    });
  }

  async listAdminRedemptions(query: RedemptionListQueryDto) {
    return this.listRedemptions({
      status: query.status,
    });
  }

  async updateRedemptionStatus(
    adminUserId: string,
    redemptionId: string,
    dto: UpdateRedemptionStatusDto,
  ) {
    await this.getActiveUserOrThrow(adminUserId);
    const { redemption, refundTransaction } = await this.dataSource.transaction(
      async (manager) => {
        const refund = false;
        const redemptionRepo = manager.getRepository(RewardRedemption);
        const itemRepo = manager.getRepository(RewardItem);

        const redemption = await redemptionRepo.findOne({
          where: { id: redemptionId },
          relations: ['reward_item'],
        });
        if (!redemption) {
          throw new NotFoundException('Reward redemption not found');
        }

        const nextStatus = dto.status.trim();
        const prevStatus = redemption.status;
        redemption.status = nextStatus;
        redemption.processed_note = dto.processed_note?.trim() || null;
        redemption.processed_by = adminUserId;
        redemption.processed_at = new Date();
        await redemptionRepo.save(redemption);

        let refundTransaction: PointTransaction | null = null;
        if (
          REDEMPTION_REFUND_STATUSES.has(nextStatus) &&
          !REDEMPTION_REFUND_STATUSES.has(prevStatus)
        ) {
          if (redemption.reward_item.stock_remaining !== null) {
            redemption.reward_item.stock_remaining += redemption.quantity;
            await itemRepo.save(redemption.reward_item);
          }

          const refundResult = await this.applyPointMutationWithManager(
            manager,
            {
              userId: redemption.user_id,
              points: redemption.total_points_cost,
              type: 'earn',
              sourceType: 'reward_redemption_refund',
              sourceRefId: redemption.id,
              skipRankingUpdate: true,
              eventKey: `reward_redemption:${redemption.id}:refund`,
              note: `Refund for redemption ${redemption.id}`,
              actorUserId: adminUserId,
              metadata: {
                redemption_status: nextStatus,
              },
            },
          );
          refundTransaction = refundResult.transaction;
        }

        return {
          redemption: await redemptionRepo.findOneOrFail({
            where: { id: redemptionId },
            relations: ['reward_item'],
          }),
          refundTransaction,
        };
      },
    );

    if (refundTransaction) {
      await this.publishWalletSyncEvent(redemption.user_id, {
        transactionId: refundTransaction.id,
        sourceType: refundTransaction.source_type ?? 'reward_redemption_refund',
        transactionType: refundTransaction.type ?? 'earn',
        points: refundTransaction.points ?? redemption.total_points_cost,
        balance: refundTransaction.balance_after ?? 0,
        updatedAt: refundTransaction.created_at,
      });
      await this.notifyUserPointChange(redemption.user_id, {
        id: refundTransaction.id,
        type: refundTransaction.type,
        source_type: refundTransaction.source_type,
        points: refundTransaction.points,
        balance_after: refundTransaction.balance_after,
        note: refundTransaction.note,
      });
    }

    await this.notifyUser(
      redemption.user_id,
      this.getRedemptionStatusTitle(redemption.status),
      this.getRedemptionStatusBody(redemption),
      {
        type: 'reward_redemption_status_updated',
        redemption_id: redemption.id,
        reward_item_id: redemption.reward_item_id,
        status: redemption.status,
      },
    );

    return redemption;
  }

  private async listRedemptions(filter: { user_id?: string; status?: string }) {
    const qb = this.rewardRedemptionRepo
      .createQueryBuilder('redemption')
      .leftJoinAndSelect('redemption.reward_item', 'item')
      .orderBy('redemption.created_at', 'DESC');

    if (filter.user_id) {
      qb.andWhere('redemption.user_id = :userId', { userId: filter.user_id });
    }
    if (filter.status) {
      qb.andWhere('redemption.status = :status', {
        status: filter.status,
      });
    }
    const results = await qb.getMany();

    const findUserNames = new Set(results.map((r) => r.user_id));
    const users = await this.userRepo.find({
      where: { id: In(Array.from(findUserNames)) },
      select: ['id', 'name', 'email'],
    });
    const userMap = new Map(users.map((u) => [u.id, u]));

    return results.map((redemption) => ({
      id: redemption.id,
      user: userMap.get(redemption.user_id) || {
        id: redemption.user_id,
        name: 'Unknown User',
        email: null,
      },
      quantity: redemption.quantity,
      unit_points_cost: redemption.unit_points_cost,
      total_points_cost: redemption.total_points_cost,
      status: redemption.status,
      created_at: redemption.created_at,
      reward_item: {
        name: redemption.reward_item.name,
        points_cost: redemption.reward_item.points_cost,
        stock_total: redemption.reward_item.stock_total,
        stock_remaining: redemption.reward_item.stock_remaining,
      },
    }));
  }

  async getYearlyLeaderboard(year?: number, limit = 20) {
    const now = new Date();
    const targetYear = year ?? now.getFullYear();
    const periodPrefix = `${targetYear}-%`;

    const rows = await this.userRepo
      .createQueryBuilder('user')
      .innerJoin(UserRole, 'userRole', 'userRole.user_id = user.id')
      .innerJoin(
        Role,
        'role',
        'role.id = userRole.role_id AND role.name = :roleName',
        { roleName: 'employee' },
      )
      .leftJoin(UserPointWallet, 'wallet', 'wallet.user_id = user.id')
      .leftJoin(
        (subQuery) => {
          return subQuery
            .select('history.user_id', 'user_id')
            .addSelect('SUM(history.points_earned)', 'historical_points')
            .from(PointPeriodHistory, 'history')
            .where('history.period LIKE :periodPrefix', { periodPrefix })
            .groupBy('history.user_id');
        },
        'yearly_stats',
        'yearly_stats.user_id = user.id',
      )
      .select([
        'user.id AS user_id',
        'user.name AS name',
        'user.avatar_url AS avatar_url',
        'user.email AS email',
        '(COALESCE(yearly_stats.historical_points, 0) + CASE WHEN :isCurrentYear THEN COALESCE(wallet.lifetime_earned, 0) ELSE 0 END) AS yearly_points',
      ])
      .setParameters({
        periodPrefix,
        isCurrentYear: targetYear === now.getFullYear(),
      })
      .where('user.is_active = true')
      .orderBy(
        '(COALESCE(yearly_stats.historical_points, 0) + CASE WHEN :isCurrentYear THEN COALESCE(wallet.lifetime_earned, 0) ELSE 0 END)',
        'DESC',
      )
      .addOrderBy('user.name', 'ASC')
      .take(limit)
      .getRawMany();

    return rows.map((row) => ({
      ...row,
      yearly_points: Number(row.yearly_points),
    }));
  }

  async getMonthlyLeaderboard(year?: number, month?: number, limit = 20) {
    const now = new Date();
    const activePeriod = this.getActiveMonthlyLeaderboardPeriod(now);
    const targetPeriod = this.resolveTargetMonthlyPeriod(now, year, month);
    const isActivePeriod = targetPeriod === activePeriod;

    const rows = await this.userRepo
      .createQueryBuilder('user')
      .innerJoin(UserRole, 'userRole', 'userRole.user_id = user.id')
      .innerJoin(
        Role,
        'role',
        'role.id = userRole.role_id AND role.name IN (:...roleNames)',
        {
          roleNames: LEADERBOARD_ROLE_NAMES,
        },
      )
      .leftJoin(UserPointWallet, 'wallet', 'wallet.user_id = user.id')
      .leftJoin(
        PointPeriodHistory,
        'history',
        'history.user_id = user.id AND history.period = :targetPeriod',
        {
          targetPeriod,
        },
      )
      .select([
        'user.id AS user_id',
        'user.name AS name',
        'user.avatar_url AS avatar_url',
        'user.email AS email',
        'COALESCE(wallet.balance, 0) AS wallet_balance',
        `${isActivePeriod ? 'COALESCE(wallet.lifetime_earned, 0)' : 'COALESCE(history.points_earned, 0)'} AS ranking_points`,
      ])
      .where('user.is_active = true')
      .orderBy('ranking_points', 'DESC')
      .addOrderBy('COALESCE(wallet.balance, 0)', 'DESC')
      .addOrderBy('user.name', 'ASC')
      .take(limit)
      .getRawMany<{
        user_id: string;
        name: string;
        avatar_url: string | null;
        email: string;
        wallet_balance: string;
        ranking_points: string;
      }>();

    return {
      period: targetPeriod,
      is_active_period: isActivePeriod,
      leaderboard: rows.map((row, index) => ({
        rank: index + 1,
        user_id: row.user_id,
        name: row.name,
        email: row.email,
        avatar_url: row.avatar_url,
        ranking_points: Number(row.ranking_points ?? 0),
        wallet_balance: Number(row.wallet_balance ?? 0),
      })),
    };
  }

  async snapshotMonthlyPoints() {
    const now = new Date();
    // Since we reset on the 25th of every month, we label the period
    // using the current year and month (the cycle that ends today).
    const period = `${now.getFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, '0')}`;

    this.logger.log(`Starting monthly points snapshot for period: ${period}`);

    await this.dataSource.transaction(async (manager) => {
      const walletRepo = manager.getRepository(UserPointWallet);
      const historyRepo = manager.getRepository(PointPeriodHistory);

      const wallets = await walletRepo.find({
        where: [
          { lifetime_earned: MoreThan(0) },
          { lifetime_spent: MoreThan(0) },
        ],
      });

      for (const wallet of wallets) {
        // Save to history
        if (wallet.lifetime_earned > 0) {
          await historyRepo.save({
            user_id: wallet.user_id,
            period,
            points_earned: wallet.lifetime_earned,
          });
        }

        // Reset monthly earned/deducted counters for the new month.
        wallet.lifetime_earned = 0;
        wallet.lifetime_spent = 0;
        await walletRepo.save(wallet);
      }
    });

    this.logger.log(`Monthly points snapshot completed for period: ${period}`);
  }

  private getActiveMonthlyLeaderboardPeriod(date: Date) {
    const year = date.getFullYear();
    const month = date.getMonth() + 1;

    if (date.getDate() >= 25) {
      const nextMonth = month === 12 ? 1 : month + 1;
      const nextYear = month === 12 ? year + 1 : year;
      return `${nextYear}-${String(nextMonth).padStart(2, '0')}`;
    }

    return `${year}-${String(month).padStart(2, '0')}`;
  }

  private resolveTargetMonthlyPeriod(date: Date, year?: number, month?: number) {
    if (year !== undefined && month !== undefined) {
      return `${year}-${String(month).padStart(2, '0')}`;
    }

    return this.getActiveMonthlyLeaderboardPeriod(date);
  }

  async getOrCreateWallet(userId: string) {
    let wallet = await this.walletRepo.findOne({ where: { user_id: userId } });
    if (!wallet) {
      wallet = this.walletRepo.create({ user_id: userId });
      wallet = await this.walletRepo.save(wallet);
    }
    return wallet;
  }

  private async getActiveUserOrThrow(userId: string) {
    const user = await this.userRepo.findOne({
      where: { id: userId, is_active: true },
    });
    if (!user) {
      throw new NotFoundException('User not found');
    }
    return user;
  }

  private async notifyAdmins(
    title: string,
    body: string,
    data: Record<string, string>,
  ) {
    const adminRole = await this.roleRepo.findOne({ where: { name: 'admin' } });
    if (!adminRole) return;
    const adminUserRoles = await this.userRoleRepo.find({
      where: { role_id: adminRole.id },
    });
    for (const adminUserRole of adminUserRoles) {
      await this.notifyUser(adminUserRole.user_id, title, body, data);
    }
  }

  private async notifyUser(
    userId: string,
    title: string,
    body: string,
    data: Record<string, string>,
  ) {
    if (!this.firebaseService.isEnabled()) return;
    const sessions = await this.sessionRepo.find({
      where: { user_id: userId },
      select: ['id', 'fcm_token'],
    });
    for (const session of sessions) {
      if (!session.fcm_token) continue;
      try {
        await this.firebaseService.sendPush(
          session.fcm_token,
          title,
          body,
          data,
        );
      } catch (err: any) {
        this.logger.error(
          `Failed to send rewards push notification to session ${session.id}: ${err.message}`,
        );
      }
    }
  }

  private async notifyUserPointChange(
    userId: string,
    transaction: Pick<
      PointTransaction,
      'id' | 'type' | 'source_type' | 'points' | 'balance_after' | 'note'
    >,
  ) {
    const pointDelta =
      transaction.points > 0
        ? `+${transaction.points}`
        : `${transaction.points}`;
    await this.notifyUser(
      userId,
      this.getPointNotificationTitle(transaction),
      `${pointDelta} Điểm. Số dư hiện tại: ${transaction.balance_after} tim.`,
      {
        type: 'reward_points_changed',
        transaction_id: transaction.id,
        source_type: transaction.source_type,
        transaction_type: transaction.type,
        points: String(transaction.points),
        balance_after: String(transaction.balance_after),
      },
    );
  }

  private async ensureDailyReportBotSetup() {
    let bot = await this.userRepo.findOne({
      where: { id: this.DAILY_REPORT_BOT_USER_ID },
    });
    if (!bot) {
      bot = this.userRepo.create({
        id: this.DAILY_REPORT_BOT_USER_ID,
        name: 'Daily Report Bot',
        email: 'bot-daily-report@19t.vn',
        is_active: true,
      });
      await this.userRepo.save(bot);
    }

    const convRepo = this.dataSource.getRepository('conversations');
    const conv = await convRepo.findOne({
      where: { id: this.DAILY_REPORT_CONV_ID },
    });
    if (!conv) {
      await convRepo.insert({
        id: this.DAILY_REPORT_CONV_ID,
        type: 'GROUP',
        name: 'Báo cáo hàng ngày',
        created_at: new Date(),
      });
    }

    const memberRepo = this.dataSource.getRepository('conversation_members');
    const membership = await memberRepo.findOne({
      where: {
        conv_id: this.DAILY_REPORT_CONV_ID,
        user_id: this.DAILY_REPORT_BOT_USER_ID,
      },
    });
    if (!membership) {
      await memberRepo.insert({
        conv_id: this.DAILY_REPORT_CONV_ID,
        user_id: this.DAILY_REPORT_BOT_USER_ID,
        role: 'admin',
        joined_at: new Date(),
      });
    }
  }

  private formatGrantPointReportMessage(
    recipientName: string,
    points: number,
    reason: string,
    totalPoints: number,
  ) {
    const dateStr = new Date().toLocaleDateString('vi-VN');
    const pointText = points > 0 ? `+${points}` : `${points}`;

    return [
      `Cập nhập điểm - ${dateStr}`,
      `Nhân sự: ${recipientName}`,
      `Số tim: ${pointText}`,
      `Tổng điểm hiện tại: ${totalPoints}`,
      `Lý do: ${reason}`,
    ].join('\n');
  }

  private async sendGrantPointReportMessage(
    recipientName: string,
    points: number,
    reason: string,
    totalPoints: number,
  ) {
    await this.ensureDailyReportBotSetup();
    await this.chatService.sendMessage(this.DAILY_REPORT_BOT_USER_ID, {
      conv_id: this.DAILY_REPORT_CONV_ID,
      content: this.formatGrantPointReportMessage(
        recipientName,
        points,
        reason,
        totalPoints,
      ),
      type: 'text',
      id: crypto.randomUUID(),
    });
  }

  private async publishWalletSyncEvent(
    userId: string,
    payload: {
      transactionId: string | null;
      sourceType: string;
      transactionType: string;
      points: number;
      balance: number;
      updatedAt?: Date | null;
    },
  ) {
    try {
      await this.redisPubSubService.publishUserEvent(userId, {
        _event: 'reward_points_changed',
        transaction_id: payload.transactionId,
        source_type: payload.sourceType,
        transaction_type: payload.transactionType,
        points: payload.points,
        balance: payload.balance,
        updated_at: (payload.updatedAt ?? new Date()).toISOString(),
      });
    } catch (error) {
      this.logger.warn(
        `Failed to publish reward_points_changed for user ${userId}: ${String(error)}`,
      );
    }
  }

  private getPointNotificationTitle(
    transaction: Pick<PointTransaction, 'type' | 'source_type' | 'note'>,
  ) {
    if (transaction.source_type === 'admin_grant') {
      return 'Bạn vừa được cộng điểm';
    }
    if (transaction.source_type === 'admin_manual') {
      return transaction.type === 'adjust' && transaction.note
        ? transaction.note
        : 'Số điểm của bạn vừa được điều chỉnh';
    }
    if (transaction.source_type === 'reward_redemption') {
      return 'Bạn vừa đổi quà thành công';
    }
    if (transaction.source_type === 'reward_redemption_refund') {
      return 'Điểm đổi quà đã được hoàn lại';
    }
    return transaction.note?.trim() || 'Số điểm của bạn vừa được thay đổi';
  }

  private getRedemptionStatusTitle(status: string) {
    switch (status) {
      case 'approved':
        return 'Yêu cầu đổi quà đã được duyệt';
      case 'rejected':
        return 'Yêu cầu đổi quà bị từ chối';
      case 'cancelled':
        return 'Yêu cầu đổi quà đã bị hủy';
      default:
        return 'Trạng thái đổi quà đã được cập nhật';
    }
  }

  private getRedemptionStatusBody(
    redemption: Pick<
      RewardRedemption,
      'status' | 'quantity' | 'total_points_cost' | 'processed_note'
    > & { reward_item: Pick<RewardItem, 'name'> },
  ) {
    const itemText = `${redemption.quantity} x ${redemption.reward_item.name}`;
    if (redemption.status === 'approved') {
      return `Yêu cầu đổi ${itemText} đã được duyệt.`;
    }
    if (redemption.status === 'rejected' || redemption.status === 'cancelled') {
      const note = redemption.processed_note?.trim();
      return note
        ? `Yêu cầu đổi ${itemText} không được chấp nhận. ${redemption.total_points_cost} điểm đã được hoàn. Lý do: ${note}`
        : `Yêu cầu đổi ${itemText} không được chấp nhận. ${redemption.total_points_cost} điểm đã được hoàn.`;
    }
    return `Yêu cầu đổi ${itemText} đã chuyển sang trạng thái ${redemption.status}.`;
  }

  private async applyPointMutation(input: TransactionMutationInput) {
    const result = await this.dataSource.transaction((manager) =>
      this.applyPointMutationWithManager(manager, input),
    );

    if (!result.duplicate) {
      await this.publishWalletSyncEvent(input.userId, {
        transactionId: result.transaction.id,
        sourceType: result.transaction.source_type ?? input.sourceType,
        transactionType: result.transaction.type ?? input.type,
        points: result.transaction.points ?? input.points,
        balance: result.transaction.balance_after ?? result.wallet.balance,
        updatedAt: result.transaction.created_at ?? result.wallet.updated_at,
      });
      await this.redisPubSubService.publishGlobalRewardUpdate();
    }

    return result;
  }

  async applyPointMutationWithManager(
    manager: EntityManager,
    input: TransactionMutationInput,
  ) {
    const walletRepo = manager.getRepository(UserPointWallet);
    const transactionRepo = manager.getRepository(PointTransaction);

    if (input.eventKey) {
      const existing = await transactionRepo.findOne({
        where: { event_key: input.eventKey },
      });
      if (existing) {
        const existingWallet =
          (await walletRepo.findOne({ where: { user_id: input.userId } })) ??
          walletRepo.create({ user_id: input.userId });
        return {
          wallet: existingWallet,
          transaction: existing,
          duplicate: true,
        };
      }
    }

    let wallet = await walletRepo.findOne({ where: { user_id: input.userId } });
    if (!wallet) {
      wallet = walletRepo.create({ user_id: input.userId });
      wallet = await walletRepo.save(wallet);
    }

    const nextBalance = wallet.balance + input.points;
    if (!input.allowNegativeBalance && nextBalance < 0) {
      throw new BadRequestException('Insufficient points balance');
    }

    const shouldCountTowardLifetimeSpent =
      input.countTowardLifetimeSpent ?? input.type === 'adjust';

    wallet.balance = nextBalance;
    if (!input.skipRankingUpdate) {
      if (input.points > 0) {
        wallet.lifetime_earned += input.points;
      } else if (input.points < 0 && input.deductFromLifetimeEarned) {
        wallet.lifetime_earned = Math.max(
          0,
          wallet.lifetime_earned + input.points,
        );
      } else if (input.points < 0 && shouldCountTowardLifetimeSpent) {
        wallet.lifetime_spent += Math.abs(input.points);
      }
    }
    wallet = await walletRepo.save(wallet);

    const transaction = transactionRepo.create({
      user_id: input.userId,
      rule_id: input.ruleId ?? null,
      created_by: input.actorUserId ?? null,
      type: input.type,
      source_type: input.sourceType,
      source_ref_id: input.sourceRefId ?? null,
      event_key: input.eventKey ?? null,
      points: input.points,
      balance_after: wallet.balance,
      note: input.note ?? null,
      metadata: input.metadata ?? null,
    });

    const savedTransaction = await transactionRepo.save(transaction);
    return { wallet, transaction: savedTransaction, duplicate: false };
  }

  private isUniqueViolation(error: unknown) {
    return (
      error instanceof QueryFailedError &&
      (error as QueryFailedError & { driverError?: { code?: string } })
        .driverError?.code === '23505'
    );
  }

  // --- Odoo Task Tag Config ---

  async listTaskTagConfigs(): Promise<OdooTaskTagConfig[]> {
    return this.taskTagConfigRepo.find({ order: { tag_name: 'ASC' } });
  }

  async createTaskTagConfig(
    dto: CreateTaskTagConfigDto,
  ): Promise<OdooTaskTagConfig> {
    try {
      const config = this.taskTagConfigRepo.create(dto);
      return await this.taskTagConfigRepo.save(config);
    } catch (err: any) {
      if (this.isUniqueViolation(err)) {
        throw new BadRequestException(`Tag "${dto.tag_name}" already exists`);
      }
      throw err;
    }
  }

  async updateTaskTagConfig(
    id: number,
    dto: UpdateTaskTagConfigDto,
  ): Promise<OdooTaskTagConfig> {
    const config = await this.taskTagConfigRepo.findOne({ where: { id } });
    if (!config) throw new NotFoundException('Tag config not found');

    if (dto.tag_name) config.tag_name = dto.tag_name;
    if (dto.base_points !== undefined) config.base_points = dto.base_points;

    try {
      return await this.taskTagConfigRepo.save(config);
    } catch (err: any) {
      if (this.isUniqueViolation(err)) {
        throw new BadRequestException(`Tag "${dto.tag_name}" already exists`);
      }
      throw err;
    }
  }

  async deleteTaskTagConfig(id: number): Promise<void> {
    const result = await this.taskTagConfigRepo.delete(id);
    if (!result.affected) throw new NotFoundException('Tag config not found');
  }

  // --- Job Title Multiplier ---

  async listJobTitleMultipliers(): Promise<JobTitleMultiplier[]> {
    return this.jobTitleMultiplierRepo.find({ order: { job_title: 'ASC' } });
  }

  async createJobTitleMultiplier(
    dto: CreateJobTitleMultiplierDto,
  ): Promise<JobTitleMultiplier> {
    try {
      const config = this.jobTitleMultiplierRepo.create(dto);
      return await this.jobTitleMultiplierRepo.save(config);
    } catch (err: any) {
      if (this.isUniqueViolation(err)) {
        throw new BadRequestException(
          `Job title "${dto.job_title}" already exists`,
        );
      }
      throw err;
    }
  }

  async updateJobTitleMultiplier(
    id: string,
    dto: UpdateJobTitleMultiplierDto,
  ): Promise<JobTitleMultiplier> {
    const config = await this.jobTitleMultiplierRepo.findOne({ where: { id } });
    if (!config) throw new NotFoundException('Job title multiplier not found');

    if (dto.job_title) config.job_title = dto.job_title;
    if (dto.multiplier !== undefined) config.multiplier = dto.multiplier;

    try {
      return await this.jobTitleMultiplierRepo.save(config);
    } catch (err: any) {
      if (this.isUniqueViolation(err)) {
        throw new BadRequestException(
          `Job title "${dto.job_title}" already exists`,
        );
      }
      throw err;
    }
  }

  async deleteJobTitleMultiplier(id: string): Promise<void> {
    const result = await this.jobTitleMultiplierRepo.delete(id);
    if (!result.affected)
      throw new NotFoundException('Job title multiplier not found');
  }

  // --- Internal Role & Job Title Mapping ---

  async listInternalRoles(): Promise<InternalRole[]> {
    return this.internalRoleRepo.find({ order: { name: 'ASC' } });
  }

  async createInternalRole(dto: CreateInternalRoleDto): Promise<InternalRole> {
    try {
      const role = this.internalRoleRepo.create(dto);
      return await this.internalRoleRepo.save(role);
    } catch (err: any) {
      if (this.isUniqueViolation(err)) {
        throw new BadRequestException(`Role "${dto.name}" already exists`);
      }
      throw err;
    }
  }

  async updateInternalRole(
    id: string,
    dto: UpdateInternalRoleDto,
  ): Promise<InternalRole> {
    const role = await this.internalRoleRepo.findOne({ where: { id } });
    if (!role) throw new NotFoundException('Internal role not found');

    if (dto.name) role.name = dto.name;
    if (dto.multiplier !== undefined) role.multiplier = dto.multiplier;

    try {
      return await this.internalRoleRepo.save(role);
    } catch (err: any) {
      if (this.isUniqueViolation(err)) {
        throw new BadRequestException(`Role "${dto.name}" already exists`);
      }
      throw err;
    }
  }

  async deleteInternalRole(id: string): Promise<void> {
    const result = await this.internalRoleRepo.delete(id);
    if (!result.affected)
      throw new NotFoundException('Internal role not found');
  }

  async listJobTitleMappings(): Promise<JobTitleMapping[]> {
    return this.jobTitleMappingRepo.find({
      relations: ['internal_role'],
      order: { job_title: 'ASC' },
    });
  }

  async createJobTitleMapping(
    dto: CreateJobTitleMappingDto,
  ): Promise<JobTitleMapping> {
    try {
      const mapping = this.jobTitleMappingRepo.create(dto);
      return await this.jobTitleMappingRepo.save(mapping);
    } catch (err: any) {
      if (this.isUniqueViolation(err)) {
        throw new BadRequestException(
          `Mapping for "${dto.job_title}" already exists`,
        );
      }
      throw err;
    }
  }

  async updateJobTitleMapping(
    id: string,
    dto: UpdateJobTitleMappingDto,
  ): Promise<JobTitleMapping> {
    const mapping = await this.jobTitleMappingRepo.findOne({ where: { id } });
    if (!mapping) throw new NotFoundException('Mapping not found');

    if (dto.job_title) mapping.job_title = dto.job_title;
    if (dto.internal_role_id) mapping.internal_role_id = dto.internal_role_id;

    try {
      return await this.jobTitleMappingRepo.save(mapping);
    } catch (err: any) {
      if (this.isUniqueViolation(err)) {
        throw new BadRequestException(
          `Mapping for "${dto.job_title}" already exists`,
        );
      }
      throw err;
    }
  }

  async deleteJobTitleMapping(id: string): Promise<void> {
    const result = await this.jobTitleMappingRepo.delete(id);
    if (!result.affected) throw new NotFoundException('Mapping not found');
  }

  async discoverUnmappedJobTitles(): Promise<string[]> {
    // Get all unique job titles from users table
    const users = await this.userRepo
      .createQueryBuilder('user')
      .select('DISTINCT user.job_title', 'job_title')
      .where('user.job_title IS NOT NULL')
      .getRawMany();

    const currentJobTitles = users.map((u) => u.job_title);

    // Get all mapped job titles
    const mappings = await this.jobTitleMappingRepo.find({
      select: ['job_title'],
    });
    const mappedJobTitles = new Set(mappings.map((m) => m.job_title));

    // Return unmapped ones
    return currentJobTitles.filter((title) => !mappedJobTitles.has(title));
  }

  async getJobTitleOverview(): Promise<any[]> {
    // 1. Get unique job titles and counts from users
    const userStats = await this.userRepo
      .createQueryBuilder('user')
      .select('user.job_title', 'job_title')
      .addSelect('COUNT(user.id)', 'user_count')
      .where('user.job_title IS NOT NULL')
      .groupBy('user.job_title')
      .getRawMany();

    // 2. Get all mappings
    const mappings = await this.jobTitleMappingRepo.find({
      relations: ['internal_role'],
    });
    const mappingMap = new Map(mappings.map((m) => [m.job_title, m]));

    // 3. Combine
    return userStats.map((stat) => {
      const mapping = mappingMap.get(stat.job_title);
      return {
        job_title: stat.job_title,
        user_count: Number(stat.user_count),
        is_mapped: !!mapping,
        internal_role: mapping
          ? {
            id: mapping.internal_role.id,
            name: mapping.internal_role.name,
            multiplier: Number(mapping.internal_role.multiplier),
          }
          : null,
        mapping_id: mapping?.id || null,
      };
    });
  }

  async syncOdooJobTitles(): Promise<any> {
    this.logger.log('Manually syncing users/job titles from Odoo...');
    return this.authService.syncUsersFromOdoo();
  }

  // --- Odoo Task Reward Automation ---

  async syncOdooTaskTags(): Promise<OdooTaskTagConfig[]> {
    this.logger.log('Syncing Odoo task tags...');
    const odooTags = await this.odooService.fetchProjectTags();
    this.logger.log(`Found ${odooTags.length} tags on Odoo`);

    const syncedConfigs: OdooTaskTagConfig[] = [];

    for (const odooTag of odooTags) {
      let config = await this.taskTagConfigRepo.findOne({
        where: { tag_name: odooTag.name },
      });
      if (!config) {
        config = this.taskTagConfigRepo.create({
          id: odooTag.id,
          tag_name: odooTag.name,
          base_points: 0,
        });
        config = await this.taskTagConfigRepo.save(config);
        this.logger.log(`Created new tag config for "${odooTag.name}"`);
      }
      syncedConfigs.push(config);
    }

    return syncedConfigs;
  }

  async processOdooTaskRewards(): Promise<any> {
    // laay danh sach stage tu Odoo, loc ra stage "STAGING", lay id stage do
    const stages = await this.odooService.fetchTaskStages();
    // console.log(`Fetched stages: ${stages}`);
    const stagingStageIds = stages
      .filter((s) => s.name.toLocaleLowerCase() === 'staging')
      .map((s) => s.id);

    if (stagingStageIds.length === 0) {
      return { message: 'No STAGING stages found' };
    }
    console.log(`stagingStageIds: ${stagingStageIds}`);

    // // Fetch all Odoo tags to map IDs to names
    const odooTags = await this.odooService.fetchProjectTags();
    const odooTagMap = new Map(odooTags.map((t) => [t.id, t.name]));

    odooTagMap.forEach((name, id) => {
      this.logger.debug(`Odoo tag - ID ${id}: "${name}"`);
    });

    this.logger.log(
      `Fetching tasks for staging stages: ${stagingStageIds.join(', ')}`,
    );

    //----

    const tasks = await this.odooService.fetchTasksByStageIds(stagingStageIds);
    this.logger.log(`Found ${tasks.length} tasks in STAGING`);

    //----

    // Load configs for efficient lookups
    const tagConfigs = await this.taskTagConfigRepo.find();
    const tagMap = new Map(tagConfigs.map((c) => [c.tag_name, c.base_points]));
    const tagIdMap = new Map(tagConfigs.map((c) => [c.id, c.base_points]));

    // console.log(`Loaded tag configs: ${tagMap.size} entries`);
    tagMap.forEach((points, tag) => {
      this.logger.debug(`Tag config - "${tag}": ${points} points`);
    });

    // Load internal role multipliers and job title mappings
    const mappings = await this.jobTitleMappingRepo.find({
      relations: ['internal_role'],
    });
    const multiplierMap = new Map(
      mappings.map((m) => [m.job_title, Number(m.internal_role.multiplier)]),
    );

    multiplierMap.forEach((multiplier, jobTitle) => {
      this.logger.debug(`Job title multiplier - "${jobTitle}": ${multiplier}x`);
    });

    const processed = [];
    for (const task of tasks) {
      try {
        const rewarded = await this.processSingleTaskReward(
          task,
          tagMap,
          tagIdMap,
          multiplierMap,
          odooTagMap,
        );
        if (rewarded) processed.push(task.id);
      } catch (err: any) {
        this.logger.error(
          `Failed to process reward for task ${task.id}: ${err}`,
        );
      }
    }

    return {
      total_tasks_found: tasks.length,
      processed_count: processed.length,
      processed_task_ids: processed,
    };
  }

  private calculateTaskPoints(
    task: any,
    user: User,
    tagMap: Map<string, number>,
    tagIdMap: Map<number, number>,
    multiplierMap: Map<string, number>,
    odooTagMap: Map<number, string>,
    options: { applyPenalty?: boolean; isDailyReport?: boolean } = {},
  ): {
    finalPoints: number;
    basePoints: number;
    multiplier: number;
    penalty: number;
    isMiss: boolean;
  } {
    let basePoints = 0;
    let foundTag = false;
    const tagIds = task.tag_ids || [];
    let isMiss = false;

    for (const tagId of tagIds) {
      if (tagIdMap.has(tagId)) {
        basePoints = Math.max(basePoints, tagIdMap.get(tagId) || 0);
        foundTag = true;
      }

      const tagName = odooTagMap.get(tagId);
      if (!tagName) continue;

      if (tagName.toLowerCase() === 'qc miss') {
        isMiss = true;
      }

      if (tagMap.has(tagName)) {
        basePoints = Math.max(basePoints, tagMap.get(tagName) || 0);
        foundTag = true;
      }
    }

    if (!foundTag) {
      return {
        finalPoints: 0,
        basePoints: 0,
        multiplier: 1,
        penalty: 1,
        isMiss: false,
      };
    }

    const multiplier = multiplierMap.get(user.job_title || '') || 1.0;
    const penalty = options.applyPenalty !== false && isMiss ? 0.5 : 1.0;
    const finalPoints = Math.round(basePoints * multiplier * penalty);

    return { finalPoints, basePoints, multiplier, penalty, isMiss };
  }

  async applyDailyReportPoints(
    userId: string,
    role: string,
    reportId: string,
    items: any[],
  ): Promise<{
    totalPoints: number;
    taskPointsMap: Map<string, DailyReportTaskReward>;
  }> {
    const context = await this.buildDailyReportRewardContext(userId, role);

    const taskPointsMap = new Map<string, DailyReportTaskReward>();
    let totalPoints = 0;

    await this.dataSource.transaction(async (manager) => {
      const transactionRepo = manager.getRepository(PointTransaction);

      for (const item of items) {
        const decision = await this.evaluateDailyReportTaskReward(
          transactionRepo,
          userId,
          context,
          reportId,
          item,
        );
        const { taskId, taskName, desiredPoints: points, metadata, reason } =
          decision;
        const eventKey = `daily_report_item:${reportId}:${taskId}`;

        const existingTx = await transactionRepo.findOne({
          where: { event_key: eventKey },
        });

        if (existingTx) {
          taskPointsMap.set(taskId, {
            points: 0,
            reason: 'Task đã được tính điểm trong báo cáo này',
          });
          continue;
        }

        if (points > 0) {
          const mutation = await this.applyPointMutationWithManager(manager, {
            userId,
            points,
            type: 'earn',
            sourceType: 'daily_report_task',
            sourceRefId: reportId,
            eventKey,
            note: `Reward for report task: ${taskName}`,
            metadata,
          });

          if (!mutation.duplicate) {
            totalPoints += points;
            taskPointsMap.set(taskId, {
              points,
              reason,
            });
          } else {
            taskPointsMap.set(taskId, {
              points: 0,
              reason: 'Task đã được tính điểm trong báo cáo này',
            });
          }
        } else {
          taskPointsMap.set(taskId, {
            points: 0,
            reason,
          });
        }
      }
    });

    if (totalPoints > 0) {
      const balance = (await this.getOrCreateWallet(userId)).balance;
      // We don't have a single transaction ID for the whole batch here since we did multiple mutations,
      // but we can use the reportId or a random one for the sync event.
      const syncEventId = crypto.randomUUID();

      await this.publishWalletSyncEvent(userId, {
        transactionId: syncEventId,
        sourceType: 'daily_report_task',
        transactionType: 'earn',
        points: totalPoints,
        balance: balance,
      });

      await this.redisPubSubService.publishGlobalRewardUpdate();

      await this.notifyUserPointChange(userId, {
        id: syncEventId,
        points: totalPoints,
        type: 'earn',
        source_type: 'daily_report_task',
        balance_after: balance,
        note: `Tổng điểm báo cáo ngày: +${totalPoints}`,
      });
    }

    return { totalPoints, taskPointsMap };
  }

  async reconcileDailyReportPoints(
    userId: string,
    role: string,
    reportId: string,
    items: any[],
  ): Promise<{
    totalPoints: number;
    netDelta: number;
    adjustedTaskCount: number;
    taskPointsMap: Map<string, DailyReportTaskReward>;
  }> {
    const context = await this.buildDailyReportRewardContext(userId, role);
    const taskPointsMap = new Map<string, DailyReportTaskReward>();
    let netDelta = 0;
    let adjustedTaskCount = 0;

    await this.dataSource.transaction(async (manager) => {
      const transactionRepo = manager.getRepository(PointTransaction);
      const existingTransactions = await transactionRepo.find({
        where: {
          user_id: userId,
          source_type: 'daily_report_task',
          source_ref_id: reportId,
        },
        select: ['points', 'metadata'],
      });

      const currentPointsByTask = new Map<string, number>();
      for (const transaction of existingTransactions) {
        const metadataTaskId = transaction.metadata?.task_id;
        if (
          typeof metadataTaskId !== 'string' &&
          typeof metadataTaskId !== 'number'
        ) {
          continue;
        }

        const taskId = String(metadataTaskId);
        currentPointsByTask.set(
          taskId,
          (currentPointsByTask.get(taskId) ?? 0) + transaction.points,
        );
      }

      const desiredDecisions = new Map<string, DailyReportTaskRewardDecision>();
      for (const item of items) {
        const decision = await this.evaluateDailyReportTaskReward(
          transactionRepo,
          userId,
          context,
          reportId,
          item,
        );
        desiredDecisions.set(decision.taskId, decision);
        taskPointsMap.set(decision.taskId, {
          points: decision.desiredPoints,
          reason: decision.reason,
        });
      }

      const taskIds = new Set<string>([
        ...currentPointsByTask.keys(),
        ...desiredDecisions.keys(),
      ]);

      for (const taskId of taskIds) {
        const desired = desiredDecisions.get(taskId);
        const desiredPoints = desired?.desiredPoints ?? 0;
        const currentPoints = currentPointsByTask.get(taskId) ?? 0;
        const delta = desiredPoints - currentPoints;

        if (delta === 0) {
          continue;
        }

        adjustedTaskCount += 1;
        netDelta += delta;

        const taskName =
          desired?.taskName ??
          String(
            existingTransactions.find(
              (transaction) =>
                String(transaction.metadata?.task_id ?? '') === taskId,
            )?.metadata?.task_name ?? taskId,
          );

        await this.applyPointMutationWithManager(manager, {
          userId,
          points: delta,
          type: 'adjust',
          sourceType: 'daily_report_task',
          sourceRefId: reportId,
          eventKey: null,
          note: `Daily report reward reconciliation: ${taskName}`,
          metadata: {
            task_id: taskId,
            task_name: taskName,
            correction: true,
            desired_points: desiredPoints,
            previous_points: currentPoints,
            delta,
          },
          countTowardLifetimeSpent: false,
        });
      }
    });

    const totalPoints = Array.from(taskPointsMap.values()).reduce(
      (sum, reward) => sum + reward.points,
      0,
    );

    if (netDelta !== 0) {
      const balance = (await this.getOrCreateWallet(userId)).balance;
      const syncEventId = crypto.randomUUID();
      const signedDelta = netDelta > 0 ? `+${netDelta}` : `${netDelta}`;

      await this.publishWalletSyncEvent(userId, {
        transactionId: syncEventId,
        sourceType: 'daily_report_task',
        transactionType: 'adjust',
        points: netDelta,
        balance,
      });

      await this.redisPubSubService.publishGlobalRewardUpdate();

      await this.notifyUserPointChange(userId, {
        id: syncEventId,
        points: netDelta,
        type: 'adjust',
        source_type: 'daily_report_task',
        balance_after: balance,
        note: `Điều chỉnh điểm báo cáo ngày: ${signedDelta}`,
      });
    }

    return {
      totalPoints,
      netDelta,
      adjustedTaskCount,
      taskPointsMap,
    };
  }

  private async buildDailyReportRewardContext(
    userId: string,
    role: string,
  ): Promise<DailyReportRewardContext> {
    const user = await this.getActiveUserOrThrow(userId);

    const tagConfigs = await this.taskTagConfigRepo.find();
    console.log(
      `Loaded tag configs for daily report: ${tagConfigs.length} entries`,
    );
    const tagMap = new Map(tagConfigs.map((c) => [c.tag_name, c.base_points]));
    const tagIdMap = new Map(tagConfigs.map((c) => [c.id, c.base_points]));
    const odooTags = await this.odooService.fetchProjectTags();
    const odooTagMap = new Map(odooTags.map((t) => [t.id, t.name]));

    const mappings = await this.jobTitleMappingRepo.find({
      relations: ['internal_role'],
    });
    const multiplierMap = new Map(
      mappings.map((m) => [m.job_title, Number(m.internal_role.multiplier)]),
    );
    const userMapping = mappings.find((m) => m.job_title === role);
    const internalRole = userMapping?.internal_role;

    return {
      user,
      internalRoleName: (internalRole?.name || 'Developer').toLowerCase(),
      roleMultiplier: Number(internalRole?.multiplier || 1.0),
      tagMap,
      tagIdMap,
      multiplierMap,
      qcJobTitles: new Set(
        mappings
          .filter(
            (mapping) =>
              mapping.internal_role?.name?.trim().toLowerCase() === 'qc',
          )
          .map((mapping) => mapping.job_title),
      ),
      odooTagMap,
    };
  }

  private async hasQcAssigneeForDailyReportTask(
    item: { user_ids?: unknown },
    context: DailyReportRewardContext,
  ): Promise<boolean> {
    if (!Array.isArray(item.user_ids) || item.user_ids.length === 0) {
      return false;
    }

    const assigneeOdooUids = item.user_ids
      .map((assignee) => {
        if (typeof assignee === 'number') {
          return assignee;
        }
        if (
          Array.isArray(assignee) &&
          typeof assignee[0] === 'number'
        ) {
          return assignee[0];
        }
        return null;
      })
      .filter((uid): uid is number => Number.isInteger(uid));

    if (assigneeOdooUids.length === 0 || context.qcJobTitles.size === 0) {
      return false;
    }

    const assignees = await this.userRepo.find({
      where: {
        odoo_uid: In(assigneeOdooUids),
      },
      select: ['job_title'],
    });

    return assignees.some(
      (assignee) =>
        typeof assignee.job_title === 'string' &&
        context.qcJobTitles.has(assignee.job_title),
    );
  }

  private async evaluateDailyReportTaskReward(
    transactionRepo: Repository<PointTransaction>,
    userId: string,
    context: DailyReportRewardContext,
    reportId: string,
    item: any,
  ): Promise<DailyReportTaskRewardDecision> {
    const taskId = String(item.id || item.task_id);
    const taskName = item.name || item.task_name;
    const hasQcAssignee =
      context.internalRoleName === 'qc'
        ? await this.hasQcAssigneeForDailyReportTask(item, context)
        : false;

    if (context.internalRoleName === 'qc' && !hasQcAssignee) {
      const desiredPoints = Math.round(context.roleMultiplier);
      return {
        taskId,
        taskName,
        desiredPoints,
        reason: desiredPoints <= 0 ? 'Hệ số nhân QC bằng 0' : '',
        metadata: {
          task_id: taskId,
          task_name: taskName,
          qc_done: item.qc_done,
          qc_miss: item.qc_miss,
          qc_fail: item.qc_fail,
          points_per_task: desiredPoints,
        },
      };
    }

    if (item.status !== 'done') {
      return {
        taskId,
        taskName,
        desiredPoints: 0,
        reason: 'Task chưa hoàn thành (Doing)',
        metadata: {
          task_id: taskId,
          task_name: taskName,
        },
      };
    }

    const priorRewardExists = await this.hasPriorDailyReportReward(
      transactionRepo,
      userId,
      taskId,
      reportId,
    );
    if (priorRewardExists) {
      return {
        taskId,
        taskName,
        desiredPoints: 0,
        reason: 'Task đã ăn điểm trước đó, không cộng lại',
        metadata: {
          task_id: taskId,
          task_name: taskName,
          prior_reward_exists: true,
        },
      };
    }

    const calc = this.calculateTaskPoints(
      item,
      context.user,
      context.tagMap,
      context.tagIdMap,
      context.multiplierMap,
      context.odooTagMap,
      { applyPenalty: false, isDailyReport: true },
    );

    return {
      taskId,
      taskName,
      desiredPoints: calc.finalPoints,
      reason:
        calc.finalPoints <= 0 ? 'Task Done nhưng không gắn tag tính điểm' : '',
      metadata: {
        task_id: taskId,
        task_name: taskName,
        base_points: calc.basePoints,
        multiplier: calc.multiplier,
        is_miss: calc.isMiss,
      },
    };
  }

  private async hasPriorDailyReportReward(
    transactionRepo: Repository<PointTransaction>,
    userId: string,
    taskId: string,
    reportId: string,
  ): Promise<boolean> {
    const matches = await transactionRepo.find({
      where: {
        user_id: userId,
        source_type: 'daily_report_task',
        type: 'earn',
      },
      select: ['source_ref_id', 'metadata'],
    });

    return matches.some((tx) => {
      const metadataTaskId = tx.metadata?.task_id;
      return (
        String(metadataTaskId ?? '') === taskId && tx.source_ref_id !== reportId
      );
    });
  }

  private async processSingleTaskReward(
    task: any,
    tagMap: Map<string, number>,
    tagIdMap: Map<number, number>,
    multiplierMap: Map<string, number>,
    odooTagMap: Map<number, string>,
  ): Promise<boolean> {
    // 1. Check if already rewarded
    const existingLog = await this.taskRewardLogRepo.findOne({
      where: { task_id: Number(task.id) },
    });
    if (existingLog) return false;

    // 2. Identify assignee
    if (!task.user_ids || task.user_ids.length === 0) {
      return false;
    }

    const odooUid =
      typeof task.user_ids[0] === 'number'
        ? task.user_ids[0]
        : task.user_ids[0][0];

    // 3. Find user in our DB
    const user = await this.userRepo.findOne({ where: { odoo_uid: odooUid } });
    if (!user) return false;

    // 4. Calculate points
    const calc = this.calculateTaskPoints(
      task,
      user,
      tagMap,
      tagIdMap,
      multiplierMap,
      odooTagMap,
    );

    if (calc.finalPoints <= 0) return false;

    // 5. Apply reward (transactional)
    await this.dataSource.transaction(async (manager) => {
      // Re-verify log inside transaction
      const logRepo = manager.getRepository(OdooTaskRewardLog);
      const doubleCheck = await logRepo.findOne({
        where: { task_id: Number(task.id) },
      });
      if (doubleCheck) return;

      const result = await this.applyPointMutationWithManager(manager, {
        userId: user.id,
        points: calc.finalPoints,
        type: 'earn',
        sourceType: 'odoo_task_staging',
        sourceRefId: String(task.id),
        eventKey: `odoo_task:${task.id}`,
        note: `Reward for Odoo task #${task.id}: ${task.name}${calc.isMiss ? ' (Penalty for Miss)' : ''}`,
        metadata: {
          task_id: task.id,
          task_name: task.name,
          base_points: calc.basePoints,
          multiplier: calc.multiplier,
          is_miss: calc.isMiss,
        },
      });

      const log = logRepo.create({
        task_id: Number(task.id),
        user_id: user.id,
        points: calc.finalPoints,
        is_miss: calc.isMiss,
      });
      await logRepo.save(log);

      await this.publishWalletSyncEvent(user.id, {
        transactionId: result.transaction.id,
        sourceType: 'odoo_task_staging',
        transactionType: 'earn',
        points: calc.finalPoints,
        balance: result.wallet.balance,
      });

      await this.notifyUserPointChange(user.id, {
        ...result.transaction,
        type: 'earn',
        source_type: 'odoo_task_staging',
        note: log.is_miss ? 'Task Staging (Penalty for Miss)' : 'Task Staging',
      });
    });

    return true;
  }
}
