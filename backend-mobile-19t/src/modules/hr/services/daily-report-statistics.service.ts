import { createHash } from 'node:crypto';
import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import { ChatService } from '../../chat/services/chat.service.js';
import { RedisPubSubService } from '../../chat/services/redis-pubsub.service.js';
import { User } from '../../auth/entities/user.entity.js';
import { UserRole } from '../../auth/entities/user-role.entity.js';
import {
  DailyReport,
  LeaveRequest,
  LeaveRequestDay,
} from '../entities/index.js';

export type DailyReportStatisticsWindow = 'morning' | 'evening';

type LeaveState = {
  full: boolean;
  morning: boolean;
  afternoon: boolean;
  duration: number;
};

@Injectable()
export class DailyReportStatisticsService {
  private readonly logger = new Logger(DailyReportStatisticsService.name);
  private readonly timezone = 'Asia/Ho_Chi_Minh';
  private readonly botId = '00000000-0000-0000-0000-000000000001';
  private readonly conversationId = '35353995-517b-4fcb-b4d7-e0f23c5f4042';

  constructor(
    @InjectRepository(User) private readonly userRepo: Repository<User>,
    @InjectRepository(UserRole)
    private readonly userRoleRepo: Repository<UserRole>,
    @InjectRepository(DailyReport)
    private readonly reportRepo: Repository<DailyReport>,
    @InjectRepository(LeaveRequest)
    private readonly leaveRepo: Repository<LeaveRequest>,
    @InjectRepository(LeaveRequestDay)
    private readonly leaveDayRepo: Repository<LeaveRequestDay>,
    private readonly chatService: ChatService,
    private readonly redis: RedisPubSubService,
    private readonly dataSource: DataSource,
  ) {}

  async publish(
    window: DailyReportStatisticsWindow,
    date = this.localDate(),
  ): Promise<void> {
    const key = `daily-report-statistics:${date}:${window}`;
    if (await this.redis.getCache(`${key}:done`)) return;
    const lockAcquired = await this.redis.setCacheIfAbsent(
      `${key}:lock`,
      '1',
      300,
    );
    if (!lockAcquired) return;

    try {
      const users = await this.loadEligibleUsers();
      const reports = await this.reportRepo.find({
        where: { report_date: date },
      });
      const reportTypes = new Set(
        reports.map((report) => `${report.user_id}:${report.report_type}`),
      );
      const leaves = await this.loadLeaveStates(date);
      const message = this.format(window, date, users, reportTypes, leaves);

      await this.ensureBotSetup();
      const id = this.stableMessageId(key);
      await this.chatService.sendMessage(
        this.botId,
        {
          conv_id: this.conversationId,
          content: message,
          type: 'text',
          id,
        },
        undefined,
        true,
      );
      await this.redis.setCache(`${key}:done`, '1', 60 * 60 * 36);
      this.logger.log(`Daily report statistics published: ${key}`);
    } catch (error) {
      await this.redis.deleteCache(`${key}:lock`);
      throw error;
    }
  }

  private async loadEligibleUsers(): Promise<User[]> {
    const adminUserIds = await this.userRoleRepo
      .createQueryBuilder('userRole')
      .innerJoin('userRole.role', 'role')
      .select('userRole.user_id', 'user_id')
      .where('LOWER(role.name) = :role', { role: 'admin' })
      .getRawMany<{ user_id: string }>();
    const excluded = new Set(adminUserIds.map((row) => row.user_id));
    const users = await this.userRepo.find({
      where: { is_active: true, is_bot: false },
      order: { name: 'ASC' },
    });
    return users.filter((user) => !excluded.has(user.id));
  }

  private async loadLeaveStates(
    date: string,
  ): Promise<Map<string, LeaveState>> {
    const days = await this.leaveDayRepo
      .createQueryBuilder('day')
      .innerJoinAndSelect('day.leave_request', 'leave')
      .where('day.leave_date = :date', { date })
      .andWhere('leave.status = :status', { status: 'approved' })
      .getMany();
    const result = new Map<string, LeaveState>();
    for (const day of days) {
      const leave = day.leave_request;
      if (!leave || leave.type === 'wfh' || leave.type === 'ot') continue;
      const state = result.get(leave.user_id) ?? {
        full: false,
        morning: false,
        afternoon: false,
        duration: 0,
      };
      const duration = Number(day.duration_days) || 0;
      state.duration += duration;
      if (state.duration >= 1) state.full = true;
      else if (day.half_day_part === 'morning') state.morning = true;
      else if (day.half_day_part === 'afternoon') state.afternoon = true;
      result.set(leave.user_id, state);
    }
    return result;
  }

  private format(
    window: DailyReportStatisticsWindow,
    date: string,
    users: User[],
    reports: Set<string>,
    leaves: Map<string, LeaveState>,
  ): string {
    const label = window === 'morning' ? 'SÁNG' : 'CUỐI NGÀY';
    const missingMorning: string[] = [];
    const missingEvening: string[] = [];
    const deferred: string[] = [];
    const off: string[] = [];
    let submitted = 0;
    for (const user of users) {
      const leave = leaves.get(user.id);
      const hasMorning = reports.has(`${user.id}:morning`);
      const hasEvening = reports.has(`${user.id}:evening`);
      if (leave?.full) {
        off.push(`${user.name} - OFF cả ngày`);
        continue;
      }
      if (window === 'morning') {
        if (hasMorning) submitted++;
        else if (leave?.morning)
          deferred.push(
            `${user.name} - OFF buổi sáng, bổ sung trong buổi chiều`,
          );
        else missingMorning.push(user.name);
      } else {
        if (!hasMorning && leave?.morning)
          missingMorning.push(`${user.name} - chưa bổ sung báo cáo sáng`);
        if (!hasEvening) missingEvening.push(user.name);
      }
    }
    const lines = [
      `📋 THỐNG KÊ BÁO CÁO ${label} - ${this.displayDate(date)}`,
      `👥 SỐ LƯỢNG: ${users.length} nhân sự`,
      '',
    ];
    if (window === 'morning') {
      lines.push(
        `✅ Đã báo cáo sáng: ${submitted}/${users.length - off.length}`,
      );
      this.appendSection(lines, '⚠️ Chưa báo cáo sáng', missingMorning);
      this.appendSection(lines, '🕒 Báo cáo được gia hạn', deferred);
    } else {
      this.appendSection(lines, '⚠️ Chưa bổ sung báo cáo sáng', missingMorning);
      this.appendSection(lines, '⚠️ Chưa báo cáo chiều', missingEvening);
    }
    this.appendSection(lines, '🏖️ Nghỉ đã duyệt', off);
    if (!missingMorning.length && !missingEvening.length)
      lines.push('✅ Không có báo cáo bắt buộc nào đang bị thiếu.');
    return lines.join('\n').trim();
  }

  private appendSection(lines: string[], title: string, values: string[]) {
    if (!values.length) return;
    lines.push(title);
    values.forEach((value, index) => lines.push(`${index + 1}. ${value}`));
    lines.push('');
  }

  private async ensureBotSetup() {
    const botRepo = this.dataSource.getRepository(User);
    const bot = await botRepo.findOne({ where: { id: this.botId } });
    if (!bot)
      await botRepo.save(
        botRepo.create({
          id: this.botId,
          name: 'Daily Report Bot',
          email: 'bot-daily-report@19t.vn',
          is_active: true,
          is_bot: true,
        }),
      );
    const convRepo = this.dataSource.getRepository('conversations');
    if (!(await convRepo.findOne({ where: { id: this.conversationId } })))
      await convRepo.insert({
        id: this.conversationId,
        type: 'GROUP',
        name: 'Báo cáo hàng ngày',
        created_at: new Date(),
      });
    const memberRepo = this.dataSource.getRepository('conversation_members');
    if (
      !(await memberRepo.findOne({
        where: { conv_id: this.conversationId, user_id: this.botId },
      }))
    )
      await memberRepo.insert({
        conv_id: this.conversationId,
        user_id: this.botId,
        role: 'admin',
        joined_at: new Date(),
      });
  }

  private stableMessageId(key: string) {
    const hex = createHash('sha256')
      .update(key)
      .digest('hex')
      .slice(0, 32)
      .split('');
    hex[12] = '5';
    hex[16] = ((parseInt(hex[16], 16) & 0x3) | 0x8).toString(16);
    return `${hex.slice(0, 8).join('')}-${hex.slice(8, 12).join('')}-${hex.slice(12, 16).join('')}-${hex.slice(16, 20).join('')}-${hex.slice(20).join('')}`;
  }

  private localDate() {
    return new Intl.DateTimeFormat('en-CA', { timeZone: this.timezone }).format(
      new Date(),
    );
  }
  private displayDate(date: string) {
    return new Date(`${date}T00:00:00+07:00`).toLocaleDateString('vi-VN', {
      timeZone: this.timezone,
    });
  }
}
