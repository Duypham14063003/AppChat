import { getRepositoryToken } from '@nestjs/typeorm';
import { Test, TestingModule } from '@nestjs/testing';
import { PayrollConfig } from '../entities/payroll-config.entity';
import { User } from '../../auth/entities/user.entity';
import { UserSession } from '../../auth/entities/user-session.entity';
import { FirebaseService } from '../../notification/services/firebase.service';
import { AttendanceReminderProcessor } from './attendance-reminder.processor';
import { OdooService } from '../../auth/services/odoo.service';
import { RewardsService } from '../../rewards/rewards.service';
import { DailyReportStatisticsService } from '../services/daily-report-statistics.service';
import { ContractReminderService } from '../services/contract-reminder.service';

describe('AttendanceReminderProcessor', () => {
  let processor: AttendanceReminderProcessor;
  let configRepo: {
    findOne: jest.Mock;
  };
  let userRepo: {
    findOne: jest.Mock;
    save: jest.Mock;
  };
  let sessionRepo: {
    find: jest.Mock;
  };
  let firebaseService: {
    isEnabled: jest.Mock;
    sendPush: jest.Mock;
  };
  let odooService: {
    findOpenAttendance: jest.Mock;
    findAutoCheckoutAttendance: jest.Mock;
    fetchTodayAttendance: jest.Mock;
    checkoutAttendance: jest.Mock;
    findEmployeeIdByUserUidOrEmployeeId: jest.Mock;
  };
  let rewardsService: {
    awardAttendanceEvent: jest.Mock;
  };
  let statisticsService: { publish: jest.Mock };
  let contractReminderService: { process: jest.Mock };
  const fixedNow = new Date('2026-04-23T03:30:00.000Z');

  beforeEach(async () => {
    jest.useFakeTimers().setSystemTime(fixedNow);
    configRepo = {
      findOne: jest.fn().mockResolvedValue({
        user_id: 'user-1',
        checkin_reminder_time: '08:00',
        checkout_reminder_time: '17:30',
        auto_checkout_enabled: true,
        auto_checkout_time: '23:00',
        standard_hours_per_day: 8,
      }),
    };
    userRepo = {
      findOne: jest.fn().mockResolvedValue({
        id: 'user-1',
        is_active: true,
        odoo_uid: 100,
        odoo_employee_id: 200,
      }),
      save: jest.fn(async (payload) => payload),
    };
    sessionRepo = {
      find: jest
        .fn()
        .mockResolvedValue([{ id: 'session-1', fcm_token: 'token-1' }]),
    };
    firebaseService = {
      isEnabled: jest.fn().mockReturnValue(true),
      sendPush: jest.fn().mockResolvedValue(true),
    };
    odooService = {
      findOpenAttendance: jest.fn().mockResolvedValue(null),
      findAutoCheckoutAttendance: jest.fn().mockResolvedValue(null),
      fetchTodayAttendance: jest.fn().mockResolvedValue([]),
      checkoutAttendance: jest.fn().mockResolvedValue(true),
      findEmployeeIdByUserUidOrEmployeeId: jest.fn().mockResolvedValue(200),
    };
    rewardsService = {
      awardAttendanceEvent: jest.fn().mockResolvedValue({
        awarded: true,
      }),
    };
    statisticsService = { publish: jest.fn().mockResolvedValue(undefined) };
    contractReminderService = { process: jest.fn().mockResolvedValue(undefined) };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AttendanceReminderProcessor,
        {
          provide: getRepositoryToken(PayrollConfig),
          useValue: configRepo,
        },
        {
          provide: getRepositoryToken(User),
          useValue: userRepo,
        },
        {
          provide: getRepositoryToken(UserSession),
          useValue: sessionRepo,
        },
        {
          provide: FirebaseService,
          useValue: firebaseService,
        },
        {
          provide: OdooService,
          useValue: odooService,
        },
        {
          provide: RewardsService,
          useValue: rewardsService,
        },
        {
          provide: DailyReportStatisticsService,
          useValue: statisticsService,
        },
        {
          provide: ContractReminderService,
          useValue: contractReminderService,
        },
      ],
    }).compile();

    processor = module.get(AttendanceReminderProcessor);
  });

  it('dispatches organization daily-report statistics without a user id', async () => {
    await processor.process({
      name: 'daily-report-evening-statistics',
      data: {},
    } as any);

    expect(statisticsService.publish).toHaveBeenCalledWith('evening');
    expect(configRepo.findOne).not.toHaveBeenCalled();
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  it('sends check-in reminder only when Odoo shows no attendance today', async () => {
    await processor.process({
      name: 'checkin-reminder',
      data: { user_id: 'user-1' },
    } as any);

    expect(odooService.fetchTodayAttendance).toHaveBeenCalledWith(200);
    expect(firebaseService.sendPush).toHaveBeenCalledWith(
      'token-1',
      'Nhắc nhở checkin',
      'Bạn chưa checkin hôm nay. Bấm để checkin.',
      { type: 'hr_checkin_reminder' },
    );
  });

  it('sends checkout reminder only for an open Odoo attendance session', async () => {
    odooService.findOpenAttendance.mockResolvedValue({
      id: 555,
      check_in: new Date().toISOString(),
      check_out: false,
    });

    await processor.process({
      name: 'checkout-reminder',
      data: { user_id: 'user-1' },
    } as any);

    expect(odooService.findOpenAttendance).toHaveBeenCalledWith(200);
    expect(firebaseService.sendPush).toHaveBeenCalledWith(
      'token-1',
      'Nhắc nhở checkout',
      'Bạn chưa checkout hôm nay. Bấm để checkout.',
      { type: 'hr_checkout_reminder' },
    );
  });

  it('auto-checkout closes the configured user open Odoo session', async () => {
    const scheduledAt = new Date('2026-04-23T03:05:00.000Z');
    odooService.findOpenAttendance.mockResolvedValue({
      id: 777,
      check_in: new Date(Date.now() - 9 * 60 * 60 * 1000).toISOString(),
      check_out: false,
    });
    odooService.findAutoCheckoutAttendance.mockResolvedValue({
      id: 777,
      check_in: new Date('2026-04-23T00:00:00.000Z').toISOString(),
      check_out: false,
    });

    await processor.process({
      name: 'auto-checkout',
      data: { user_id: 'user-1' },
      opts: { prevMillis: scheduledAt.getTime() },
    } as any);

    expect(odooService.findAutoCheckoutAttendance).toHaveBeenCalledWith(
      200,
      scheduledAt,
    );
    expect(odooService.checkoutAttendance).toHaveBeenCalledWith(
      777,
      scheduledAt,
    );
    expect(rewardsService.awardAttendanceEvent).toHaveBeenCalledWith(
      'user-1',
      'attendance_auto_checkout',
      '777',
      { attendance_id: 777 },
    );
    expect(firebaseService.sendPush).toHaveBeenCalledWith(
      'token-1',
      'Tự động checkout',
      expect.stringContaining('10:05'),
      { type: 'hr_auto_checkout' },
    );
  });

  it('skips stale auto-checkout jobs that are too late', async () => {
    const scheduledAt = new Date('2026-04-22T18:05:00.000Z');

    await processor.process({
      name: 'auto-checkout',
      data: { user_id: 'user-1' },
      opts: { prevMillis: scheduledAt.getTime() },
    } as any);

    expect(userRepo.findOne).not.toHaveBeenCalledWith({
      where: { id: 'user-1', is_active: true },
    });
    expect(odooService.findAutoCheckoutAttendance).not.toHaveBeenCalled();
    expect(odooService.checkoutAttendance).not.toHaveBeenCalled();
    expect(firebaseService.sendPush).not.toHaveBeenCalled();
  });

  it('does not close a session when no eligible scheduled-cutoff session exists', async () => {
    const scheduledAt = new Date('2026-04-23T03:05:00.000Z');
    odooService.findAutoCheckoutAttendance.mockResolvedValue(null);

    await processor.process({
      name: 'auto-checkout',
      data: { user_id: 'user-1' },
      opts: { prevMillis: scheduledAt.getTime() },
    } as any);

    expect(odooService.findAutoCheckoutAttendance).toHaveBeenCalledWith(
      200,
      scheduledAt,
    );
    expect(odooService.checkoutAttendance).not.toHaveBeenCalled();
    expect(firebaseService.sendPush).not.toHaveBeenCalled();
  });

  it('tracks failed push delivery attempts', async () => {
    firebaseService.sendPush.mockResolvedValue(false);
    odooService.findOpenAttendance.mockResolvedValue({
      id: 555,
      check_in: new Date().toISOString(),
      check_out: false,
    });

    await processor.process({
      name: 'checkout-reminder',
      data: { user_id: 'user-1' },
    } as any);

    expect(firebaseService.sendPush).toHaveBeenCalledTimes(1);
  });
});
