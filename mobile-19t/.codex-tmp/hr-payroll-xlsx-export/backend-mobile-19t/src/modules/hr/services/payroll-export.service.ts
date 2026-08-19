import { ForbiddenException, Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import ExcelJS from 'exceljs';
import { Repository } from 'typeorm';
import { OdooAttendanceRecord, OdooService } from '../../auth/services/odoo.service.js';
import { User } from '../../auth/entities/user.entity.js';
import { LeaveRequest } from '../entities/leave-request.entity.js';
import { LeaveRequestDay } from '../entities/leave-request-day.entity.js';
import { PayrollConfig } from '../entities/payroll-config.entity.js';
import { canApproveLeaveRoles } from '../hr-role.utils.js';

type PayrollCycleRange = {
  from: Date;
  to: Date;
};

type PayrollAggregates = {
  paidLeaveDays: number;
  unpaidLeaveDays: number;
  absentWithoutLeaveDays: number;
  actualWorkedDays: number;
  payrollWorkedDays: number;
  wfhDays: number;
  otHours: number;
};

type PayrollWorkbookRow = {
  displayName: string;
  employmentStatus: string | null;
  paidLeaveDays: number;
  unpaidLeaveDays: number;
  absentWithoutLeaveDays: number;
  actualWorkedDays: number;
  payrollWorkedDays: number;
  wfhDays: number;
  otHours: number;
};

export type PayrollExportResult = {
  buffer: Buffer;
  contentType: string;
  filename: string;
};

const WORKBOOK_CONTENT_TYPE =
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

const WORKBOOK_HEADERS = [
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
] as const;

@Injectable()
export class PayrollExportService {
  private readonly logger = new Logger(PayrollExportService.name);

  constructor(
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    @InjectRepository(LeaveRequest)
    private readonly leaveRepo: Repository<LeaveRequest>,
    @InjectRepository(LeaveRequestDay)
    private readonly leaveDayRepo: Repository<LeaveRequestDay>,
    @InjectRepository(PayrollConfig)
    private readonly configRepo: Repository<PayrollConfig>,
    private readonly odooService: OdooService,
  ) {}

  async exportPayrollWorkbook(
    requesterUserId: string,
    roles: string[] | undefined,
    month: string,
  ): Promise<PayrollExportResult> {
    if (!canApproveLeaveRoles(roles)) {
      throw new ForbiddenException('Không có quyền xuất bảng lương');
    }

    const payrollStartDay = await this.getPayrollStartDay(requesterUserId);
    const cycle = this.buildPayrollCycle(month, payrollStartDay);
    const users = await this.userRepo.find({
      where: {
        is_active: true,
        is_bot: false,
      },
      order: {
        name: 'ASC',
      },
    });

    const activeUsers = users.filter((user) => user.is_active && !user.is_bot);
    const rows: PayrollWorkbookRow[] = [];

    for (const user of activeUsers) {
      const aggregates = await this.computePayrollAggregates(user, cycle);
      rows.push({
        displayName: this.buildDisplayName(user),
        employmentStatus: user.employment_status ?? null,
        paidLeaveDays: aggregates.paidLeaveDays,
        unpaidLeaveDays: aggregates.unpaidLeaveDays,
        absentWithoutLeaveDays: aggregates.absentWithoutLeaveDays,
        actualWorkedDays: aggregates.actualWorkedDays,
        payrollWorkedDays: aggregates.payrollWorkedDays,
        wfhDays: aggregates.wfhDays,
        otHours: aggregates.otHours,
      });
    }

    rows.sort((left, right) => {
      const rankDiff =
        this.getEmploymentStatusRank(left.employmentStatus) -
        this.getEmploymentStatusRank(right.employmentStatus);
      if (rankDiff != 0) return rankDiff;
      return left.displayName.localeCompare(right.displayName, 'vi');
    });

    const workbook = new ExcelJS.Workbook();
    const worksheet = workbook.addWorksheet('Bang cong');
    worksheet.addRow([...WORKBOOK_HEADERS]);
    const headerRow = worksheet.getRow(1);
    headerRow.font = { bold: true };

    rows.forEach((row, index) => {
      worksheet.addRow([
        index + 1,
        row.displayName,
        row.paidLeaveDays,
        row.unpaidLeaveDays,
        row.absentWithoutLeaveDays,
        row.actualWorkedDays,
        row.payrollWorkedDays,
        row.wfhDays,
        row.otHours,
        '',
        '',
        '',
      ]);
    });

    worksheet.columns = [
      { width: 8 },
      { width: 32 },
      { width: 18 },
      { width: 20 },
      { width: 18 },
      { width: 16 },
      { width: 22 },
      { width: 18 },
      { width: 14 },
      { width: 20 },
      { width: 16 },
      { width: 22 },
    ];

    const rawBuffer = await workbook.xlsx.writeBuffer();
    const buffer = Buffer.from(rawBuffer);

    return {
      buffer,
      contentType: WORKBOOK_CONTENT_TYPE,
      filename: `bang-cong-luong-${month}.xlsx`,
    };
  }

  private async getPayrollStartDay(userId: string): Promise<number> {
    const config = await this.configRepo.findOne({
      where: { user_id: userId },
    });

    const startDay = Number(config?.payroll_start_day ?? 1);
    if (!Number.isInteger(startDay) || startDay < 1 || startDay > 28) {
      return 1;
    }

    return startDay;
  }

  private buildPayrollCycle(month: string, startDay: number): PayrollCycleRange {
    const selectedMonth = new Date(`${month}-01T00:00:00.000Z`);
    const year = selectedMonth.getUTCFullYear();
    const monthIndex = selectedMonth.getUTCMonth();

    if (startDay === 1) {
      return {
        from: new Date(Date.UTC(year, monthIndex, 1)),
        to: new Date(Date.UTC(year, monthIndex + 1, 0)),
      };
    }

    const from = new Date(Date.UTC(year, monthIndex - 1, startDay));
    const to = new Date(Date.UTC(year, monthIndex, startDay));
    to.setUTCDate(to.getUTCDate() - 1);

    return { from, to };
  }

  private async computePayrollAggregates(
    user: User,
    cycle: PayrollCycleRange,
  ): Promise<PayrollAggregates> {
    const attendanceRecords = await this.loadAttendanceRecords(user, cycle);
    const attendanceDays = new Set(
      attendanceRecords.map((record) => this.toDateKey(new Date(record.check_in))),
    );

    const leaveDays = await this.leaveDayRepo
      .createQueryBuilder('day')
      .leftJoinAndSelect('day.leave_request', 'leave')
      .where('leave.user_id = :userId', { userId: user.id })
      .andWhere('leave.status = :status', { status: 'approved' })
      .andWhere('day.leave_date BETWEEN :from AND :to', {
        from: this.toDateKey(cycle.from),
        to: this.toDateKey(cycle.to),
      })
      .getMany();

    const paidLeaveByDay = new Map<string, number>();
    const unpaidLeaveByDay = new Map<string, number>();
    const wfhByDay = new Map<string, number>();

    for (const leaveDay of leaveDays) {
      const leaveType = leaveDay.leave_request?.type;
      const currentDate = leaveDay.leave_date;
      const duration = Number(leaveDay.duration_days) || 0;

      if (leaveType === 'wfh') {
        wfhByDay.set(
          currentDate,
          this.roundDays((wfhByDay.get(currentDate) ?? 0) + duration),
        );
        continue;
      }

      if (leaveType === 'ot') {
        continue;
      }

      if (leaveDay.is_paid) {
        paidLeaveByDay.set(
          currentDate,
          this.roundDays((paidLeaveByDay.get(currentDate) ?? 0) + duration),
        );
      } else {
        unpaidLeaveByDay.set(
          currentDate,
          this.roundDays((unpaidLeaveByDay.get(currentDate) ?? 0) + duration),
        );
      }
    }

    let paidLeaveDays = 0;
    let unpaidLeaveDays = 0;
    let absentWithoutLeaveDays = 0;
    let actualWorkedDays = 0;
    let wfhDays = 0;

    for (const workday of this.getWorkdayDates(cycle.from, cycle.to)) {
      const paidLeave = paidLeaveByDay.get(workday) ?? 0;
      const unpaidLeave = unpaidLeaveByDay.get(workday) ?? 0;
      const wfh = Math.min(1, wfhByDay.get(workday) ?? 0);

      paidLeaveDays += paidLeave;
      unpaidLeaveDays += unpaidLeave;
      wfhDays += wfh;

      if (attendanceDays.has(workday)) {
        actualWorkedDays += 1;
        continue;
      }

      actualWorkedDays += wfh;
      absentWithoutLeaveDays += Math.max(0, 1 - wfh - paidLeave - unpaidLeave);
    }

    const otHours = await this.getApprovedOtHoursForRange(
      user.id,
      cycle.from,
      cycle.to,
    );

    paidLeaveDays = this.roundDays(paidLeaveDays);
    unpaidLeaveDays = this.roundDays(unpaidLeaveDays);
    actualWorkedDays = this.roundDays(actualWorkedDays);
    absentWithoutLeaveDays = this.roundDays(absentWithoutLeaveDays);
    wfhDays = this.roundDays(wfhDays);

    return {
      paidLeaveDays,
      unpaidLeaveDays,
      absentWithoutLeaveDays,
      actualWorkedDays,
      payrollWorkedDays: this.roundDays(actualWorkedDays + paidLeaveDays),
      wfhDays,
      otHours: this.roundHours(otHours),
    };
  }

  private async loadAttendanceRecords(
    user: User,
    cycle: PayrollCycleRange,
  ): Promise<OdooAttendanceRecord[]> {
    try {
      const employeeId = await this.resolveEmployeeId(user);
      if (employeeId == null) {
        return [];
      }

      return this.odooService.fetchAttendanceHistory(
        employeeId,
        cycle.from,
        this.makeExclusiveEnd(cycle.to),
      );
    } catch (error) {
      this.logger.warn(
        `Skipping attendance fetch for user=${user.id}: ${error instanceof Error ? error.message : String(error)}`,
      );
      return [];
    }
  }

  private async resolveEmployeeId(user: User): Promise<number | null> {
    if (user.odoo_employee_id) {
      return user.odoo_employee_id;
    }

    if (!user.odoo_uid) {
      return null;
    }

    const resolvedEmployeeId =
      await this.odooService.findEmployeeIdByUserUidOrEmployeeId(user.odoo_uid);

    if (!resolvedEmployeeId) {
      return null;
    }

    user.odoo_employee_id = resolvedEmployeeId;
    await this.userRepo.save(user);
    return resolvedEmployeeId;
  }

  private buildDisplayName(user: User): string {
    const baseName = user.name?.trim() || 'Nhân viên';
    const status = user.employment_status?.trim().toLowerCase();

    if (status === 'probation') {
      return `${baseName} (thử việc)`;
    }

    if (status === 'intern') {
      return `${baseName} (thực tập)`;
    }

    return baseName;
  }

  private getEmploymentStatusRank(status: string | null): number {
    switch ((status ?? '').trim().toLowerCase()) {
      case 'official':
        return 0;
      case 'probation':
        return 1;
      case 'intern':
        return 2;
      default:
        return 3;
    }
  }

  private getWorkdayDates(from: Date, to: Date): string[] {
    const dates: string[] = [];
    const current = this.toStartOfUtcDay(from);
    const end = this.toStartOfUtcDay(to);

    while (current <= end) {
      const day = current.getUTCDay();
      if (day !== 0 && day !== 6) {
        dates.push(current.toISOString().substring(0, 10));
      }
      current.setUTCDate(current.getUTCDate() + 1);
    }

    return dates;
  }

  private async getApprovedOtHoursForRange(
    userId: string,
    from: Date,
    to: Date,
  ): Promise<number> {
    const rangeStart = this.toStartOfUtcDay(from);
    const rangeEndExclusive = this.makeExclusiveEnd(to);

    const approvedOtLeaves = await this.leaveRepo.find({
      where: {
        user_id: userId,
        type: 'ot',
        status: 'approved',
      },
    });

    return approvedOtLeaves.reduce((sum, leave) => {
      return (
        sum +
        this.calculateApprovedOtHoursForLeave(
          leave,
          rangeStart,
          rangeEndExclusive,
        )
      );
    }, 0);
  }

  private calculateApprovedOtHoursForLeave(
    leave: Pick<
      LeaveRequest,
      'start_time' | 'end_time' | 'start_date' | 'end_date'
    >,
    rangeStart: Date,
    rangeEndExclusive: Date,
  ): number {
    const dailyHours = this.getOtHoursPerDay(leave.start_time, leave.end_time);
    if (dailyHours <= 0) return 0;

    const overlapDays = this.countOverlappingDays(
      rangeStart,
      rangeEndExclusive,
      leave.start_date,
      leave.end_date,
    );

    return overlapDays * dailyHours;
  }

  private getOtHoursPerDay(
    startTime: string | null,
    endTime: string | null,
  ): number {
    if (!startTime || !endTime) return 0;

    const startMinutes = this.parseTimeToMinutes(startTime);
    const endMinutes = this.parseTimeToMinutes(endTime);
    if (
      startMinutes == null ||
      endMinutes == null ||
      endMinutes <= startMinutes
    ) {
      return 0;
    }

    return Math.round(((endMinutes - startMinutes) / 60) * 100) / 100;
  }

  private countOverlappingDays(
    rangeStart: Date,
    rangeEndExclusive: Date,
    leaveStartDate: string,
    leaveEndDate: string,
  ): number {
    const leaveStart = this.toStartOfUtcDay(
      new Date(`${leaveStartDate}T00:00:00.000Z`),
    );
    const leaveEndExclusive = this.toExclusiveUtcEndOfDay(
      new Date(`${leaveEndDate}T00:00:00.000Z`),
    );

    const overlapStart = Math.max(rangeStart.getTime(), leaveStart.getTime());
    const overlapEnd = Math.min(
      rangeEndExclusive.getTime(),
      leaveEndExclusive.getTime(),
    );

    if (overlapEnd <= overlapStart) return 0;

    return Math.round((overlapEnd - overlapStart) / (1000 * 60 * 60 * 24));
  }

  private parseTimeToMinutes(value: string): number | null {
    const [hoursText, minutesText] = value.split(':');
    const hours = Number(hoursText);
    const minutes = Number(minutesText);
    if (
      !Number.isInteger(hours) ||
      !Number.isInteger(minutes) ||
      hours < 0 ||
      hours > 23 ||
      minutes < 0 ||
      minutes > 59
    ) {
      return null;
    }

    return hours * 60 + minutes;
  }

  private makeExclusiveEnd(date: Date) {
    const end = new Date(date);
    end.setUTCHours(0, 0, 0, 0);
    end.setUTCDate(end.getUTCDate() + 1);
    return end;
  }

  private toDateKey(date: Date) {
    return date.toISOString().substring(0, 10);
  }

  private toStartOfUtcDay(date: Date): Date {
    const normalized = new Date(date);
    normalized.setUTCHours(0, 0, 0, 0);
    return normalized;
  }

  private toExclusiveUtcEndOfDay(date: Date): Date {
    const normalized = this.toStartOfUtcDay(date);
    normalized.setUTCDate(normalized.getUTCDate() + 1);
    return normalized;
  }

  private roundDays(value: number): number {
    return Math.round(value * 10) / 10;
  }

  private roundHours(value: number): number {
    return Math.round(value * 100) / 100;
  }
}
