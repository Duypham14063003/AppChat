import { getRepositoryToken } from '@nestjs/typeorm';
import { Test, TestingModule } from '@nestjs/testing';
import { getQueueToken } from '@nestjs/bullmq';
import { PayrollConfig } from '../entities/payroll-config.entity';
import { HR_REMINDERS_QUEUE } from './attendance-reminder.processor';
import { AttendanceReminderScheduler } from './attendance-reminder.scheduler';

describe('AttendanceReminderScheduler', () => {
  let scheduler: AttendanceReminderScheduler;
  let configRepo: {
    find: jest.Mock;
  };
  let queue: {
    upsertJobScheduler: jest.Mock;
    removeJobScheduler: jest.Mock;
  };

  const config = (override: Partial<PayrollConfig> = {}) =>
    ({
      id: 1,
      user_id: 'user-1',
      checkin_reminder_time: '08:05',
      checkout_reminder_time: '17:30',
      auto_checkout_enabled: true,
      auto_checkout_time: '23:00',
      ...override,
    }) as PayrollConfig;

  beforeEach(async () => {
    configRepo = {
      find: jest.fn(),
    };
    queue = {
      upsertJobScheduler: jest.fn(),
      removeJobScheduler: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AttendanceReminderScheduler,
        {
          provide: getRepositoryToken(PayrollConfig),
          useValue: configRepo,
        },
        {
          provide: getQueueToken(HR_REMINDERS_QUEUE),
          useValue: queue,
        },
      ],
    }).compile();

    scheduler = module.get(AttendanceReminderScheduler);
  });

  it('reconciles startup schedules for all user configs', async () => {
    configRepo.find.mockResolvedValue([
      config({ user_id: 'user-1' }),
      config({ user_id: 'user-2', checkin_reminder_time: null }),
    ]);

    await scheduler.reconcileAll();

    expect(queue.upsertJobScheduler).toHaveBeenCalledWith(
      'hr-reminder:user-1:checkin-reminder',
      { pattern: '5 8 * * *', tz: 'Asia/Ho_Chi_Minh' },
      expect.objectContaining({
        name: 'checkin-reminder',
        data: { user_id: 'user-1' },
      }),
    );
    expect(queue.removeJobScheduler).toHaveBeenCalledWith(
      'hr-reminder:user-2:checkin-reminder',
    );
  });

  it('removes disabled reminder jobs for a user', async () => {
    await scheduler.reconcileUser(
      config({
        checkin_reminder_time: null,
        checkout_reminder_time: null,
        auto_checkout_enabled: false,
      }),
    );

    expect(queue.removeJobScheduler).toHaveBeenCalledWith(
      'hr-reminder:user-1:checkin-reminder',
    );
    expect(queue.removeJobScheduler).toHaveBeenCalledWith(
      'hr-reminder:user-1:checkout-reminder',
    );
    expect(queue.removeJobScheduler).toHaveBeenCalledWith(
      'hr-reminder:user-1:auto-checkout',
    );
  });

  it('uses stable per-user scheduler ids and job payloads', async () => {
    await scheduler.reconcileUser(config({ user_id: 'user-42' }));

    expect(queue.upsertJobScheduler).toHaveBeenCalledWith(
      'hr-reminder:user-42:auto-checkout',
      { pattern: '0 23 * * *', tz: 'Asia/Ho_Chi_Minh' },
      expect.objectContaining({
        name: 'auto-checkout',
        data: { user_id: 'user-42' },
        opts: expect.objectContaining({
          attempts: 3,
        }),
      }),
    );
  });

  it('registers stable organization statistics schedules on startup', async () => {
    configRepo.find.mockResolvedValue([]);

    await scheduler.onModuleInit();

    expect(queue.upsertJobScheduler).toHaveBeenCalledWith(
      'hr-reminder:organization:daily-report-morning-statistics',
      { pattern: '0 10 * * 1-6', tz: 'Asia/Ho_Chi_Minh' },
      expect.objectContaining({
        name: 'daily-report-morning-statistics',
        data: {},
      }),
    );
    expect(queue.upsertJobScheduler).toHaveBeenCalledWith(
      'hr-reminder:organization:daily-report-evening-statistics',
      { pattern: '30 18 * * 1-5', tz: 'Asia/Ho_Chi_Minh' },
      expect.objectContaining({
        name: 'daily-report-evening-statistics',
        data: {},
      }),
    );
  });
});
