import {
  Controller,
  Post,
  Put,
  Get,
  Sse,
  Body,
  Param,
  Query,
  HttpCode,
  HttpStatus,
  ForbiddenException,
  MessageEvent,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { DailyReportService } from './services/daily-report.service.js';
import {
  CreateDailyReportDto,
  DailyReportAuditLogQueryDto,
} from './dto/daily-report.dto.js';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import { Roles } from '../auth/decorators/roles.decorator.js';
import { InjectRepository } from '@nestjs/typeorm';
import { DailyReportItem } from './entities/daily-report-item.entity.js';
import { Repository } from 'typeorm';
import { AuditLogService } from '../auth/services/audit-log.service.js';
import { Observable } from 'rxjs';

@ApiTags('HR - Daily Reports')
@ApiBearerAuth()
@Controller('daily-reports')
export class DailyReportController {
  constructor(
    private readonly dailyReportService: DailyReportService,
    private readonly auditLogService: AuditLogService,
    @InjectRepository(DailyReportItem)
    private readonly itemRepo: Repository<DailyReportItem>,
  ) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Submit a new daily report (morning/evening)' })
  async submit(
    @CurrentUser('userId') userId: string,
    @Body() dto: CreateDailyReportDto,
  ) {
    return this.dailyReportService.submitReport(userId, dto);
  }

  @Put(':id')
  @ApiOperation({ summary: 'Update an existing daily report' })
  async update(
    @CurrentUser('userId') userId: string,
    @Param('id') id: string,
    @Body() dto: CreateDailyReportDto,
  ) {
    return this.dailyReportService.updateReport(userId, id, dto);
  }

  @Get('today')
  @ApiOperation({ summary: 'Get current user reports for today' })
  async getToday(@CurrentUser('userId') userId: string) {
    const reports = await this.dailyReportService.getTodayReports(userId);
    return { reports };
  }

  @Get('audit-logs')
  @ApiOperation({ summary: 'List daily report audit logs' })
  async getAuditLogs(
    @CurrentUser('userId') userId: string,
    @CurrentUser('roles') roles: string[],
    @Query() query: DailyReportAuditLogQueryDto,
  ) {
    const isAdmin = roles.includes('admin');
    if (query.user_id && !isAdmin && query.user_id !== userId) {
      throw new ForbiddenException('You can only access your own audit logs');
    }

    return this.auditLogService.listDailyReportLogs({
      eventType: query.event_type,
      status: query.status,
      reportId: query.report_id,
      taskId: query.task_id,
      userId: isAdmin ? (query.user_id ?? userId) : userId,
      limit: query.limit,
    });
  }

  @Sse('audit-logs/stream')
  @ApiOperation({ summary: 'Stream daily report audit logs (SSE)' })
  streamAuditLogs(
    @CurrentUser('userId') userId: string,
    @CurrentUser('roles') roles: string[],
    @Query() query: DailyReportAuditLogQueryDto,
  ): Observable<MessageEvent> {
    const isAdmin = roles.includes('admin');
    if (query.user_id && !isAdmin && query.user_id !== userId) {
      throw new ForbiddenException('You can only access your own audit logs');
    }

    return this.auditLogService.streamDailyReportLogs({
      eventType: query.event_type,
      status: query.status,
      reportId: query.report_id,
      taskId: query.task_id,
      userId: isAdmin ? (query.user_id ?? userId) : userId,
      limit: query.limit,
    });
  }

  // --- Admin Analytics ---

  @Roles('admin')
  @Get('stats/tasks/:id')
  @ApiOperation({
    summary: 'Get quality metrics for a specific Task ID (Admin)',
  })
  async getTaskStats(@Param('id') taskId: string) {
    const items = await this.itemRepo.find({
      where: { task_id: taskId },
      relations: ['report', 'report.user'],
    });

    const stats = items.reduce(
      (acc, item) => {
        acc.total_qc_done += item.qc_done || 0;
        acc.total_qc_miss += item.qc_miss || 0;
        acc.total_qc_fail += item.qc_fail || 0;
        acc.occurrences += 1;
        return acc;
      },
      { total_qc_done: 0, total_qc_miss: 0, total_qc_fail: 0, occurrences: 0 },
    );

    return {
      task_id: taskId,
      task_name: items[0]?.task_name || 'Unknown',
      ...stats,
      history: items.map((i) => ({
        date: i.report.report_date,
        user: i.report.user?.name,
        role: i.report.report_role,
        qc_done: i.qc_done,
        qc_miss: i.qc_miss,
        qc_fail: i.qc_fail,
        status: i.status,
      })),
    };
  }

  @Roles('admin')
  @Get('stats/users')
  @ApiOperation({
    summary: 'Get productivity statistics for all users (Admin)',
  })
  async getUserStats() {
    const stats = await this.itemRepo
      .createQueryBuilder('item')
      .leftJoin('item.report', 'report')
      .leftJoin('report.user', 'user')
      .select('user.id', 'user_id')
      .addSelect('user.name', 'user_name')
      .addSelect('report.report_role', 'role')
      .addSelect('COUNT(DISTINCT item.task_id)', 'unique_tasks_count')
      .addSelect('SUM(COALESCE(item.qc_done, 0))', 'total_qc_done')
      .addSelect('SUM(COALESCE(item.qc_miss, 0))', 'total_qc_miss')
      .addSelect('SUM(COALESCE(item.qc_fail, 0))', 'total_qc_fail')
      .addSelect(
        "COUNT(item.id) FILTER (WHERE item.status = 'done')",
        'total_dev_done',
      )
      .groupBy('user.id, user.name, report.report_role')
      .getRawMany<{
        user_id: string;
        user_name: string;
        role: string;
        unique_tasks_count: string;
        total_qc_done: string;
        total_qc_miss: string;
        total_qc_fail: string;
        total_dev_done: string;
      }>();

    return stats.map((s) => ({
      ...s,
      unique_tasks_count: parseInt(s.unique_tasks_count, 10),
      total_qc_done: parseInt(s.total_qc_done, 10),
      total_qc_miss: parseInt(s.total_qc_miss, 10),
      total_qc_fail: parseInt(s.total_qc_fail, 10),
      total_dev_done: parseInt(s.total_dev_done, 10),
    }));
  }
}
