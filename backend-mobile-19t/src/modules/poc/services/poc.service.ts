import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Brackets, DataSource, Repository } from 'typeorm';
import type { QueryDeepPartialEntity } from 'typeorm/query-builder/QueryPartialEntity.js';
import { AuditLogService } from '../../auth/services/audit-log.service.js';
import { User } from '../../auth/entities/user.entity.js';
import { ConversationMember } from '../../chat/entities/conversation-member.entity.js';
import { Message } from '../../chat/entities/message.entity.js';
import {
  AssignPocDto,
  CreatePocDto,
  PocListQueryDto,
  TransitionPocDto,
  UpdatePocPlanDto,
} from '../dto/poc.dto.js';
import { Poc } from '../entities/poc.entity.js';
import { PocHistory } from '../entities/poc-history.entity.js';
import type { PocStatus } from '../poc.constants.js';
import { PocChatService } from './poc-chat.service.js';
import { PocJobService } from './poc-job.service.js';
import { PocPushService } from './poc-push.service.js';

const DETAIL_RELATIONS = [
  'sale_user',
  'developer_user',
  'assigned_by_user',
  'working_conversation',
] as const;

@Injectable()
export class PocService {
  constructor(
    @InjectRepository(Poc) private readonly pocRepo: Repository<Poc>,
    @InjectRepository(PocHistory)
    private readonly historyRepo: Repository<PocHistory>,
    @InjectRepository(User) private readonly userRepo: Repository<User>,
    @InjectRepository(ConversationMember)
    private readonly memberRepo: Repository<ConversationMember>,
    @InjectRepository(Message)
    private readonly messageRepo: Repository<Message>,
    private readonly dataSource: DataSource,
    private readonly audit: AuditLogService,
    private readonly chat: PocChatService,
    private readonly jobs: PocJobService,
    private readonly push: PocPushService,
  ) {}

  async create(actorId: string, dto: CreatePocDto) {
    await this.activeUser(actorId);
    const demoAt = this.futureDate(dto.demo_at, 'demo_at');
    await this.validateConversationContext(
      actorId,
      dto.working_conversation_id,
      dto.source_message_id,
    );
    const poc = await this.dataSource.transaction(async (manager) => {
      const repo = manager.getRepository(Poc);
      const saved = await repo.save(
        repo.create({
          customer_name: dto.customer_name.trim(),
          title: dto.title.trim(),
          requirement: dto.requirement.trim(),
          product_type: dto.product_type,
          priority: dto.priority ?? 'normal',
          sale_user_id: actorId,
          developer_user_id: null,
          assigned_by_user_id: null,
          working_conversation_id: dto.working_conversation_id ?? null,
          source_message_id: dto.source_message_id ?? null,
          planned_start_at: null,
          estimated_hours: null,
          demo_at: demoAt,
          status: 'unassigned',
          outcome: null,
          poc_url: null,
          reference_links: dto.reference_links ?? [],
          cancel_reason: null,
          ready_at: null,
          demonstrated_at: null,
          version: 1,
        }),
      );
      await manager.getRepository(PocHistory).save({
        poc_id: saved.id,
        actor_user_id: actorId,
        event_type: 'created',
        previous_values: null,
        new_values: this.snapshot(saved),
      });
      return saved;
    });
    await this.log(actorId, poc, 'poc.created');
    await this.jobs.enqueueWeeklyRefresh();
    return this.detail(actorId, poc.id);
  }

  async list(userId: string, query: PocListQueryDto) {
    const qb = this.pocRepo
      .createQueryBuilder('poc')
      .leftJoinAndSelect('poc.sale_user', 'sale')
      .leftJoinAndSelect('poc.developer_user', 'developer')
      .leftJoinAndSelect('poc.assigned_by_user', 'assignedBy');
    if (query.mode === 'my_requests')
      qb.andWhere('poc.sale_user_id = :userId', { userId });
    if (query.mode === 'my_pocs')
      qb.andWhere('poc.developer_user_id = :userId', { userId });
    if (query.mode === 'unassigned')
      qb.andWhere('poc.status = :unassigned', { unassigned: 'unassigned' });
    if (query.mode === 'week' || query.week) {
      const { start, end } = this.weekWindow(
        query.week ?? new Date().toISOString(),
      );
      qb.andWhere('poc.demo_at >= :start AND poc.demo_at < :end', {
        start,
        end,
      });
    }
    if (query.status)
      qb.andWhere('poc.status = :status', { status: query.status });
    if (query.developer_user_id)
      qb.andWhere('poc.developer_user_id = :developer', {
        developer: query.developer_user_id,
      });
    if (query.sale_user_id)
      qb.andWhere('poc.sale_user_id = :sale', { sale: query.sale_user_id });
    if (query.priority)
      qb.andWhere('poc.priority = :priority', { priority: query.priority });
    if (query.search?.trim()) {
      qb.andWhere(
        new Brackets((where) =>
          where
            .where('poc.title ILIKE :search', {
              search: `%${query.search!.trim()}%`,
            })
            .orWhere('poc.customer_name ILIKE :search', {
              search: `%${query.search!.trim()}%`,
            })
            .orWhere('poc.code ILIKE :search', {
              search: `%${query.search!.trim()}%`,
            }),
        ),
      );
    }
    qb.orderBy(
      `CASE WHEN poc.demo_at < NOW() AND poc.status NOT IN ('ready','demonstrated','cancelled') THEN 0 ELSE 1 END`,
      'ASC',
    )
      .addOrderBy('poc.demo_at', 'ASC')
      .skip((query.page - 1) * query.limit)
      .take(query.limit);
    const [items, total] = await qb.getManyAndCount();
    return {
      items: items.map((poc) => this.view(poc)),
      total,
      page: query.page,
      limit: query.limit,
    };
  }

  async detail(_userId: string, id: string) {
    const poc = await this.pocRepo.findOne({
      where: { id },
      relations: [...DETAIL_RELATIONS],
    });
    if (!poc) throw new NotFoundException('PoC not found');
    const history = await this.historyRepo.find({
      where: { poc_id: id },
      relations: ['actor'],
      order: { created_at: 'ASC' },
    });
    return {
      ...this.view(poc),
      history: history.map((event) => ({
        id: event.id,
        event_type: event.event_type,
        actor_user_id: event.actor_user_id,
        actor_name: event.actor?.name ?? null,
        previous_values: event.previous_values,
        new_values: event.new_values,
        created_at: event.created_at,
      })),
    };
  }

  async assign(actorId: string, id: string, dto: AssignPocDto) {
    await this.activeUser(actorId);
    const current = await this.get(id);
    if (['demonstrated', 'cancelled'].includes(current.status)) {
      throw new BadRequestException('Terminal PoC cannot be assigned');
    }
    const developer = await this.activeUser(dto.developer_user_id);
    const demoAt = dto.demo_at
      ? this.futureDate(dto.demo_at, 'demo_at')
      : current.demo_at;
    const plannedStart = new Date(dto.planned_start_at);
    this.validPlan(plannedStart, demoAt, dto.estimated_hours);
    const firstAssignment = !current.sequence_number;
    const sequence = firstAssignment
      ? await this.nextSequence()
      : current.sequence_number!;
    const changes = this.changes(current, {
      developer_user_id: developer.id,
      planned_start_at: plannedStart,
      estimated_hours: dto.estimated_hours.toFixed(2),
      demo_at: demoAt,
    });
    const code = this.code(
      current.sale_user?.name ?? '',
      developer.name,
      current.product_type,
      sequence,
      demoAt,
    );
    const updated = await this.mutate(
      actorId,
      current,
      dto.version,
      firstAssignment ? 'assigned' : 'reassigned',
      {
        developer_user_id: developer.id,
        assigned_by_user_id: actorId,
        planned_start_at: plannedStart,
        estimated_hours: dto.estimated_hours.toFixed(2),
        demo_at: demoAt,
        status: current.status === 'unassigned' ? 'assigned' : current.status,
        sequence_number: sequence,
        code,
      },
      changes,
    );
    await this.jobs.reconcile(updated);
    await this.chat.project(
      updated,
      actorId,
      firstAssignment ? 'poc_assigned' : 'poc_reassigned',
      changes,
    );
    await this.push.send(
      [developer.id],
      'PoC mới được phân công',
      `${code} · Demo ${this.displayDate(demoAt)}`,
      this.pushData(updated),
    );
    await this.jobs.enqueueWeeklyRefresh();
    return this.detail(actorId, id);
  }

  async updatePlan(actorId: string, id: string, dto: UpdatePocPlanDto) {
    await this.activeUser(actorId);
    const current = await this.get(id);
    if (['demonstrated', 'cancelled'].includes(current.status))
      throw new BadRequestException('Terminal PoC cannot be updated');
    const developerId = dto.developer_user_id ?? current.developer_user_id;
    const developer = developerId ? await this.activeUser(developerId) : null;
    const plannedStart = dto.planned_start_at
      ? new Date(dto.planned_start_at)
      : current.planned_start_at;
    const demoAt = dto.demo_at
      ? this.futureDate(dto.demo_at, 'demo_at')
      : current.demo_at;
    const estimate = dto.estimated_hours ?? Number(current.estimated_hours);
    if (developer && plannedStart)
      this.validPlan(plannedStart, demoAt, estimate);
    if (dto.working_conversation_id)
      await this.validateConversationContext(
        actorId,
        dto.working_conversation_id,
      );
    const next: Partial<Poc> = {
      developer_user_id: developerId,
      assigned_by_user_id:
        developerId !== current.developer_user_id
          ? actorId
          : current.assigned_by_user_id,
      planned_start_at: plannedStart,
      estimated_hours: developer ? estimate.toFixed(2) : null,
      demo_at: demoAt,
      poc_url: dto.poc_url === undefined ? current.poc_url : dto.poc_url.trim(),
      reference_links: dto.reference_links ?? current.reference_links,
      working_conversation_id:
        dto.working_conversation_id ?? current.working_conversation_id,
    };
    if (current.sequence_number && developer) {
      next.code = this.code(
        current.sale_user?.name ?? '',
        developer.name,
        current.product_type,
        current.sequence_number,
        demoAt,
      );
    }
    const changes = this.changes(current, next);
    if (!Object.keys(changes).length) return this.detail(actorId, id);
    const updated = await this.mutate(
      actorId,
      current,
      dto.version,
      'plan_updated',
      next,
      changes,
    );
    await this.jobs.reconcile(updated);
    await this.chat.project(updated, actorId, 'poc_plan_updated', changes);
    await this.jobs.enqueueWeeklyRefresh();
    return this.detail(actorId, id);
  }

  async transition(actorId: string, id: string, dto: TransitionPocDto) {
    await this.activeUser(actorId);
    const current = await this.get(id);
    this.assertTransition(current.status, dto.status, dto.outcome);
    const next: Partial<Poc> = { status: dto.status };
    let event = `status_${dto.status}`;
    if (dto.status === 'ready') next.ready_at = new Date();
    if (dto.status === 'demonstrated') {
      next.demonstrated_at = new Date();
      next.outcome = dto.outcome!;
    }
    if (dto.status === 'cancelled') {
      if (!dto.cancel_reason?.trim())
        throw new BadRequestException('cancel_reason is required');
      next.cancel_reason = dto.cancel_reason.trim();
    }
    if (dto.status === 'demonstrated' && dto.outcome === 'revision_required') {
      const demoAt = this.futureDate(dto.demo_at!, 'demo_at');
      const plannedStart = new Date(dto.planned_start_at!);
      this.validPlan(plannedStart, demoAt, dto.estimated_hours!);
      next.status = 'in_progress';
      next.outcome = 'revision_required';
      next.demo_at = demoAt;
      next.planned_start_at = plannedStart;
      next.estimated_hours = dto.estimated_hours!.toFixed(2);
      next.ready_at = null;
      next.demonstrated_at = null;
      if (current.sequence_number && current.developer_user) {
        next.code = this.code(
          current.sale_user?.name ?? '',
          current.developer_user.name,
          current.product_type,
          current.sequence_number,
          demoAt,
        );
      }
      event = 'revision_required';
    }
    const changes = this.changes(current, next);
    const updated = await this.mutate(
      actorId,
      current,
      dto.version,
      event,
      next,
      changes,
    );
    await this.jobs.reconcile(updated);
    await this.chat.project(updated, actorId, `poc_${event}`, changes);
    if (updated.status === 'ready') {
      await this.push.send(
        [updated.sale_user_id],
        'PoC đã sẵn sàng demo',
        updated.code ?? updated.title,
        this.pushData(updated),
      );
    }
    await this.jobs.enqueueWeeklyRefresh();
    return this.detail(actorId, id);
  }

  async getForNotification(id: string): Promise<Poc | null> {
    return this.pocRepo.findOne({
      where: { id },
      relations: ['sale_user', 'developer_user'],
    });
  }

  private async mutate(
    actorId: string,
    current: Poc,
    expectedVersion: number,
    eventType: string,
    next: Partial<Poc>,
    changes: Record<string, { previous: unknown; current: unknown }>,
  ): Promise<Poc> {
    const nextVersion = expectedVersion + 1;
    const affected = await this.dataSource.transaction(async (manager) => {
      const result = await manager
        .getRepository(Poc)
        .createQueryBuilder()
        .update(Poc)
        .set({
          ...(next as QueryDeepPartialEntity<Poc>),
          version: nextVersion,
          updated_at: new Date(),
        })
        .where('id = :id AND version = :version', {
          id: current.id,
          version: expectedVersion,
        })
        .execute();
      if (!result.affected) return false;
      await manager.getRepository(PocHistory).save({
        poc_id: current.id,
        actor_user_id: actorId,
        event_type: eventType,
        previous_values: Object.fromEntries(
          Object.entries(changes).map(([key, value]) => [key, value.previous]),
        ),
        new_values: Object.fromEntries(
          Object.entries(changes).map(([key, value]) => [key, value.current]),
        ),
      });
      return true;
    });
    if (!affected) {
      const latest = await this.get(current.id);
      throw new ConflictException({
        message: 'PoC was changed by another user',
        code: 'POC_VERSION_CONFLICT',
        latest: this.view(latest),
      });
    }
    const updated = await this.get(current.id);
    await this.log(actorId, updated, `poc.${eventType}`, changes);
    return updated;
  }

  private async get(id: string): Promise<Poc> {
    const poc = await this.pocRepo.findOne({
      where: { id },
      relations: [...DETAIL_RELATIONS],
    });
    if (!poc) throw new NotFoundException('PoC not found');
    return poc;
  }

  private async activeUser(id: string): Promise<User> {
    const user = await this.userRepo.findOne({
      where: { id, is_active: true, is_bot: false },
    });
    if (!user) throw new BadRequestException('Active user not found');
    return user;
  }

  private async validateConversationContext(
    actorId: string,
    convId?: string,
    messageId?: string,
  ) {
    if (!convId && messageId)
      throw new BadRequestException(
        'working_conversation_id is required for source_message_id',
      );
    if (!convId) return;
    if (
      !(await this.memberRepo.findOne({
        where: { conv_id: convId, user_id: actorId },
      }))
    ) {
      throw new ForbiddenException(
        'You are not a member of the working conversation',
      );
    }
    if (
      messageId &&
      !(await this.messageRepo.findOne({
        where: { id: messageId, conv_id: convId },
      }))
    ) {
      throw new BadRequestException(
        'Source message does not belong to the working conversation',
      );
    }
  }

  private futureDate(value: string, field: string): Date {
    const date = new Date(value);
    if (!Number.isFinite(date.getTime()) || date <= new Date())
      throw new BadRequestException(`${field} must be in the future`);
    return date;
  }

  private validPlan(start: Date, demo: Date, hours: number) {
    if (!Number.isFinite(start.getTime()) || start >= demo)
      throw new BadRequestException('planned_start_at must be before demo_at');
    if (!Number.isFinite(hours) || hours <= 0)
      throw new BadRequestException('estimated_hours must be positive');
  }

  private assertTransition(
    current: PocStatus,
    next: PocStatus,
    outcome?: string,
  ) {
    const allowed: Record<PocStatus, PocStatus[]> = {
      unassigned: ['cancelled'],
      assigned: ['in_progress', 'cancelled'],
      in_progress: ['ready', 'cancelled'],
      ready: ['in_progress', 'demonstrated', 'cancelled'],
      demonstrated: ['in_progress'],
      cancelled: [],
    };
    if (!allowed[current].includes(next))
      throw new BadRequestException(`Invalid transition ${current} -> ${next}`);
    if (
      next === 'demonstrated' &&
      !['completed', 'revision_required', 'not_proceeding'].includes(
        outcome ?? '',
      )
    ) {
      throw new BadRequestException('A demonstrated PoC requires an outcome');
    }
  }

  private async nextSequence(): Promise<string> {
    const rows = await this.pocRepo.query<Array<{ value: string }>>(
      `SELECT nextval('poc_code_sequence')::text AS value`,
    );
    return rows[0].value;
  }

  private code(
    sale: string,
    developer: string,
    product: string,
    sequence: string,
    demo: Date,
  ) {
    const initials = (name: string) =>
      name
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '')
        .split(/\s+/)
        .filter(Boolean)
        .map((part) => part[0])
        .join('')
        .toUpperCase()
        .slice(0, 3) || 'NA';
    const productCode =
      product === 'website' ? 'WS' : product === 'web_app' ? 'WA' : 'DV';
    const date = new Intl.DateTimeFormat('en-GB', {
      timeZone: 'Asia/Ho_Chi_Minh',
      day: '2-digit',
      month: '2-digit',
      year: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      hour12: false,
    }).formatToParts(demo);
    const value = Object.fromEntries(
      date.map((part) => [part.type, part.value]),
    );
    return `${initials(sale)}.${initials(developer)}-${productCode}-P${sequence.padStart(4, '0')}-${value.hour}${value.minute}-${value.day}.${value.month}.${value.year}`;
  }

  private changes(current: Poc, next: Partial<Poc>) {
    const result: Record<string, { previous: unknown; current: unknown }> = {};
    for (const [key, value] of Object.entries(next)) {
      const previous = current[key as keyof Poc];
      const prevValue =
        previous instanceof Date ? previous.toISOString() : previous;
      const nextValue = value instanceof Date ? value.toISOString() : value;
      if (JSON.stringify(prevValue) !== JSON.stringify(nextValue))
        result[key] = { previous: prevValue, current: nextValue };
    }
    return result;
  }

  private snapshot(poc: Poc): Record<string, unknown> {
    return {
      customer_name: poc.customer_name,
      title: poc.title,
      product_type: poc.product_type,
      priority: poc.priority,
      demo_at: poc.demo_at.toISOString(),
      status: poc.status,
    };
  }

  private view(poc: Poc) {
    const terminal =
      poc.status === 'cancelled' ||
      (poc.status === 'demonstrated' &&
        ['completed', 'not_proceeding'].includes(poc.outcome ?? ''));
    const overdue =
      !terminal &&
      !['ready', 'demonstrated'].includes(poc.status) &&
      poc.demo_at < new Date();
    const demoSoon =
      !terminal &&
      poc.demo_at > new Date() &&
      poc.demo_at.getTime() - Date.now() <= 86400000;
    return {
      ...poc,
      estimated_hours: poc.estimated_hours ? Number(poc.estimated_hours) : null,
      sale_user: poc.sale_user ? this.userView(poc.sale_user) : undefined,
      developer_user: poc.developer_user
        ? this.userView(poc.developer_user)
        : null,
      assigned_by_user: poc.assigned_by_user
        ? this.userView(poc.assigned_by_user)
        : null,
      overdue,
      demo_soon: demoSoon,
    };
  }

  private userView(user: User) {
    return {
      id: user.id,
      name: user.name,
      email: user.email,
      avatar_url: user.avatar_url,
      department: user.department,
      job_title: user.job_title,
    };
  }

  private async log(
    actorId: string,
    poc: Poc,
    type: string,
    metadata?: Record<string, unknown>,
  ) {
    await this.audit.logEvent({
      category: 'poc',
      type,
      userId: actorId,
      entityType: 'poc',
      entityId: poc.id,
      status: poc.status,
      metadata,
    });
  }

  private pushData(poc: Poc): Record<string, string> {
    return { type: 'poc', poc_id: poc.id, deep_link: `/pocs/${poc.id}` };
  }

  private displayDate(value: Date) {
    return value.toLocaleString('vi-VN', { timeZone: 'Asia/Ho_Chi_Minh' });
  }

  private weekWindow(value: string) {
    const date = new Date(`${value.slice(0, 10)}T12:00:00+07:00`);
    const day = date.getUTCDay() || 7;
    date.setUTCDate(date.getUTCDate() - day + 1);
    const local = date.toLocaleDateString('en-CA', {
      timeZone: 'Asia/Ho_Chi_Minh',
    });
    const start = new Date(`${local}T00:00:00+07:00`);
    return { start, end: new Date(start.getTime() + 7 * 86400000) };
  }
}
