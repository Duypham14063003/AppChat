import { Test, TestingModule } from '@nestjs/testing';
import { ForbiddenException } from '@nestjs/common';
import { getRepositoryToken } from '@nestjs/typeorm';
import ExcelJS from 'exceljs';
import { PayrollExportService } from './payroll-export.service.js';
import { User } from '../../auth/entities/user.entity.js';
import { LeaveRequest } from '../entities/leave-request.entity.js';
import { LeaveRequestDay } from '../entities/leave-request-day.entity.js';
import { PayrollConfig } from '../entities/payroll-config.entity.js';
import { OdooService } from '../../auth/services/odoo.service.js';

describe('PayrollExportService', () => {
  let service: PayrollExportService;
  let userRepo: {
    find: jest.Mock;
    save: jest.Mock;
  };
  let leaveRepo: {
    find: jest.Mock;
  };
  let leaveDayRepo: {
    createQueryBuilder: jest.Mock;
  };
  let configRepo: {
    findOne: jest.Mock;
  };
  let odooService: {
    fetchAttendanceHistory: jest.Mock;
    findEmployeeIdByUserUidOrEmployeeId: jest.Mock;
  };
  let leaveDayQueryBuilder: {
    leftJoinAndSelect: jest.Mock;
    where: jest.Mock;
    andWhere: jest.Mock;
    getMany: jest.Mock;
  };
  let leaveDayQueryState: {
    userId?: string;
  };

  beforeEach(async () => {
    leaveDayQueryState = {};
    leaveDayQueryBuilder = {
      leftJoinAndSelect: jest.fn().mockReturnThis(),
      where: jest.fn((query: string, params?: { userId?: string }) => {
        if (query.includes('leave.user_id') && params?.userId != null) {
          leaveDayQueryState.userId = params.userId;
        }
        return leaveDayQueryBuilder;
      }),
      andWhere: jest.fn().mockReturnThis(),
      getMany: jest.fn(),
    };

    userRepo = {
      find: jest.fn(),
      save: jest.fn(async (payload) => payload),
    };
    leaveRepo = {
      find: jest.fn(),
    };
    leaveDayRepo = {
      createQueryBuilder: jest.fn(() => leaveDayQueryBuilder),
    };
    configRepo = {
      findOne: jest.fn(),
    };
    odooService = {
      fetchAttendanceHistory: jest.fn(),
      findEmployeeIdByUserUidOrEmployeeId: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PayrollExportService,
        {
          provide: getRepositoryToken(User),
          useValue: userRepo,
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
          provide: getRepositoryToken(PayrollConfig),
          useValue: configRepo,
        },
        {
          provide: OdooService,
          useValue: odooService,
        },
      ],
    }).compile();

    service = module.get(PayrollExportService);
  });

  it('rejects export for non-approver roles', async () => {
    await expect(
      service.exportPayrollWorkbook('requester-1', ['employee'], '2026-07'),
    ).rejects.toThrow(ForbiddenException);
  });

  it('builds an xlsx workbook for active employees and payroll cycle boundaries', async () => {
    configRepo.findOne.mockResolvedValue({
      user_id: 'requester-1',
      payroll_start_day: 25,
    } as PayrollConfig);

    userRepo.find.mockResolvedValue([
      {
        id: 'u-official',
        name: 'Alice Nguyen',
        employment_status: 'official',
        is_active: true,
        is_bot: false,
        odoo_uid: 100,
        odoo_employee_id: 200,
      },
      {
        id: 'u-probation',
        name: 'Bao Tran',
        employment_status: 'probation',
        is_active: true,
        is_bot: false,
        odoo_uid: 101,
        odoo_employee_id: 201,
      },
      {
        id: 'u-inactive',
        name: 'Inactive User',
        employment_status: 'official',
        is_active: false,
        is_bot: false,
        odoo_uid: 102,
        odoo_employee_id: 202,
      },
    ] as User[]);

    odooService.fetchAttendanceHistory.mockImplementation(
      async (employeeId: number) => {
        if (employeeId === 200) {
          return [
            {
              id: 1,
              employee_id: [200, 'Alice Nguyen'],
              check_in: '2026-06-25T01:00:00.000Z',
              check_out: '2026-06-25T10:00:00.000Z',
              worked_hours: 9,
            },
            {
              id: 2,
              employee_id: [200, 'Alice Nguyen'],
              check_in: '2026-06-26T01:00:00.000Z',
              check_out: '2026-06-26T10:00:00.000Z',
              worked_hours: 9,
            },
          ];
        }
        return [];
      },
    );

    leaveDayQueryBuilder.getMany.mockImplementation(async () => {
      if (leaveDayQueryState.userId === 'u-official') {
        return [
          {
            leave_date: '2026-06-29',
            duration_days: 1,
            is_paid: true,
            leave_request: {
              type: 'annual',
            },
          },
          {
            leave_date: '2026-06-30',
            duration_days: 0.5,
            is_paid: false,
            leave_request: {
              type: 'annual',
            },
          },
          {
            leave_date: '2026-07-01',
            duration_days: 1,
            is_paid: false,
            leave_request: {
              type: 'wfh',
            },
          },
        ] as LeaveRequestDay[];
      }

      return [
        {
          leave_date: '2026-07-03',
          duration_days: 1,
          is_paid: true,
          leave_request: {
            type: 'annual',
          },
        },
        {
          leave_date: '2026-07-06',
          duration_days: 0.5,
          is_paid: false,
          leave_request: {
            type: 'annual',
          },
        },
      ] as LeaveRequestDay[];
    });

    leaveRepo.find.mockImplementation(async ({ where }) => {
      if (where.user_id === 'u-official') {
        return [
          {
            user_id: 'u-official',
            start_date: '2026-07-02',
            end_date: '2026-07-02',
            start_time: '18:00',
            end_time: '20:00',
          },
        ];
      }
      return [];
    });

    const result = await service.exportPayrollWorkbook(
      'requester-1',
      ['manager'],
      '2026-07',
    );

    expect(result.filename).toBe('bang-cong-luong-2026-07.xlsx');
    expect(result.contentType).toBe(
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    expect(userRepo.find).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { is_active: true, is_bot: false },
      }),
    );
    expect(odooService.fetchAttendanceHistory).toHaveBeenCalledWith(
      200,
      new Date('2026-06-25T00:00:00.000Z'),
      new Date('2026-07-25T00:00:00.000Z'),
    );

    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.load(result.buffer);
    const worksheet = workbook.getWorksheet('Bang cong');

    expect(worksheet).toBeDefined();
    expect(worksheet?.getRow(1).values?.slice(1)).toEqual([
      'STT',
      'HỌ VÀ TÊN',
      'NGHỈ PHÉP CÓ LƯƠNG',
      'NGHỈ PHÉP KHÔNG LƯƠNG',
      'NGHỈ KHÔNG PHÉP',
      'CÔNG THỰC TẾ',
      'TỔNG NGÀY CÔNG TÍNH LƯƠNG',
      'SỐ NGÀY LÀM TẠI NHÀ',
      'GIỜ OT (GIỜ)',
      'NHẬN VIỆC/NGHỈ VIỆC',
      'XÁC NHẬN (Đ/S)',
      'NHẬP SIA/LỆCH (nếu có)',
    ]);

    expect(worksheet?.actualRowCount).toBe(3);
    expect(worksheet?.getCell('B2').value).toBe('Alice Nguyen');
    expect(worksheet?.getCell('C2').value).toBe(1);
    expect(worksheet?.getCell('D2').value).toBe(0.5);
    expect(worksheet?.getCell('E2').value).toBe(17.5);
    expect(worksheet?.getCell('F2').value).toBe(3);
    expect(worksheet?.getCell('G2').value).toBe(4);
    expect(worksheet?.getCell('H2').value).toBe(1);
    expect(worksheet?.getCell('I2').value).toBe(2);
    expect(worksheet?.getCell('B3').value).toBe('Bao Tran (thử việc)');
    expect(worksheet?.getCell('C3').value).toBe(1);
    expect(worksheet?.getCell('D3').value).toBe(0.5);
    expect(worksheet?.getCell('E3').value).toBe(20.5);
    expect(worksheet?.getCell('F3').value).toBe(0);
    expect(worksheet?.getCell('G3').value).toBe(1);
  });
});
