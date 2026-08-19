import { Test, TestingModule } from '@nestjs/testing';
import {
  BadRequestException,
  ForbiddenException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { getRepositoryToken } from '@nestjs/typeorm';
import { AttendanceService } from './attendance.service';
import { PayrollConfig } from '../entities/payroll-config.entity';
import { LeaveRequest } from '../entities/leave-request.entity';
import { LeaveRequestDay } from '../entities/leave-request-day.entity';
import { OdooService } from '../../auth/services/odoo.service';
import { User } from '../../auth/entities/user.entity';
import { RewardsService } from '../../rewards/rewards.service';

describe('AttendanceService', () => {
  let service: AttendanceService;
  let configRepo: {
    findOne: jest.Mock;
    create: jest.Mock;
    save: jest.Mock;
  };
  let leaveRepo: {
    find: jest.Mock;
  };
  let leaveDayRepo: {
    find: jest.Mock;
  };
  let userRepo: {
    findOne: jest.Mock;
    save: jest.Mock;
  };
  let odooService: {
    fetchAttendanceHistory: jest.Mock;
    createAttendanceCheckIn: jest.Mock;
    checkoutAttendance: jest.Mock;
    fetchTodayAttendance: jest.Mock;
    findOpenAttendance: jest.Mock;
    findEmployeeIdByUserUidOrEmployeeId: jest.Mock;
  };
  let rewardsService: {
    awardAttendanceEvent: jest.Mock;
  };

  const payrollConfig = {
    id: 1,
    user_id: 'user-1',
    standard_hours_per_day: 8,
    work_start_time: '08:00',
  } as PayrollConfig;

  const user = {
    id: 'user-1',
    odoo_uid: 100,
    odoo_employee_id: 200,
  } as User;

  beforeEach(async () => {
    configRepo = {
      findOne: jest.fn().mockResolvedValue(payrollConfig),
      create: jest.fn(
        (payload: Partial<PayrollConfig>) => payload as PayrollConfig,
      ),
      save: jest.fn((payload) => Promise.resolve(payload)),
    };
    leaveRepo = {
      find: jest.fn().mockResolvedValue([]),
    };
    leaveDayRepo = {
      find: jest.fn().mockResolvedValue([]),
    };
    userRepo = {
      findOne: jest.fn().mockResolvedValue(user),
      save: jest.fn((payload) => Promise.resolve(payload)),
    };
    odooService = {
      getHoChiMinhDayRange: jest.fn((reference: Date) => {
        const start = new Date(reference);
        start.setUTCHours(0, 0, 0, 0);
        const end = new Date(start);
        end.setUTCDate(end.getUTCDate() + 1);
        return { start, end };
      }),
      fetchAttendanceHistory: jest.fn().mockResolvedValue([]),
      createAttendanceCheckIn: jest.fn().mockResolvedValue(555),
      checkoutAttendance: jest.fn().mockResolvedValue(true),
      fetchTodayAttendance: jest.fn().mockResolvedValue([]),
      findOpenAttendance: jest.fn().mockResolvedValue(null),
      findEmployeeIdByUserUidOrEmployeeId: jest.fn().mockResolvedValue(200),
    };
    rewardsService = {
      awardAttendanceEvent: jest.fn().mockResolvedValue({
        awarded: true,
        transaction: {
          points: 5,
        },
      }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AttendanceService,
        {
          provide: getRepositoryToken(PayrollConfig),
          useValue: configRepo,
        },
        {
          provide: getRepositoryToken(LeaveRequest),
          useValue: leaveRepo,
        },
        {
          provide: getRepositoryToken(LeaveRequestDay),
          useValue: leaveDayRepo,
        },
        {
          provide: getRepositoryToken(User),
          useValue: userRepo,
        },
        {
          provide: OdooService,
          useValue: odooService,
        },
        {
          provide: RewardsService,
          useValue: rewardsService,
        },
      ],
    }).compile();

    service = module.get<AttendanceService>(AttendanceService);
  });

  it('allows the first check-in of the day directly in Odoo', async () => {
    odooService.fetchAttendanceHistory
      .mockResolvedValueOnce([])
      .mockResolvedValueOnce([
        {
          id: 555,
          employee_id: [200, 'Employee'],
          check_in: new Date().toISOString(),
          check_out: false,
          worked_hours: 0,
        },
      ]);

    const result = await service.checkin('user-1', {
      timestamp: new Date().toISOString(),
    });

    expect(odooService.createAttendanceCheckIn).toHaveBeenCalledWith(
      200,
      expect.any(Date),
    );
    expect(rewardsService.awardAttendanceEvent).toHaveBeenCalledWith(
      'user-1',
      'attendance_checkin',
      '555',
      { attendance_id: 555 },
    );
    expect(result.user_id).toBe('user-1');
    expect(result.id).toBe('555');
  });

  it('allows check-in even when another Odoo session is still open', async () => {
    odooService.fetchAttendanceHistory.mockResolvedValue([
      {
        id: 555,
        employee_id: [200, 'Employee'],
        check_in: new Date().toISOString(),
        check_out: false,
        worked_hours: 0,
      },
    ]);

    await service.checkin('user-1', {
      timestamp: new Date().toISOString(),
    });

    expect(odooService.createAttendanceCheckIn).toHaveBeenCalledWith(
      200,
      expect.any(Date),
    );
  });

  it('does not award checkout points when worked time is under 8 hours', async () => {
    const openSession = {
      id: 777,
      employee_id: [200, 'Employee'],
      check_in: new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString(),
      check_out: false,
      worked_hours: false,
    };
    const closedSession = {
      ...openSession,
      check_out: new Date().toISOString(),
      worked_hours: 2,
    };
    odooService.findOpenAttendance.mockResolvedValue(openSession);
    odooService.fetchAttendanceHistory.mockResolvedValueOnce([closedSession]);

    const result = await service.checkout('user-1', {
      timestamp: new Date().toISOString(),
    });

    expect(odooService.checkoutAttendance).toHaveBeenCalledWith(
      777,
      expect.any(Date),
    );
    expect(rewardsService.awardAttendanceEvent).not.toHaveBeenCalled();
    expect(result.rewarded).toBe(false);
    expect(result.reward_points).toBe(0);
    expect(result.checkout_at).toBeInstanceOf(Date);
  });

  it('awards checkout points when worked time reaches 8 hours', async () => {
    const openSession = {
      id: 777,
      employee_id: [200, 'Employee'],
      check_in: new Date(Date.now() - 8 * 60 * 60 * 1000).toISOString(),
      check_out: false,
      worked_hours: false,
    };
    const closedSession = {
      ...openSession,
      check_out: new Date().toISOString(),
      worked_hours: 8,
    };
    odooService.findOpenAttendance.mockResolvedValue(openSession);
    odooService.fetchAttendanceHistory.mockResolvedValueOnce([closedSession]);

    const result = await service.checkout('user-1', {
      timestamp: new Date().toISOString(),
    });

    expect(rewardsService.awardAttendanceEvent).toHaveBeenCalledWith(
      'user-1',
      'attendance_checkout',
      '777',
      { attendance_id: 777 },
    );
    expect(result.rewarded).toBe(true);
    expect(result.reward_points).toBe(5);
    expect(result.checkout_at).toBeInstanceOf(Date);
  });

  it('rejects checkout when no open Odoo session exists', async () => {
    odooService.findOpenAttendance.mockResolvedValue(null);

    await expect(
      service.checkout('user-1', { timestamp: new Date().toISOString() }),
    ).rejects.toThrow(
      new BadRequestException('Không có phiên checkin đang mở'),
    );
  });

  it('today status stays consistent with Odoo completed session data', async () => {
    odooService.fetchTodayAttendance.mockResolvedValue([
      {
        id: 888,
        employee_id: [200, 'Employee'],
        check_in: new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString(),
        check_out: new Date(Date.now() - 60 * 60 * 1000).toISOString(),
        worked_hours: 1,
      },
    ]);

    const result = await service.getTodayStatus('user-1');

    expect(result.has_open_session).toBe(false);
    expect(result.session_count).toBe(1);
  });

  it('classifies approved leave separately from absence in summary', async () => {
    odooService.fetchAttendanceHistory.mockResolvedValue([]);
    leaveDayRepo.find.mockResolvedValue([
      {
        leave_date: '2026-04-20',
        duration_days: 0.5,
        is_paid: true,
        leave_request: {
          user_id: 'user-1',
          status: 'approved',
        },
      },
    ]);

    const result = await service.getSummary(
      'user-1',
      '2026-04-20',
      '2026-04-20',
    );

    expect(result.paid_leave_days).toBe(0.5);
    expect(result.unpaid_leave_days).toBe(0);
    expect(result.total_days).toBe(0);
    expect(result.total_ot).toBe(0);
    expect(result.absent_without_leave_days).toBe(0.5);
    expect(result.days_absent).toBe(0.5);
  });

  it('calculates total OT from approved OT leave requests overlapping the summary range', async () => {
    odooService.fetchAttendanceHistory.mockResolvedValue([]);
    leaveRepo.find.mockResolvedValue([
      {
        user_id: 'user-1',
        type: 'ot',
        status: 'approved',
        start_date: '2026-04-24',
        end_date: '2026-04-26',
        start_time: '18:00',
        end_time: '20:30',
      },
      {
        user_id: 'user-1',
        type: 'ot',
        status: 'approved',
        start_date: '2026-05-25',
        end_date: '2026-05-25',
        start_time: '19:00',
        end_time: '21:00',
      },
    ]);

    const result = await service.getSummary(
      'user-1',
      '2026-04-25',
      '2026-05-25',
    );

    expect(result.total_ot).toBe(5);
  });

  it('returns OT summary grouped by user for admins', async () => {
    leaveRepo.find.mockResolvedValue([
      {
        user_id: 'user-1',
        start_date: '2026-04-24',
        end_date: '2026-04-26',
        start_time: '18:00',
        end_time: '20:30',
        requester: { name: 'Alice' },
      },
      {
        user_id: 'user-2',
        start_date: '2026-04-25',
        end_date: '2026-04-25',
        start_time: '19:00',
        end_time: '22:00',
        requester: { name: 'Bob' },
      },
      {
        user_id: 'user-1',
        start_date: '2026-04-25',
        end_date: '2026-04-25',
        start_time: '21:00',
        end_time: '22:30',
        requester: { name: 'Alice' },
      },
    ]);

    const result = await service.getOtSummary(
      'user-1',
      ['admin'],
      '2026-04-25',
      '2026-04-27',
    );

    expect(result).toEqual([
      { user_id: 'user-1', name: 'Alice', total_ot: 6.5 },
      { user_id: 'user-2', name: 'Bob', total_ot: 3 },
    ]);
    expect(leaveRepo.find).toHaveBeenCalledWith({
      where: {
        type: 'ot',
        status: 'approved',
      },
      relations: ['requester'],
    });
  });

  it('forbids non-admin users from viewing OT summary', async () => {
    await expect(
      service.getOtSummary('user-1', ['employee'], '2026-04-25', '2026-04-27'),
    ).rejects.toThrow(new ForbiddenException('Không có quyền xem thống kê OT'));
  });

  it('resolves and persists missing employee mapping before attendance actions', async () => {
    userRepo.findOne.mockResolvedValue({
      ...user,
      odoo_employee_id: null,
    });
    odooService.fetchAttendanceHistory.mockResolvedValue([]);

    await expect(
      service.checkin('user-1', {
        timestamp: new Date().toISOString(),
      }),
    ).rejects.toThrow(
      new ServiceUnavailableException(
        'Không thể xác nhận phiên checkin trên Odoo',
      ),
    );

    expect(
      odooService.findEmployeeIdByUserUidOrEmployeeId,
    ).toHaveBeenCalledWith(100);
    expect(userRepo.save).toHaveBeenCalledWith(
      expect.objectContaining({ odoo_employee_id: 200 }),
    );
  });

  it('fails clearly when employee mapping cannot be resolved', async () => {
    userRepo.findOne.mockResolvedValue({
      ...user,
      odoo_employee_id: null,
    });
    odooService.findEmployeeIdByUserUidOrEmployeeId.mockResolvedValue(null);

    await expect(
      service.checkin('user-1', {
        timestamp: new Date().toISOString(),
      }),
    ).rejects.toThrow(
      new ServiceUnavailableException(
        'Không tìm thấy employee Odoo cho người dùng',
      ),
    );
  });

  it('propagates Odoo availability errors during direct check-in', async () => {
    odooService.createAttendanceCheckIn.mockRejectedValue(
      new ServiceUnavailableException('Odoo unreachable'),
    );

    await expect(
      service.checkin('user-1', {
        timestamp: new Date().toISOString(),
      }),
    ).rejects.toThrow(new ServiceUnavailableException('Odoo unreachable'));
  });
});
