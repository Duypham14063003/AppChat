import { Injectable, Logger, MessageEvent } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Observable, Subject, concat, from } from 'rxjs';
import { filter as rxFilter, map } from 'rxjs/operators';
import { AuditLog } from '../entities/audit-log.entity.js';

export type DailyReportAuditLogFilters = {
  eventType?: string;
  reportId?: string;
  status?: string;
  taskId?: string;
  userId?: string;
  limit?: number;
};

@Injectable()
export class AuditLogService {
  private readonly logger = new Logger('AuditLog');
  private readonly auditLogStream$ = new Subject<AuditLog>();

  constructor(
    @InjectRepository(AuditLog)
    private readonly auditLogRepo: Repository<AuditLog>,
  ) {}

  async logEvent(event: {
    category: string;
    type: string;
    userId?: string;
    entityType?: string;
    entityId?: string;
    status?: string;
    email?: string;
    ip?: string;
    userAgent?: string;
    reason?: string;
    metadata?: Record<string, unknown>;
  }): Promise<void> {
    const payload = {
      timestamp: new Date().toISOString(),
      category: event.category,
      event: event.type,
      userId: event.userId,
      entityType: event.entityType,
      entityId: event.entityId,
      status: event.status,
      email: event.email,
      ip: event.ip,
      userAgent: event.userAgent,
      reason: event.reason,
      ...event.metadata,
    };

    this.logger.log(JSON.stringify(payload));

    try {
      const auditLog = this.auditLogRepo.create({
        category: event.category,
        event_type: event.type,
        user_id: event.userId ?? null,
        entity_type: event.entityType ?? null,
        entity_id: event.entityId ?? null,
        status: event.status ?? null,
        reason: event.reason ?? null,
        email: event.email ?? null,
        ip: event.ip ?? null,
        user_agent: event.userAgent ?? null,
        metadata: event.metadata ?? null,
      });
      const savedAuditLog = await this.auditLogRepo.save(auditLog);
      this.auditLogStream$.next(savedAuditLog);
    } catch (error) {
      this.logger.error(
        `Failed to persist audit log: ${error instanceof Error ? error.message : String(error)}`,
      );
    }
  }

  async logAuthEvent(event: {
    type: string;
    userId?: string;
    email?: string;
    ip?: string;
    userAgent?: string;
    reason?: string;
    metadata?: Record<string, unknown>;
  }): Promise<void> {
    await this.logEvent({
      category: 'auth',
      type: event.type,
      userId: event.userId,
      email: event.email,
      ip: event.ip,
      userAgent: event.userAgent,
      reason: event.reason,
      metadata: event.metadata,
    });
  }

  async logDailyReportEvent(event: {
    type: string;
    userId?: string;
    reportId?: string;
    status?: string;
    reason?: string;
    metadata?: Record<string, unknown>;
  }): Promise<void> {
    await this.logEvent({
      category: 'daily_report',
      type: event.type,
      userId: event.userId,
      entityType: 'daily_report',
      entityId: event.reportId,
      status: event.status,
      reason: event.reason,
      metadata: event.metadata,
    });
  }

  async listDailyReportLogs(filters: DailyReportAuditLogFilters) {
    const limit = Math.min(Math.max(filters.limit ?? 20, 1), 100);

    const query = this.auditLogRepo
      .createQueryBuilder('audit')
      .where('audit.category = :category', { category: 'daily_report' })
      .orderBy('audit.created_at', 'DESC')
      .limit(limit);

    if (filters.userId) {
      query.andWhere('audit.user_id = :userId', { userId: filters.userId });
    }

    if (filters.status) {
      query.andWhere('audit.status = :status', { status: filters.status });
    }

    if (filters.eventType) {
      query.andWhere('audit.event_type = :eventType', {
        eventType: filters.eventType,
      });
    }

    if (filters.reportId) {
      query.andWhere('audit.entity_id = :reportId', {
        reportId: filters.reportId,
      });
    }

    if (filters.taskId) {
      query.andWhere(`audit.metadata ->> 'taskId' = :taskId`, {
        taskId: filters.taskId,
      });
    }

    const items = await query.getMany();
    return { items };
  }

  streamDailyReportLogs(
    filters: DailyReportAuditLogFilters,
  ): Observable<MessageEvent> {
    const snapshot$ = from(this.listDailyReportLogs(filters)).pipe(
      map(
        ({ items }) => ({ type: 'snapshot', data: { items } }) as MessageEvent,
      ),
    );

    const live$ = this.auditLogStream$.pipe(
      rxFilter((log) => this.matchesDailyReportLogFilters(log, filters)),
      map((log) => ({ type: 'audit_log', data: log }) as MessageEvent),
    );

    return concat(snapshot$, live$);
  }

  private matchesDailyReportLogFilters(
    log: AuditLog,
    filters: DailyReportAuditLogFilters,
  ): boolean {
    if (log.category !== 'daily_report') {
      return false;
    }

    if (filters.userId && log.user_id !== filters.userId) {
      return false;
    }

    if (filters.status && log.status !== filters.status) {
      return false;
    }

    if (filters.eventType && log.event_type !== filters.eventType) {
      return false;
    }

    if (filters.reportId && log.entity_id !== filters.reportId) {
      return false;
    }

    if (filters.taskId) {
      const taskId = log.metadata?.taskId;
      if (
        typeof taskId !== 'string' &&
        typeof taskId !== 'number' &&
        typeof taskId !== 'boolean'
      ) {
        return false;
      }

      if (String(taskId) !== filters.taskId) {
        return false;
      }
    }

    return true;
  }
}
