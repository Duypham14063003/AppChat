import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import type { Job } from 'bullmq';
import { PayrollConfig } from '../entities/payroll-config.entity.js';
import { User } from '../../auth/entities/user.entity.js';
import { UserSession } from '../../auth/entities/user-session.entity.js';
import { FirebaseService } from '../../notification/services/firebase.service.js';
import { OdooService } from '../../auth/services/odoo.service.js';
import { RewardsService } from '../../rewards/rewards.service.js';
import { DailyReportStatisticsService } from '../services/daily-report-statistics.service.js';
import { ContractReminderService } from '../services/contract-reminder.service.js';

export const HR_REMINDERS_QUEUE = 'hr-reminders';
const AUTO_CHECKOUT_MAX_LATENESS_MS = 60 * 60 * 1000;
const HR_TIMEZONE = 'Asia/Ho_Chi_Minh';

type PushStats = {
  attempted: number;
  sent: number;
  failed: number;
  skipped: number;
  firebaseEnabled: boolean;
};

@Processor(HR_REMINDERS_QUEUE)
export class AttendanceReminderProcessor extends WorkerHost {
  private readonly logger = new Logger(AttendanceReminderProcessor.name);

  constructor(
    @InjectRepository(PayrollConfig)
    private readonly configRepo: Repository<PayrollConfig>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    @InjectRepository(UserSession)
    private readonly sessionRepo: Repository<UserSession>,
    private readonly firebaseService: FirebaseService,
    private readonly odooService: OdooService,
    private readonly rewardsService: RewardsService,
    private readonly statisticsService: DailyReportStatisticsService,
    private readonly contractReminderService: ContractReminderService,
  ) {
    super();
  }

  async process(job: Job<{ user_id?: string }>): Promise<void> {
    if (job.name === 'employee-contract-expiry-reminders') {
      await this.contractReminderService.process();
      return;
    }
    if (
      job.name === 'daily-report-morning-statistics' ||
      job.name === 'daily-report-evening-statistics'
    ) {
      await this.statisticsService.publish(
        job.name === 'daily-report-morning-statistics' ? 'morning' : 'evening',
      );
      return;
    }
    const userId = job.data?.user_id;
    if (!userId) {
      this.logger.warn(`Reminder job ${job.name} missing user_id`);
      return;
    }

    const config = await this.configRepo.findOne({
      where: { user_id: userId },
    });
    if (!config) return;

    switch (job.name) {
      case 'checkin-reminder':
        await this.handleCheckinReminder(config, userId);
        break;
      case 'checkout-reminder':
        await this.handleCheckoutReminder(config, userId);
        break;
      case 'auto-checkout':
        await this.handleAutoCheckout(
          config,
          userId,
          this.getScheduledAutoCheckoutTime(job),
        );
        break;
    }
  }

  private async handleCheckinReminder(config: PayrollConfig, userId: string) {
    if (!config.checkin_reminder_time) return;

    const user = await this.userRepo.findOne({
      where: { id: userId, is_active: true },
    });
    if (!user) return;

    const employeeId = await this.resolveEmployeeId(user);
    const existing = await this.odooService.findOpenAttendance(employeeId);
    const todaySessions =
      await this.odooService.fetchTodayAttendance(employeeId);
    let pushStats = this.emptyPushStats();
    if (!existing && todaySessions.length === 0) {
      pushStats = await this.sendPush(
        user.id,
        'Nhắc nhở checkin',
        'Bạn chưa checkin hôm nay. Bấm để checkin.',
        { type: 'hr_checkin_reminder' },
      );
    }
    this.logger.log(
      `Checkin reminder job completed for user ${userId}: eligible=${!existing && todaySessions.length === 0}, ${this.formatPushStats(pushStats)}`,
    );
  }

  private async handleCheckoutReminder(config: PayrollConfig, userId: string) {
    if (!config.checkout_reminder_time) return;

    const user = await this.userRepo.findOne({
      where: { id: userId, is_active: true },
    });
    if (!user) return;

    const employeeId = await this.resolveEmployeeId(user);
    const openSession = await this.odooService.findOpenAttendance(employeeId);

    let totalPushStats = this.emptyPushStats();
    if (openSession) {
      totalPushStats = await this.sendPush(
        userId,
        'Nhắc nhở checkout',
        'Bạn chưa checkout hôm nay. Bấm để checkout.',
        { type: 'hr_checkout_reminder' },
      );
    }
    this.logger.log(
      `Checkout reminder job completed for user ${userId}: open_sessions=${openSession ? 1 : 0}, ${this.formatPushStats(totalPushStats)}`,
    );
  }

  private async handleAutoCheckout(
    config: PayrollConfig,
    userId: string,
    scheduledAt: Date | null,
  ) {
    if (!config.auto_checkout_enabled) return;
    if (!scheduledAt) {
      this.logger.warn(
        `Skipping auto-checkout for user ${userId}: missing scheduled cutoff`,
      );
      return;
    }

    const now = new Date();
    if (this.isStaleAutoCheckout(scheduledAt, now)) {
      this.logger.warn(
        `Skipping stale auto-checkout for user ${userId}: scheduled_at=${scheduledAt.toISOString()}, processed_at=${now.toISOString()}`,
      );
      return;
    }

    const user = await this.userRepo.findOne({
      where: { id: userId, is_active: true },
    });
    if (!user) return;

    const employeeId = await this.resolveEmployeeId(user);
    const openSession = await this.odooService.findAutoCheckoutAttendance(
      employeeId,
      scheduledAt,
    );
    let totalPushStats = this.emptyPushStats();
    let updated = false;

    if (openSession) {
      updated = await this.odooService.checkoutAttendance(
        openSession.id,
        scheduledAt,
      );
      if (updated) {
        await this.tryAwardAutoCheckout(userId, openSession.id);
        const timeStr = scheduledAt.toLocaleTimeString('vi-VN', {
          hour: '2-digit',
          minute: '2-digit',
          timeZone: HR_TIMEZONE,
        });
        totalPushStats = await this.sendPush(
          userId,
          'Tự động checkout',
          `Hệ thống đã tự động checkout cho bạn lúc ${timeStr}.`,
          { type: 'hr_auto_checkout' },
        );
      }
    }
    this.logger.log(
      `Auto-checkout completed for user ${userId}: records_updated=${updated ? 1 : 0}, ${this.formatPushStats(totalPushStats)}`,
    );
  }

  private getScheduledAutoCheckoutTime(
    job: Job<{ user_id?: string }>,
  ): Date | null {
    const prevMillis = job.opts.prevMillis;
    if (typeof prevMillis !== 'number' || !Number.isFinite(prevMillis)) {
      return null;
    }

    const scheduledAt = new Date(prevMillis);
    if (Number.isNaN(scheduledAt.getTime())) {
      return null;
    }

    return scheduledAt;
  }

  private isStaleAutoCheckout(scheduledAt: Date, processedAt: Date) {
    return (
      processedAt.getTime() - scheduledAt.getTime() >
      AUTO_CHECKOUT_MAX_LATENESS_MS
    );
  }

  private async resolveEmployeeId(user: User): Promise<number> {
    if (user.odoo_employee_id) {
      return user.odoo_employee_id;
    }

    const employeeId =
      await this.odooService.findEmployeeIdByUserUidOrEmployeeId(user.odoo_uid);
    if (!employeeId) {
      throw new Error(`Missing Odoo employee mapping for user ${user.id}`);
    }

    user.odoo_employee_id = employeeId;
    await this.userRepo.save(user);
    return employeeId;
  }

  private async sendPush(
    userId: string,
    title: string,
    body: string,
    data: Record<string, string>,
  ): Promise<PushStats> {
    const stats = this.emptyPushStats();
    stats.firebaseEnabled = this.firebaseService.isEnabled();
    if (!stats.firebaseEnabled) {
      this.logger.warn(
        `Push skipped for user ${userId}: Firebase is not enabled`,
      );
      return stats;
    }

    const sessions = await this.sessionRepo.find({
      where: { user_id: userId },
      select: ['id', 'fcm_token'],
    });
    for (const s of sessions) {
      if (!s.fcm_token) {
        stats.skipped += 1;
        continue;
      }

      stats.attempted += 1;
      try {
        const sent = await this.firebaseService.sendPush(
          s.fcm_token,
          title,
          body,
          data,
        );
        if (sent) {
          stats.sent += 1;
        } else {
          stats.failed += 1;
        }
      } catch (err: any) {
        this.logger.error(
          `Failed to send attendance push notification to session ${s.id}: ${err.message}`,
        );
        stats.failed += 1;
      }
    }

    this.logger.log(
      `Push result for user ${userId}, type=${data.type}: ${this.formatPushStats(stats)}`,
    );
    return stats;
  }

  private emptyPushStats(): PushStats {
    return {
      attempted: 0,
      sent: 0,
      failed: 0,
      skipped: 0,
      firebaseEnabled: this.firebaseService.isEnabled(),
    };
  }

  private formatPushStats(stats: PushStats) {
    return `push_attempted=${stats.attempted}, push_sent=${stats.sent}, push_failed=${stats.failed}, push_skipped=${stats.skipped}, firebase_enabled=${stats.firebaseEnabled}`;
  }

  private async tryAwardAutoCheckout(userId: string, attendanceId: number) {
    try {
      await this.rewardsService.awardAttendanceEvent(
        userId,
        'attendance_auto_checkout',
        String(attendanceId),
        { attendance_id: attendanceId },
      );
    } catch (error) {
      this.logger.warn(
        `Rewards award failed for attendance_auto_checkout user=${userId} attendance=${attendanceId}: ${String(error)}`,
      );
    }
  }
}
