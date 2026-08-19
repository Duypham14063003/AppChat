import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { getRepositoryToken } from '@nestjs/typeorm';
import { LeaveService } from './leave.service';
import { LeaveRequest } from '../entities/leave-request.entity';
import { LeaveRequestDay } from '../entities/leave-request-day.entity';
import { YearlyLeaveBalance } from '../entities/yearly-leave-balance.entity';
import { CompanyWfhYearlyConfig } from '../entities/company-wfh-yearly-config.entity';
import { YearlyWfhBalance } from '../entities/yearly-wfh-balance.entity';
import { User } from '../../auth/entities/user.entity';
import { UserRole } from '../../auth/entities/user-role.entity';
import { Role } from '../../auth/entities/role.entity';
import { UserSession } from '../../auth/entities/user-session.entity';
import { FirebaseService } from '../../notification/services/firebase.service';
import { PayrollConfigService } from './payroll-config.service';
import { AuditLogService } from '../../auth/services/audit-log.service';

describe('LeaveService', () => {
  let service: LeaveService;
  let leaveRepo: {
    create: jest.Mock;
    save: jest.Mock;
    findOne: jest.Mock;
    createQueryBuilder: jest.Mock;
  };
  let leaveDayRepo: {
    delete: jest.Mock;
    find: jest.Mock;
    create: jest.Mock;
    save: jest.Mock;
  };
  let yearlyBalanceRepo: {
    findOne: jest.Mock;
    create: jest.Mock;
    save: jest.Mock;
  };
  let companyWfhConfigRepo: {
    findOne: jest.Mock;
    create: jest.Mock;
    save: jest.Mock;
  };
  let yearlyWfhBalanceRepo: {
    findOne: jest.Mock;
    create: jest.Mock;
    save: jest.Mock;
    update: jest.Mock;
  };
  let userRepo: {
    findOne: jest.Mock;
  };
  let userRoleRepo: {
    find: jest.Mock;
  };
  let roleRepo: {
    findOne: jest.Mock;
  };
  let sessionRepo: {
    find: jest.Mock;
  };
  let dataSource: {
    transaction: jest.Mock;
  };
  let leaveQueryBuilder: {
    leftJoin: jest.Mock;
    addSelect: jest.Mock;
    orderBy: jest.Mock;
    where: jest.Mock;
    andWhere: jest.Mock;
    getRawAndEntities: jest.Mock;
  };
  let payrollConfigService: {
    getPayrollConfigStartDay: jest.Mock;
  };
  let auditLogService: {
    logEvent: jest.Mock;
  };

  beforeEach(async () => {
    leaveQueryBuilder = {
      leftJoin: jest.fn().mockReturnThis(),
      addSelect: jest.fn().mockReturnThis(),
      orderBy: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      getRawAndEntities: jest.fn().mockResolvedValue({
        entities: [],
        raw: [],
      }),
    };
    leaveRepo = {
      create: jest.fn((payload) => payload),
      save: jest.fn(async (payload) => payload),
      findOne: jest.fn(),
      createQueryBuilder: jest.fn(() => leaveQueryBuilder),
    };
    leaveDayRepo = {
      delete: jest.fn(),
      find: jest.fn().mockResolvedValue([]),
      create: jest.fn((payload) => payload),
      save: jest.fn(async (payload) => payload),
    };
    yearlyBalanceRepo = {
      findOne: jest.fn(),
      create: jest.fn((payload) => payload),
      save: jest.fn(async (payload) => payload),
    };
    companyWfhConfigRepo = {
      findOne: jest.fn(),
      create: jest.fn((payload) => payload),
      save: jest.fn(async (payload) => payload),
    };
    yearlyWfhBalanceRepo = {
      findOne: jest.fn(),
      create: jest.fn((payload) => payload),
      save: jest.fn(async (payload) => payload),
      update: jest.fn(),
    };
    userRepo = {
      findOne: jest.fn(),
    };
    userRoleRepo = {
      find: jest.fn().mockResolvedValue([]),
    };
    roleRepo = {
      findOne: jest.fn().mockResolvedValue(null),
    };
    sessionRepo = {
      find: jest.fn().mockResolvedValue([]),
    };
    dataSource = {
      transaction: jest.fn(),
    };
    payrollConfigService = {
      getPayrollConfigStartDay: jest.fn().mockResolvedValue(1),
    };
    auditLogService = {
      logEvent: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        LeaveService,
        {
          provide: getRepositoryToken(LeaveRequest),
          useValue: leaveRepo,
        },
        {
          provide: getRepositoryToken(LeaveRequestDay),
          useValue: leaveDayRepo,
        },
        {
          provide: getRepositoryToken(YearlyLeaveBalance),
          useValue: yearlyBalanceRepo,
        },
        {
          provide: getRepositoryToken(CompanyWfhYearlyConfig),
          useValue: companyWfhConfigRepo,
        },
        {
          provide: getRepositoryToken(YearlyWfhBalance),
          useValue: yearlyWfhBalanceRepo,
        },
        {
          provide: getRepositoryToken(User),
          useValue: userRepo,
        },
        {
          provide: getRepositoryToken(UserRole),
          useValue: userRoleRepo,
        },
        {
          provide: getRepositoryToken(Role),
          useValue: roleRepo,
        },
        {
          provide: getRepositoryToken(UserSession),
          useValue: sessionRepo,
        },
        {
          provide: DataSource,
          useValue: dataSource,
        },
        {
          provide: FirebaseService,
          useValue: {
            isEnabled: jest.fn().mockReturnValue(false),
            sendPush: jest.fn(),
          },
        },
        {
          provide: PayrollConfigService,
          useValue: payrollConfigService,
        },
        {
          provide: AuditLogService,
          useValue: auditLogService,
        },
      ],
    }).compile();

    service = module.get(LeaveService);
  });

  it('rejects hourly duration for non-OT leave', async () => {
    await expect(
      service.create('user-1', {
        type: 'annual',
        start_date: '2026-04-20',
        end_date: '2026-04-20',
        start_time: '08:00',
        end_time: '12:00',
      }),
    ).rejects.toThrow(
      new BadRequestException('Đơn nghỉ phép không hỗ trợ theo giờ'),
    );
  });

  it('stores half-day annual leave with requested days', async () => {
    await service.create('user-1', {
      type: 'annual',
      start_date: '2026-04-20',
      end_date: '2026-04-20',
      is_half_day: true,
      half_day_part: 'morning',
    });

    expect(leaveRepo.create).toHaveBeenCalledWith(
      expect.objectContaining({
        is_half_day: true,
        half_day_part: 'morning',
        requested_days: 0.5,
      }),
    );
  });

  it('stores half-day wfh leave with requested days', async () => {
    await service.create('user-1', {
      type: 'wfh',
      start_date: '2026-04-20',
      end_date: '2026-04-20',
      is_half_day: true,
      half_day_part: 'afternoon',
    });

    expect(leaveRepo.create).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'wfh',
        is_half_day: true,
        half_day_part: 'afternoon',
        requested_days: 0.5,
      }),
    );
  });

  it('rejects cross-year wfh leave requests', async () => {
    await expect(
      service.create('user-1', {
        type: 'wfh',
        start_date: '2026-12-31',
        end_date: '2027-01-02',
      }),
    ).rejects.toThrow(
      new BadRequestException('Đơn WFH phải nằm trong cùng một năm'),
    );
  });

  it('returns leave list with requester and approver names', async () => {
    leaveQueryBuilder.getRawAndEntities.mockResolvedValue({
      entities: [
        {
          id: 'leave-1',
          user_id: 'user-1',
          approved_by: 'admin-1',
          status: 'approved',
          created_at: new Date('2026-04-22T16:17:33.730Z'),
          type: 'annual',
          start_date: '2026-04-21',
          end_date: '2026-04-21',
        },
      ],
      raw: [
        {
          user_name: 'Nguyen Van A',
          approved_by_name: 'Admin User',
        },
      ],
    });

    const result = await service.getLeaves('admin-1', undefined, undefined, [
      'admin',
    ]);

    expect(leaveRepo.createQueryBuilder).toHaveBeenCalledWith('l');
    expect(leaveQueryBuilder.leftJoin).toHaveBeenCalledWith(
      'l.requester',
      'requester',
    );
    expect(leaveQueryBuilder.addSelect).toHaveBeenCalledWith(
      'requester.name',
      'user_name',
    );
    expect(result.leaves).toEqual([
      expect.objectContaining({
        id: 'leave-1',
        user_id: 'user-1',
        user_name: 'Nguyen Van A',
        approved_by_name: 'Admin User',
      }),
    ]);
  });

  it('filters leave orders by target user for approvers', async () => {
    await service.getLeaves(
      'manager-1',
      undefined,
      'employee-2',
      ['manager'],
      2026,
      8,
    );

    expect(leaveQueryBuilder.where).toHaveBeenCalledWith('l.user_id = :uid', {
      uid: 'employee-2',
    });
  });

  it('ignores another-user filters from regular employees', async () => {
    await service.getLeaves(
      'employee-1',
      undefined,
      'employee-2',
      ['employee'],
      2026,
      8,
    );

    expect(leaveQueryBuilder.where).toHaveBeenCalledWith('l.user_id = :uid', {
      uid: 'employee-1',
    });
    expect(leaveQueryBuilder.where).not.toHaveBeenCalledWith(
      'l.user_id = :uid',
      { uid: 'employee-2' },
    );
  });

  it('filters a selected payroll month from the 25th to the next 25th', async () => {
    payrollConfigService.getPayrollConfigStartDay.mockResolvedValue(25);

    await service.getLeaves(
      'admin-1',
      undefined,
      undefined,
      ['admin'],
      2026,
      8,
    );

    expect(leaveQueryBuilder.andWhere).toHaveBeenCalledWith(
      'l.start_date < :cycleEnd AND l.end_date >= :cycleStart',
      {
        cycleStart: '2026-07-25',
        cycleEnd: '2026-08-25',
      },
    );
  });

  it('handles the January payroll month across years', async () => {
    payrollConfigService.getPayrollConfigStartDay.mockResolvedValue(25);

    await service.getLeaves(
      'admin-1',
      undefined,
      undefined,
      ['admin'],
      2027,
      1,
    );

    expect(leaveQueryBuilder.andWhere).toHaveBeenCalledWith(
      'l.start_date < :cycleEnd AND l.end_date >= :cycleStart',
      {
        cycleStart: '2026-12-25',
        cycleEnd: '2027-01-25',
      },
    );
  });

  it('approves official annual leave as paid within yearly balance', async () => {
    const leave = {
      id: 'leave-1',
      user_id: 'user-1',
      type: 'annual',
      start_date: '2026-04-21',
      end_date: '2026-04-21',
      is_half_day: false,
      half_day_part: null,
      status: 'submitted',
    };
    leaveRepo.findOne.mockResolvedValue(leave);
    userRepo.findOne.mockImplementation(({ where: { id } }) =>
      Promise.resolve(
        id === 'admin-1'
          ? { id, name: 'Admin' }
          : { id, employment_status: 'official' },
      ),
    );
    yearlyBalanceRepo.findOne.mockResolvedValue(null);
    dataSource.transaction.mockImplementation(async (callback) =>
      callback({
        getRepository: (entity: unknown) => {
          if (entity === LeaveRequest) return leaveRepo;
          if (entity === LeaveRequestDay) return leaveDayRepo;
          if (entity === YearlyLeaveBalance) return yearlyBalanceRepo;
          if (entity === CompanyWfhYearlyConfig) return companyWfhConfigRepo;
          if (entity === YearlyWfhBalance) return yearlyWfhBalanceRepo;
          if (entity === User) return userRepo;
          throw new Error('Unexpected repository');
        },
      }),
    );

    const result = await service.approve('admin-1', 'leave-1');

    expect(result.paid_days).toBe(1);
    expect(result.unpaid_days).toBe(0);
    expect(yearlyBalanceRepo.save).toHaveBeenCalledWith(
      expect.objectContaining({
        user_id: 'user-1',
        year: 2026,
        used_paid_days: 1,
      }),
    );
    expect(leaveDayRepo.save).toHaveBeenCalledWith(
      expect.arrayContaining([
        expect.objectContaining({
          leave_date: '2026-04-21',
          duration_days: 1,
          is_paid: true,
        }),
      ]),
    );
  });

  it('approves probation annual leave as unpaid', async () => {
    const leave = {
      id: 'leave-2',
      user_id: 'user-2',
      type: 'annual',
      start_date: '2026-04-21',
      end_date: '2026-04-21',
      is_half_day: false,
      half_day_part: null,
      status: 'submitted',
    };
    leaveRepo.findOne.mockResolvedValue(leave);
    userRepo.findOne.mockImplementation(({ where: { id } }) =>
      Promise.resolve(
        id === 'admin-1'
          ? { id, name: 'Admin' }
          : { id, employment_status: 'probation' },
      ),
    );
    dataSource.transaction.mockImplementation(async (callback) =>
      callback({
        getRepository: (entity: unknown) => {
          if (entity === LeaveRequest) return leaveRepo;
          if (entity === LeaveRequestDay) return leaveDayRepo;
          if (entity === YearlyLeaveBalance) return yearlyBalanceRepo;
          if (entity === CompanyWfhYearlyConfig) return companyWfhConfigRepo;
          if (entity === YearlyWfhBalance) return yearlyWfhBalanceRepo;
          if (entity === User) return userRepo;
          throw new Error('Unexpected repository');
        },
      }),
    );

    const result = await service.approve('admin-1', 'leave-2');

    expect(result.paid_days).toBe(0);
    expect(result.unpaid_days).toBe(1);
    expect(yearlyBalanceRepo.save).not.toHaveBeenCalled();
  });

  it('cancels an approved annual leave and restores paid quota', async () => {
    const leave = {
      id: 'leave-cancel-1',
      user_id: 'user-1',
      type: 'annual',
      start_date: '2026-04-21',
      end_date: '2026-04-22',
      requested_days: 2,
      paid_days: 1.5,
      status: 'approved',
      odoo_synced: true,
    };
    const balance = {
      user_id: 'user-1',
      year: 2026,
      allocated_days: 12,
      used_paid_days: 5,
    };
    leaveRepo.findOne.mockResolvedValue(leave);
    leaveDayRepo.find.mockResolvedValue([
      { leave_date: '2026-04-21', duration_days: 1, is_paid: true },
      { leave_date: '2026-04-22', duration_days: 0.5, is_paid: true },
      { leave_date: '2026-04-22', duration_days: 0.5, is_paid: false },
    ]);
    yearlyBalanceRepo.findOne.mockResolvedValue(balance);
    userRepo.findOne.mockResolvedValue({ id: 'admin-1', name: 'Admin' });
    dataSource.transaction.mockImplementation(async (callback) =>
      callback({
        getRepository: (entity: unknown) => {
          if (entity === LeaveRequest) return leaveRepo;
          if (entity === LeaveRequestDay) return leaveDayRepo;
          if (entity === YearlyLeaveBalance) return yearlyBalanceRepo;
          if (entity === YearlyWfhBalance) return yearlyWfhBalanceRepo;
          throw new Error('Unexpected repository');
        },
      }),
    );

    const result = await service.cancelApprovedLeave(
      'admin-1',
      leave.id,
      'Nhân viên đổi lịch',
    );

    expect(balance.used_paid_days).toBe(3.5);
    expect(yearlyBalanceRepo.save).toHaveBeenCalledWith(balance);
    expect(result).toEqual(
      expect.objectContaining({
        status: 'cancelled',
        cancelled_by: 'admin-1',
        cancel_reason: 'Nhân viên đổi lịch',
        odoo_synced: false,
      }),
    );
    expect(result.cancelled_at).toBeInstanceOf(Date);
    expect(auditLogService.logEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'hr_leave.cancelled',
        userId: 'admin-1',
        entityId: leave.id,
        reason: 'Nhân viên đổi lịch',
      }),
    );
  });

  it('cancels an approved WFH leave and restores WFH quota', async () => {
    const leave = {
      id: 'leave-cancel-wfh',
      user_id: 'user-1',
      type: 'wfh',
      start_date: '2026-04-21',
      end_date: '2026-04-21',
      requested_days: 0.5,
      status: 'approved',
    };
    const balance = {
      user_id: 'user-1',
      year: 2026,
      allocated_days: 12,
      used_days: 2,
    };
    leaveRepo.findOne.mockResolvedValue(leave);
    yearlyWfhBalanceRepo.findOne.mockResolvedValue(balance);
    userRepo.findOne.mockResolvedValue({ id: 'manager-1', name: 'Manager' });
    dataSource.transaction.mockImplementation(async (callback) =>
      callback({
        getRepository: (entity: unknown) => {
          if (entity === LeaveRequest) return leaveRepo;
          if (entity === LeaveRequestDay) return leaveDayRepo;
          if (entity === YearlyLeaveBalance) return yearlyBalanceRepo;
          if (entity === YearlyWfhBalance) return yearlyWfhBalanceRepo;
          throw new Error('Unexpected repository');
        },
      }),
    );

    await service.cancelApprovedLeave('manager-1', leave.id, 'Không còn WFH');

    expect(balance.used_days).toBe(1.5);
    expect(yearlyWfhBalanceRepo.save).toHaveBeenCalledWith(balance);
  });

  it('does not cancel a leave that is not approved', async () => {
    leaveRepo.findOne.mockResolvedValue({
      id: 'leave-submitted',
      status: 'submitted',
    });

    await expect(
      service.cancelApprovedLeave('admin-1', 'leave-submitted', 'Không hợp lệ'),
    ).rejects.toThrow(new BadRequestException('Chỉ có thể hủy đơn đã duyệt'));
    expect(dataSource.transaction).not.toHaveBeenCalled();
  });

  it('evaluates annual leave across months against the same yearly balance', async () => {
    const leave = {
      id: 'leave-3',
      user_id: 'user-3',
      type: 'annual',
      start_date: '2026-04-30',
      end_date: '2026-05-01',
      is_half_day: false,
      half_day_part: null,
      status: 'submitted',
    };
    leaveRepo.findOne.mockResolvedValue(leave);
    userRepo.findOne.mockImplementation(({ where: { id } }) =>
      Promise.resolve(
        id === 'admin-1'
          ? { id, name: 'Admin' }
          : { id, employment_status: 'official' },
      ),
    );
    yearlyBalanceRepo.findOne.mockResolvedValue(null);
    dataSource.transaction.mockImplementation(async (callback) =>
      callback({
        getRepository: (entity: unknown) => {
          if (entity === LeaveRequest) return leaveRepo;
          if (entity === LeaveRequestDay) return leaveDayRepo;
          if (entity === YearlyLeaveBalance) return yearlyBalanceRepo;
          if (entity === CompanyWfhYearlyConfig) return companyWfhConfigRepo;
          if (entity === YearlyWfhBalance) return yearlyWfhBalanceRepo;
          if (entity === User) return userRepo;
          throw new Error('Unexpected repository');
        },
      }),
    );

    const result = await service.approve('admin-1', 'leave-3');

    expect(result.paid_days).toBe(2);
    expect(result.unpaid_days).toBe(0);
    expect(leaveDayRepo.save).toHaveBeenCalledWith(
      expect.arrayContaining([
        expect.objectContaining({ leave_date: '2026-04-30', is_paid: true }),
        expect.objectContaining({ leave_date: '2026-05-01', is_paid: true }),
      ]),
    );
    // Both days are evaluated against the same yearly balance
    expect(yearlyBalanceRepo.save).toHaveBeenCalledTimes(2);
  });

  it('returns remaining paid leave for an official employee with an existing yearly balance', async () => {
    userRepo.findOne.mockResolvedValue({
      id: 'user-1',
      employment_status: 'official',
    });
    yearlyBalanceRepo.findOne.mockResolvedValue({
      user_id: 'user-1',
      year: 2026,
      allocated_days: 12,
      used_paid_days: 0.5,
    });

    const result = await service.getLeaveBalance('user-1', 2026);

    expect(result).toEqual({
      year: 2026,
      employment_status: 'official',
      is_paid_leave_eligible: true,
      allocated_days: 12,
      used_paid_days: 0.5,
      remaining_paid_days: 11.5,
      has_remaining_paid_leave: true,
    });
  });

  it('returns zero remaining paid leave for an official employee with no balance left', async () => {
    userRepo.findOne.mockResolvedValue({
      id: 'user-1',
      employment_status: 'official',
    });
    yearlyBalanceRepo.findOne.mockResolvedValue({
      user_id: 'user-1',
      year: 2026,
      allocated_days: 12,
      used_paid_days: 12,
    });

    const result = await service.getLeaveBalance('user-1', 2026);

    expect(result.remaining_paid_days).toBe(0);
    expect(result.has_remaining_paid_leave).toBe(false);
  });

  it('returns zero paid leave balance for a probation employee without a balance row', async () => {
    userRepo.findOne.mockResolvedValue({
      id: 'user-2',
      employment_status: 'probation',
    });
    yearlyBalanceRepo.findOne.mockResolvedValue(null);

    const result = await service.getLeaveBalance('user-2', 2026);

    expect(result).toEqual({
      year: 2026,
      employment_status: 'probation',
      is_paid_leave_eligible: false,
      allocated_days: 0,
      used_paid_days: 0,
      remaining_paid_days: 0,
      has_remaining_paid_leave: false,
    });
  });

  it('returns wfh balance from company default config when user has no override row', async () => {
    userRepo.findOne.mockResolvedValue({
      id: 'user-1',
      employment_status: 'official',
    });
    yearlyWfhBalanceRepo.findOne.mockResolvedValue(null);
    companyWfhConfigRepo.findOne.mockResolvedValue({
      year: 2026,
      allocated_days: 12,
    });

    const result = await service.getWfhBalance('user-1', 2026);

    expect(yearlyWfhBalanceRepo.save).toHaveBeenCalledWith(
      expect.objectContaining({
        user_id: 'user-1',
        year: 2026,
        allocated_days: 12,
        used_days: 0,
        is_override: false,
      }),
    );
    expect(result).toEqual({
      year: 2026,
      allocated_days: 12,
      used_days: 0,
      remaining_days: 12,
      has_remaining_days: true,
      is_override: false,
    });
  });

  it('updates company wfh config without overwriting user overrides', async () => {
    companyWfhConfigRepo.findOne.mockResolvedValue({
      id: 'cfg-1',
      year: 2026,
      allocated_days: 10,
    });
    companyWfhConfigRepo.save.mockImplementation(async (payload) => payload);

    const result = await service.updateCompanyWfhConfig(2026, 12);

    expect(result.allocated_days).toBe(12);
    expect(yearlyWfhBalanceRepo.update).toHaveBeenCalledWith(
      { year: 2026, is_override: false },
      { allocated_days: 12 },
    );
  });

  it('approves wfh leave and deducts the user yearly wfh balance', async () => {
    const leave = {
      id: 'leave-wfh-1',
      user_id: 'user-1',
      type: 'wfh',
      start_date: '2026-04-21',
      end_date: '2026-04-21',
      requested_days: 0.5,
      is_half_day: true,
      half_day_part: 'morning',
      status: 'submitted',
    };
    leaveRepo.findOne.mockResolvedValue(leave);
    userRepo.findOne.mockImplementation(({ where: { id } }) =>
      Promise.resolve(
        id === 'admin-1'
          ? { id, name: 'Admin' }
          : { id, employment_status: 'official' },
      ),
    );
    yearlyWfhBalanceRepo.findOne.mockResolvedValue({
      user_id: 'user-1',
      year: 2026,
      allocated_days: 1,
      used_days: 0,
      is_override: false,
    });
    dataSource.transaction.mockImplementation(async (callback) =>
      callback({
        getRepository: (entity: unknown) => {
          if (entity === LeaveRequest) return leaveRepo;
          if (entity === LeaveRequestDay) return leaveDayRepo;
          if (entity === YearlyLeaveBalance) return yearlyBalanceRepo;
          if (entity === CompanyWfhYearlyConfig) return companyWfhConfigRepo;
          if (entity === YearlyWfhBalance) return yearlyWfhBalanceRepo;
          if (entity === User) return userRepo;
          throw new Error('Unexpected repository');
        },
      }),
    );

    const result = await service.approve('admin-1', 'leave-wfh-1');

    expect(result.paid_days).toBe(0);
    expect(result.unpaid_days).toBe(0);
    expect(leaveDayRepo.save).toHaveBeenCalledWith(
      expect.arrayContaining([
        expect.objectContaining({
          leave_date: '2026-04-21',
          duration_days: 0.5,
          half_day_part: 'morning',
          is_paid: false,
        }),
      ]),
    );
    expect(yearlyWfhBalanceRepo.save).toHaveBeenCalledWith(
      expect.objectContaining({
        user_id: 'user-1',
        year: 2026,
        used_days: 0.5,
      }),
    );
  });

  it('rejects wfh approval when remaining quota is insufficient', async () => {
    const leave = {
      id: 'leave-wfh-2',
      user_id: 'user-1',
      type: 'wfh',
      start_date: '2026-04-21',
      end_date: '2026-04-21',
      requested_days: 1,
      is_half_day: false,
      half_day_part: null,
      status: 'submitted',
    };
    leaveRepo.findOne.mockResolvedValue(leave);
    userRepo.findOne.mockImplementation(({ where: { id } }) =>
      Promise.resolve(
        id === 'admin-1'
          ? { id, name: 'Admin' }
          : { id, employment_status: 'official' },
      ),
    );
    yearlyWfhBalanceRepo.findOne.mockResolvedValue({
      user_id: 'user-1',
      year: 2026,
      allocated_days: 1,
      used_days: 0.5,
      is_override: false,
    });
    dataSource.transaction.mockImplementation(async (callback) =>
      callback({
        getRepository: (entity: unknown) => {
          if (entity === LeaveRequest) return leaveRepo;
          if (entity === LeaveRequestDay) return leaveDayRepo;
          if (entity === YearlyLeaveBalance) return yearlyBalanceRepo;
          if (entity === CompanyWfhYearlyConfig) return companyWfhConfigRepo;
          if (entity === YearlyWfhBalance) return yearlyWfhBalanceRepo;
          if (entity === User) return userRepo;
          throw new Error('Unexpected repository');
        },
      }),
    );

    await expect(service.approve('admin-1', 'leave-wfh-2')).rejects.toThrow(
      new BadRequestException('Không đủ quota WFH còn lại để duyệt'),
    );
  });

  it('defaults to the current year when year is omitted', async () => {
    userRepo.findOne.mockResolvedValue({
      id: 'user-3',
      employment_status: 'official',
    });
    yearlyBalanceRepo.findOne.mockResolvedValue(null);

    const result = await service.getLeaveBalance('user-3');

    expect(yearlyBalanceRepo.findOne).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          user_id: 'user-3',
          year: result.year,
        }),
      }),
    );
    expect(result.allocated_days).toBe(12);
  });
});
