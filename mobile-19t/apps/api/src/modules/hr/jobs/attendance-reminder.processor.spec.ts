import type { Job, Queue } from 'bullmq';
import { AttendanceReminderProcessor } from './attendance-reminder.processor';
import { PayrollConfig } from '../entities/payroll-config.entity';

describe('AttendanceReminderProcessor', () => {
  const queue = {
    upsertJobScheduler: jest.fn(),
  } as unknown as Queue;

  const attendanceRepo = {
    find: jest.fn(),
    findOne: jest.fn(),
    save: jest.fn(),
  } as any;

  const configRepo = {
    findOne: jest.fn(),
  } as any;

  const userRepo = {
    find: jest.fn(),
  } as any;

  const sessionRepo = {
    find: jest.fn(),
  } as any;

  const firebaseService = {
    isEnabled: jest.fn().mockReturnValue(true),
    sendPush: jest.fn().mockResolvedValue(true),
  } as any;

  const buildConfig = (
    overrides: Partial<PayrollConfig> = {},
  ): PayrollConfig =>
    ({
      id: 1,
      payroll_start_day: 1,
      standard_hours_per_day: 8,
      standard_days_per_month: 22,
      work_start_time: '08:00',
      checkin_reminder_time: '09:30',
      checkout_reminder_time: '18:00',
      auto_checkout_enabled: true,
      auto_checkout_time: '23:59',
      updated_at: new Date('2026-04-21T00:00:00.000Z'),
      ...overrides,
    }) as PayrollConfig;

  let processor: AttendanceReminderProcessor;

  beforeEach(() => {
    jest.clearAllMocks();
    processor = new AttendanceReminderProcessor(
      queue,
      attendanceRepo,
      configRepo,
      userRepo,
      sessionRepo,
      firebaseService,
    );
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  it('registers stable per-minute schedulers on startup', async () => {
    await processor.onModuleInit();

    expect(queue.upsertJobScheduler).toHaveBeenCalledTimes(3);
    expect(queue.upsertJobScheduler).toHaveBeenNthCalledWith(
      1,
      'hr-checkin-reminder-minute',
      { every: 60_000 },
      { name: 'checkin-reminder' },
    );
    expect(queue.upsertJobScheduler).toHaveBeenNthCalledWith(
      2,
      'hr-checkout-reminder-minute',
      { every: 60_000 },
      { name: 'checkout-reminder' },
    );
    expect(queue.upsertJobScheduler).toHaveBeenNthCalledWith(
      3,
      'hr-auto-checkout-minute',
      { every: 60_000 },
      { name: 'auto-checkout' },
    );
  });

  it('auto-checkout uses configured time and marks attendance ready for sync', async () => {
    jest.useFakeTimers().setSystemTime(new Date('2026-04-21T16:59:00.000Z'));
    configRepo.findOne.mockResolvedValue(buildConfig());
    attendanceRepo.find.mockResolvedValue([
      {
        id: 'att-1',
        user_id: 'user-1',
        checkin_at: new Date('2026-04-21T01:00:00.000Z'),
        checkout_at: null,
        total_hours: null,
        ot_hours: null,
        odoo_synced: true,
        odoo_synced_at: new Date('2026-04-21T12:00:00.000Z'),
      },
    ]);
    sessionRepo.find.mockResolvedValue([{ id: 's1', fcm_token: 'token-1' }]);

    await processor.process({ name: 'auto-checkout' } as Job);

    expect(attendanceRepo.save).toHaveBeenCalledWith(
      expect.objectContaining({
        checkout_at: new Date('2026-04-21T16:59:00.000Z'),
        total_hours: 15.98,
        ot_hours: 7.98,
        odoo_synced: false,
        odoo_synced_at: null,
      }),
    );
    expect(firebaseService.sendPush).toHaveBeenCalledWith(
      'token-1',
      'Tự động checkout',
      expect.stringContaining('23:59'),
      { type: 'hr_auto_checkout' },
    );
  });
});
