import { Processor, WorkerHost, InjectQueue } from '@nestjs/bullmq';
import { Logger, OnModuleInit } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Between, IsNull } from 'typeorm';
import { Queue, type Job } from 'bullmq';
import { Attendance } from '../entities/attendance.entity.js';
import { PayrollConfig } from '../entities/payroll-config.entity.js';
import { User } from '../../auth/entities/user.entity.js';
import { UserSession } from '../../auth/entities/user-session.entity.js';
import { FirebaseService } from '../../notification/services/firebase.service.js';

export const HR_REMINDERS_QUEUE = 'hr-reminders';
const BUSINESS_TZ_OFFSET_MS = 7 * 60 * 60 * 1000;

@Processor(HR_REMINDERS_QUEUE)
export class AttendanceReminderProcessor
  extends WorkerHost
  implements OnModuleInit
{
  private readonly logger = new Logger(AttendanceReminderProcessor.name);

  constructor(
    @InjectQueue(HR_REMINDERS_QUEUE)
    private readonly queue: Queue,
    @InjectRepository(Attendance)
    private readonly attendanceRepo: Repository<Attendance>,
    @InjectRepository(PayrollConfig)
    private readonly configRepo: Repository<PayrollConfig>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    @InjectRepository(UserSession)
    private readonly sessionRepo: Repository<UserSession>,
    private readonly firebaseService: FirebaseService,
  ) {
    super();
  }

  async onModuleInit(): Promise<void> {
    await this.registerSchedulers();
  }

  async registerSchedulers(): Promise<void> {
    await this.queue.upsertJobScheduler(
      'hr-checkin-reminder-minute',
      { every: 60_000 },
      { name: 'checkin-reminder' },
    );
    await this.queue.upsertJobScheduler(
      'hr-checkout-reminder-minute',
      { every: 60_000 },
      { name: 'checkout-reminder' },
    );
    await this.queue.upsertJobScheduler(
      'hr-auto-checkout-minute',
      { every: 60_000 },
      { name: 'auto-checkout' },
    );
    this.logger.log('HR reminder schedulers registered: every minute');
  }

  async process(job: Job): Promise<void> {
    const config = await this.configRepo.findOne({ where: { id: 1 } });
    if (!config) return;

    switch (job.name) {
      case 'checkin-reminder':
        await this.handleCheckinReminder(config);
        break;
      case 'checkout-reminder':
        await this.handleCheckoutReminder(config);
        break;
      case 'auto-checkout':
        await this.handleAutoCheckout(config);
        break;
    }
  }

  private async handleCheckinReminder(config: PayrollConfig) {
    if (!this.isConfiguredTimeDue(config.checkin_reminder_time)) return;

    const { dayStart, dayEnd } = this.getBusinessDayRange();
    const activeUsers = await this.userRepo.find({
      where: { is_active: true },
    });

    for (const user of activeUsers) {
      const existing = await this.attendanceRepo.findOne({
        where: { user_id: user.id, checkin_at: Between(dayStart, dayEnd) },
      });
      if (!existing) {
        await this.sendPush(
          user.id,
          'Nhắc nhở checkin',
          'Bạn chưa checkin hôm nay. Bấm để checkin.',
          { type: 'hr_checkin_reminder' },
        );
      }
    }
    this.logger.log('Checkin reminder job completed');
  }

  private async handleCheckoutReminder(config: PayrollConfig) {
    if (!this.isConfiguredTimeDue(config.checkout_reminder_time)) return;

    const { dayStart, dayEnd } = this.getBusinessDayRange();
    const uncheckedOut = await this.attendanceRepo.find({
      where: {
        checkin_at: Between(dayStart, dayEnd),
        checkout_at: IsNull(),
      },
    });

    for (const record of uncheckedOut) {
      await this.sendPush(
        record.user_id,
        'Nhắc nhở checkout',
        'Bạn chưa checkout hôm nay. Bấm để checkout.',
        { type: 'hr_checkout_reminder' },
      );
    }
    this.logger.log('Checkout reminder job completed');
  }

  private async handleAutoCheckout(config: PayrollConfig) {
    const checkoutAt = this.resolveScheduledAutoCheckoutAt(
      config.auto_checkout_time,
    );
    if (!config.auto_checkout_enabled || checkoutAt == null) return;

    const { dayStart, dayEnd } = this.getBusinessDayRange(checkoutAt);
    const uncheckedOut = await this.attendanceRepo.find({
      where: {
        checkin_at: Between(dayStart, dayEnd),
        checkout_at: IsNull(),
      },
    });

    for (const record of uncheckedOut) {
      const diffMs = checkoutAt.getTime() - record.checkin_at.getTime();
      const totalHours = Math.round((diffMs / (1000 * 60 * 60)) * 100) / 100;
      const otHours = Math.max(
        0,
        Math.round((totalHours - Number(config.standard_hours_per_day)) * 100) /
          100,
      );

      record.checkout_at = checkoutAt;
      record.total_hours = totalHours;
      record.ot_hours = otHours;
      record.odoo_synced = false;
      record.odoo_synced_at = null;
      await this.attendanceRepo.save(record);

      const timeStr = this.formatBusinessTime(checkoutAt);
      await this.sendPush(
        record.user_id,
        'Tự động checkout',
        `Hệ thống đã tự động checkout cho bạn lúc ${timeStr}.`,
        { type: 'hr_auto_checkout' },
      );
    }
    this.logger.log(`Auto-checkout: ${uncheckedOut.length} records updated`);
  }

  private isConfiguredTimeDue(
    configuredTime: string | null,
    graceMinutes = 0,
    now = new Date(),
  ): boolean {
    if (!configuredTime) return false;
    const configuredMinutes = this.parseTimeToMinutes(configuredTime);
    if (configuredMinutes == null) return false;

    const businessNow = this.toBusinessDate(now);
    const currentMinutes =
      businessNow.getUTCHours() * 60 + businessNow.getUTCMinutes();
    const minuteDelta = currentMinutes - configuredMinutes;
    const wrappedDelta = currentMinutes + 1440 - configuredMinutes;

    return (
      (minuteDelta >= 0 && minuteDelta <= graceMinutes) ||
      (wrappedDelta >= 0 && wrappedDelta <= graceMinutes)
    );
  }

  private resolveScheduledAutoCheckoutAt(
    configuredTime: string,
    now = new Date(),
  ): Date | null {
    if (!this.isConfiguredTimeDue(configuredTime, 2, now)) return null;

    const configuredMinutes = this.parseTimeToMinutes(configuredTime);
    if (configuredMinutes == null) return null;

    const businessNow = this.toBusinessDate(now);
    const currentMinutes =
      businessNow.getUTCHours() * 60 + businessNow.getUTCMinutes();

    const targetBusinessDate = new Date(businessNow);
    if (currentMinutes < configuredMinutes) {
      targetBusinessDate.setUTCDate(targetBusinessDate.getUTCDate() - 1);
    }

    const [hours, minutes] = configuredTime.split(':').map(Number);
    const scheduledUtcMs =
      Date.UTC(
        targetBusinessDate.getUTCFullYear(),
        targetBusinessDate.getUTCMonth(),
        targetBusinessDate.getUTCDate(),
        hours,
        minutes,
      ) - BUSINESS_TZ_OFFSET_MS;
    return new Date(scheduledUtcMs);
  }

  private getBusinessDayRange(reference = new Date()) {
    const businessReference = this.toBusinessDate(reference);
    const dayStart = new Date(
      Date.UTC(
        businessReference.getUTCFullYear(),
        businessReference.getUTCMonth(),
        businessReference.getUTCDate(),
      ) - BUSINESS_TZ_OFFSET_MS,
    );
    const dayEnd = new Date(dayStart.getTime() + 24 * 60 * 60 * 1000);
    return { dayStart, dayEnd };
  }

  private formatBusinessTime(reference: Date): string {
    const businessDate = this.toBusinessDate(reference);
    return `${businessDate.getUTCHours().toString().padStart(2, '0')}:${businessDate.getUTCMinutes().toString().padStart(2, '0')}`;
  }

  private parseTimeToMinutes(value: string): number | null {
    const parts = value.split(':');
    if (parts.length < 2) return null;
    const hours = Number(parts[0]);
    const minutes = Number(parts[1]);
    if (
      Number.isNaN(hours) ||
      Number.isNaN(minutes) ||
      hours < 0 ||
      hours > 23 ||
      minutes < 0 ||
      minutes > 59
    ) {
      return null;
    }
    return hours * 60 + minutes;
  }

  private toBusinessDate(reference: Date): Date {
    return new Date(reference.getTime() + BUSINESS_TZ_OFFSET_MS);
  }

  private async sendPush(
    userId: string,
    title: string,
    body: string,
    data: Record<string, string>,
  ) {
    if (!this.firebaseService.isEnabled()) {
      this.logger.warn(
        `Push skipped for user ${userId}: Firebase is not enabled`,
      );
      return;
    }

    const sessions = await this.sessionRepo.find({
      where: { user_id: userId },
      select: ['id', 'fcm_token'],
    });

    if (sessions.length === 0) {
      this.logger.warn(`Push skipped for user ${userId}: no sessions found`);
      return;
    }

    let attempted = 0;
    let sent = 0;
    for (const s of sessions) {
      if (!s.fcm_token) continue;
      attempted += 1;
      const ok = await this.firebaseService.sendPush(
        s.fcm_token,
        title,
        body,
        data,
      );
      if (ok) {
        sent += 1;
      } else {
        this.logger.warn(
          `Push send failed for user ${userId}, session ${s.id}, type ${data.type}`,
        );
      }
    }

    if (attempted === 0) {
      this.logger.warn(
        `Push skipped for user ${userId}: sessions exist but no FCM token`,
      );
      return;
    }

    this.logger.log(
      `Push ${data.type} sent to ${sent}/${attempted} token(s) for user ${userId}`,
    );
  }
}
