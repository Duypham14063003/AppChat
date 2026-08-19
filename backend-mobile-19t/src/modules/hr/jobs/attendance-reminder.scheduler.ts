import { InjectQueue } from '@nestjs/bullmq';
import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Queue } from 'bullmq';
import { Repository } from 'typeorm';
import { PayrollConfig } from '../entities/payroll-config.entity.js';
import { HR_REMINDERS_QUEUE } from './attendance-reminder.processor.js';

type ReminderJobName =
  | 'checkin-reminder'
  | 'checkout-reminder'
  | 'auto-checkout'
  | 'daily-report-morning-statistics'
  | 'daily-report-evening-statistics';

@Injectable()
export class AttendanceReminderScheduler implements OnModuleInit {
  private readonly logger = new Logger(AttendanceReminderScheduler.name);
  private readonly timezone = 'Asia/Ho_Chi_Minh';

  constructor(
    @InjectRepository(PayrollConfig)
    private readonly configRepo: Repository<PayrollConfig>,
    @InjectQueue(HR_REMINDERS_QUEUE)
    private readonly remindersQueue: Queue,
  ) { }

  async onModuleInit(): Promise<void> {
    await this.reconcileAll();
    await this.reconcileStatistics();
    await this.reconcileContractReminders();
  }

  private async reconcileContractReminders() {
    await this.remindersQueue.upsertJobScheduler(
      'hr-reminder:organization:contract-expiry',
      { pattern: '0 8 * * *', tz: this.timezone },
      { name: 'employee-contract-expiry-reminders', data: {}, opts: { attempts: 3, backoff: { type: 'exponential', delay: 2000 } } },
    );
  }

  private async reconcileStatistics() {
    for (const [jobName, time, weekdays] of [
      // The company works Saturday mornings and is closed on Sundays.
      ['daily-report-morning-statistics', '10:00', '1-6'],
      ['daily-report-evening-statistics', '18:30', '1-5'],
    ] as const) {
      await this.remindersQueue.upsertJobScheduler(
        `hr-reminder:organization:${jobName}`,
        { pattern: this.toCron(time, weekdays), tz: this.timezone },
        {
          name: jobName,
          data: {},
          opts: { attempts: 3, backoff: { type: 'exponential', delay: 2000 } },
        },
      );
    }
  }

  async reconcileAll(): Promise<void> {
    const configs = await this.configRepo.find();
    for (const config of configs) {
      await this.reconcileUser(config);
    }
    this.logger.log(
      `Attendance reminders reconciled for ${configs.length} users`,
    );
  }

  async reconcileUser(config: PayrollConfig): Promise<void> {
    await this.reconcileJob(
      config,
      'checkin-reminder',
      config.checkin_reminder_time,
    );
    await this.reconcileJob(
      config,
      'checkout-reminder',
      config.checkout_reminder_time,
    );

    if (config.auto_checkout_enabled) {
      await this.reconcileJob(
        config,
        'auto-checkout',
        config.auto_checkout_time,
      );
    } else {
      await this.removeJob(config.user_id, 'auto-checkout');
    }
  }

  private async reconcileJob(
    config: PayrollConfig,
    jobName: ReminderJobName,
    time: string | null,
  ) {
    if (!time) {
      await this.removeJob(config.user_id, jobName);
      return;
    }

    const schedulerId = this.schedulerId(config.user_id, jobName);
    await this.remindersQueue.upsertJobScheduler(
      schedulerId,
      {
        pattern: this.toDailyCron(time),
        tz: this.timezone,
      },
      {
        name: jobName,
        data: { user_id: config.user_id },
        opts: {
          attempts: 3,
          backoff: { type: 'exponential', delay: 2000 },
        },
      },
    );
  }

  private async removeJob(userId: string, jobName: ReminderJobName) {
    await this.remindersQueue.removeJobScheduler(
      this.schedulerId(userId, jobName),
    );
  }

  private schedulerId(userId: string, jobName: ReminderJobName) {
    return `hr-reminder:${userId}:${jobName}`;
  }

  private toDailyCron(time: string) {
    return this.toCron(time, '*');
  }

  private toCron(time: string, weekdays: string) {
    const [hour = '0', minute = '0'] = time.split(':');
    return `${Number(minute)} ${Number(hour)} * * ${weekdays}`;
  }
}
