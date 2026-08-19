import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { PayrollConfig } from '../entities/payroll-config.entity';
import { AttendanceReminderScheduler } from '../jobs/attendance-reminder.scheduler';
import { PayrollConfigService } from './payroll-config.service';

describe('PayrollConfigService', () => {
  let service: PayrollConfigService;
  let configRepo: {
    findOne: jest.Mock;
    create: jest.Mock;
    save: jest.Mock;
  };
  let reminderScheduler: {
    reconcileUser: jest.Mock;
  };

  beforeEach(async () => {
    configRepo = {
      findOne: jest.fn(),
      create: jest.fn((payload) => ({
        id: 1,
        payroll_start_day: 1,
        standard_hours_per_day: 8,
        standard_days_per_month: 22,
        work_start_time: '08:00',
        checkin_reminder_time: null,
        checkout_reminder_time: null,
        auto_checkout_enabled: false,
        auto_checkout_time: '23:59',
        ...payload,
      })),
      save: jest.fn(async (payload) => payload),
    };
    reminderScheduler = {
      reconcileUser: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PayrollConfigService,
        {
          provide: getRepositoryToken(PayrollConfig),
          useValue: configRepo,
        },
        {
          provide: AttendanceReminderScheduler,
          useValue: reminderScheduler,
        },
      ],
    }).compile();

    service = module.get(PayrollConfigService);
  });

  it('returns the authenticated user payroll config', async () => {
    const existing = {
      id: 11,
      user_id: 'user-1',
      checkin_reminder_time: '08:00',
      standard_days_per_month: 26,
    } as PayrollConfig;
    configRepo.findOne.mockResolvedValue(existing);

    await expect(service.getConfig('user-1')).resolves.toMatchObject({
      user_id: 'user-1',
      standard_days_per_month: 26,
    });
    expect(configRepo.findOne).toHaveBeenCalledWith({
      where: { user_id: 'user-1' },
    });
  });

  it('creates a default config for a user without one', async () => {
    configRepo.findOne.mockResolvedValue(null);

    const result = await service.getConfig('user-1');

    expect(configRepo.create).toHaveBeenCalledWith({ user_id: 'user-1' });
    expect(configRepo.save).toHaveBeenCalledWith(
      expect.objectContaining({ user_id: 'user-1' }),
    );
    expect(result.user_id).toBe('user-1');
    expect(result.standard_days_per_month).toBe(22);
  });

  it('updates only the provided user config and refreshes that user schedule', async () => {
    const existing = {
      id: 11,
      user_id: 'user-1',
      checkin_reminder_time: null,
      updated_at: new Date('2026-04-20T00:00:00Z'),
    } as PayrollConfig;
    configRepo.findOne.mockResolvedValue(existing);

    const result = await service.updateConfig('user-1', {
      checkin_reminder_time: '08:30',
    });

    expect(configRepo.save).toHaveBeenCalledWith(
      expect.objectContaining({
        id: 11,
        user_id: 'user-1',
        checkin_reminder_time: '08:30',
      }),
    );
    expect(reminderScheduler.reconcileUser).toHaveBeenCalledWith(result);
    expect(configRepo.findOne).not.toHaveBeenCalledWith({
      where: { user_id: 'user-2' },
    });
  });
});
