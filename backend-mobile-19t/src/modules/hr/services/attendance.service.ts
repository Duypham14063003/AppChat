import {
  Injectable,
  BadRequestException,
  ForbiddenException,
  ServiceUnavailableException,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Between, Repository } from 'typeorm';
import { PayrollConfig } from '../entities/payroll-config.entity.js';
import { LeaveRequest } from '../entities/leave-request.entity.js';
import { LeaveRequestDay } from '../entities/leave-request-day.entity.js';
import { CheckinDto, CheckoutDto } from '../dto/hr.dto.js';
import {
  OdooAttendanceRecord,
  OdooService,
} from '../../auth/services/odoo.service.js';
import { User } from '../../auth/entities/user.entity.js';
import { RewardsService } from '../../rewards/rewards.service.js';

type AttendanceView = {
  id: string;
  user_id: string;
  checkin_at: Date;
  checkout_at: Date | null;
  checkin_lat: number | null;
  checkin_lng: number | null;
  checkout_lat: number | null;
  checkout_lng: number | null;
  device_id: string | null;
  total_hours: number | null;
  ot_hours: number | null;
  odoo_synced: boolean;
  odoo_synced_at: Date | null;
  created_at: Date;
  rewarded: boolean;
  reward_points: number;
};

type AttendanceRewardResult = {
  awarded: boolean;
  points: number;
};

const CHECKOUT_REWARD_MIN_HOURS = 8;
const CHECKIN_CONFIRM_ATTEMPTS = 3;
const CHECKIN_CONFIRM_DELAY_MS = 150;

@Injectable()
export class AttendanceService {
  private readonly logger = new Logger(AttendanceService.name);

  constructor(
    @InjectRepository(PayrollConfig)
    private readonly configRepo: Repository<PayrollConfig>,
    @InjectRepository(LeaveRequest)
    private readonly leaveRepo: Repository<LeaveRequest>,
    @InjectRepository(LeaveRequestDay)
    private readonly leaveDayRepo: Repository<LeaveRequestDay>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    private readonly odooService: OdooService,
    private readonly rewardsService: RewardsService,
  ) {}

  async checkin(userId: string, dto: CheckinDto): Promise<AttendanceView> {
    const timestamp = new Date(dto.timestamp);

    this.validateTimestamp(timestamp);

    const user = await this.getUserOrThrow(userId);
    const employeeId = await this.resolveEmployeeId(user);
    const { start, end } = this.odooService.getHoChiMinhDayRange(timestamp);

    const attendanceId = await this.odooService.createAttendanceCheckIn(
      employeeId,
      timestamp,
    );
    const createdRecord = await this.fetchAttendanceById(
      employeeId,
      attendanceId,
      start,
      end,
    );

    await this.tryAwardAttendanceEvent(
      userId,
      'attendance_checkin',
      attendanceId,
    );

    return this.toAttendanceView(
      createdRecord ?? {
        id: attendanceId,
        employee_id: [employeeId, ''],
        check_in: timestamp.toISOString(),
        check_out: false,
        worked_hours: 0,
      },
      userId,
      0,
    );
  }

  async checkout(userId: string, dto: CheckoutDto): Promise<AttendanceView> {
    const timestamp = new Date(dto.timestamp);

    this.validateTimestamp(timestamp);

    const user = await this.getUserOrThrow(userId);
    const employeeId = await this.resolveEmployeeId(user);
    const { start, end } = this.odooService.getHoChiMinhDayRange(timestamp);
    const openSession = await this.odooService.findOpenAttendance(
      employeeId,
      timestamp,
    );

    if (!openSession) {
      throw new BadRequestException('Không có phiên checkin đang mở');
    }

    if (timestamp < new Date(openSession.check_in)) {
      throw new BadRequestException(
        'Thời gian checkout không thể sớm hơn checkin',
      );
    }

    const updated = await this.odooService.checkoutAttendance(
      openSession.id,
      timestamp,
    );
    if (!updated) {
      throw new ServiceUnavailableException('Không thể checkout trên Odoo');
    }

    const refreshed = await this.fetchAttendanceById(
      employeeId,
      openSession.id,
      start,
      end,
    );
    const config = await this.getConfig(userId);
    const sessionsToday = await this.odooService.fetchAttendanceHistory(
      employeeId,
      start,
      end,
    );
    const sessionsWithUpdated = this.sortSessionsAsc([
      ...sessionsToday.filter((session) => session.id !== openSession.id),
      {
        ...openSession,
        check_out: timestamp.toISOString(),
        worked_hours: this.getWorkedHours(openSession, timestamp),
      },
    ]);
    const { otById } = this.computeDailyStats(sessionsWithUpdated, config);
    const workedHours =
      this.getWorkedHours(refreshed ?? sessionsWithUpdated.at(-1) ?? openSession) ??
      0;
    const rewardResult =
      workedHours >= CHECKOUT_REWARD_MIN_HOURS
        ? await this.tryAwardAttendanceEvent(
            userId,
            'attendance_checkout',
            openSession.id,
          )
        : { awarded: false, points: 0 };

    return this.toAttendanceView(
      refreshed ?? {
        ...openSession,
        check_out: timestamp.toISOString(),
        worked_hours: this.getWorkedHours(openSession, timestamp),
      },
      userId,
      otById.get(openSession.id) ?? 0,
      rewardResult,
    );
  }

  async getHistory(
    userId: string,
    from?: string,
    to?: string,
    targetUserId?: string,
    roles?: string[],
  ): Promise<AttendanceView[]> {
    const queryUserId = targetUserId || userId;

    if (targetUserId && targetUserId !== userId && !roles?.includes('admin')) {
      throw new ForbiddenException('Không có quyền xem dữ liệu người khác');
    }

    const user = await this.getUserOrThrow(queryUserId);
    const employeeId = await this.resolveEmployeeId(user);
    const fromDate = from ? new Date(from) : new Date('1970-01-01T00:00:00Z');
    const toDate = to ? new Date(to) : new Date();
    if (Number.isNaN(fromDate.getTime()) || Number.isNaN(toDate.getTime())) {
      throw new BadRequestException('Khoảng thời gian không hợp lệ');
    }

    const records = await this.odooService.fetchAttendanceHistory(
      employeeId,
      fromDate,
      this.makeExclusiveEnd(toDate),
    );
    const config = await this.getConfig(queryUserId);
    const otById = this.computeRangeOt(records, config);

    return records.map((record) =>
      this.toAttendanceView(record, queryUserId, otById.get(record.id) ?? 0),
    );
  }

  async getSummary(userId: string, from: string, to: string) {
    const config = await this.getConfig(userId);
    const user = await this.getUserOrThrow(userId);
    const employeeId = await this.resolveEmployeeId(user);
    const fromDate = new Date(from);
    const toDate = new Date(to);
    if (Number.isNaN(fromDate.getTime()) || Number.isNaN(toDate.getTime())) {
      throw new BadRequestException('Khoảng thời gian không hợp lệ');
    }

    const records = await this.odooService.fetchAttendanceHistory(
      employeeId,
      fromDate,
      this.makeExclusiveEnd(toDate),
    );
    const leaveDays = await this.leaveDayRepo.find({
      where: {
        leave_date: Between(from, to),
      },
      relations: ['leave_request'],
    });
    const approvedLeaveDays = leaveDays.filter(
      (leaveDay) =>
        leaveDay.leave_request?.user_id === userId &&
        leaveDay.leave_request?.status === 'approved',
    );

    const totalDays = new Set(
      records.map((r) => this.toDateKey(new Date(r.check_in))),
    ).size;
    const totalHours = records.reduce(
      (sum, r) => sum + this.getWorkedHours(r),
      0,
    );
    const totalOt = await this.getApprovedOtHoursForRange(
      userId,
      fromDate,
      toDate,
    );

    const [startH, startM] = config.work_start_time.split(':').map(Number);
    const firstCheckinByDay = new Map<string, Date>();
    for (const r of records) {
      const checkin = new Date(r.check_in);
      const dateKey = this.toDateKey(checkin);
      const existing = firstCheckinByDay.get(dateKey);
      if (!existing || checkin < existing) {
        firstCheckinByDay.set(dateKey, checkin);
      }
    }
    const daysLate = [...firstCheckinByDay.values()].filter((checkin) => {
      const ictHour = (checkin.getUTCHours() + 7) % 24;
      const ictMin = checkin.getUTCMinutes();
      return ictHour > startH || (ictHour === startH && ictMin > startM);
    }).length;

    let paidLeaveDays = 0;
    let unpaidLeaveDays = 0;
    let absentWithoutLeaveDays = 0;

    const attendanceDays = new Set(firstCheckinByDay.keys());
    const leaveByDay = new Map<string, { paid: number; unpaid: number }>();
    for (const leaveDay of approvedLeaveDays) {
      const existing = leaveByDay.get(leaveDay.leave_date) ?? {
        paid: 0,
        unpaid: 0,
      };
      if (leaveDay.is_paid) {
        existing.paid += Number(leaveDay.duration_days) || 0;
      } else {
        existing.unpaid += Number(leaveDay.duration_days) || 0;
      }
      leaveByDay.set(leaveDay.leave_date, existing);
    }

    for (const workday of this.getWorkdayDates(fromDate, toDate)) {
      if (attendanceDays.has(workday)) continue;

      const leave = leaveByDay.get(workday);
      if (leave) {
        paidLeaveDays += leave.paid;
        unpaidLeaveDays += leave.unpaid;
        absentWithoutLeaveDays += Math.max(0, 1 - leave.paid - leave.unpaid);
      } else {
        absentWithoutLeaveDays += 1;
      }
    }
    return {
      total_days: totalDays,
      total_hours: Math.round(totalHours * 100) / 100,
      total_ot: Math.round(totalOt * 100) / 100,
      days_late: daysLate,
      paid_leave_days: Math.round(paidLeaveDays * 10) / 10,
      unpaid_leave_days: Math.round(unpaidLeaveDays * 10) / 10,
      absent_without_leave_days: Math.round(absentWithoutLeaveDays * 10) / 10,
      days_absent: Math.round(absentWithoutLeaveDays * 10) / 10,
    };
  }

  async getOtSummary(
    userId: string,
    roles: string[] | undefined,
    from: string,
    to: string,
  ) {
    if (!roles?.includes('admin')) {
      throw new ForbiddenException('Không có quyền xem thống kê OT');
    }

    await this.getUserOrThrow(userId);

    const fromDate = new Date(from);
    const toDate = new Date(to);
    if (Number.isNaN(fromDate.getTime()) || Number.isNaN(toDate.getTime())) {
      throw new BadRequestException('Khoảng thời gian không hợp lệ');
    }

    const approvedOtLeaves = await this.leaveRepo.find({
      where: {
        type: 'ot',
        status: 'approved',
      },
      relations: ['requester'],
    });

    const totals = new Map<
      string,
      { user_id: string; name: string; total_ot: number }
    >();
    for (const leave of approvedOtLeaves) {
      const totalHours = this.calculateApprovedOtHoursForLeaveInRange(
        leave,
        fromDate,
        toDate,
      );
      if (totalHours <= 0) continue;

      const name = leave.requester?.name?.trim() || 'Unknown';
      const existing = totals.get(leave.user_id) ?? {
        user_id: leave.user_id,
        name,
        total_ot: 0,
      };
      existing.total_ot =
        Math.round((existing.total_ot + totalHours) * 100) / 100;
      if (!existing.name || existing.name === 'Unknown') {
        existing.name = name;
      }
      totals.set(leave.user_id, existing);
    }

    return [...totals.values()].sort(
      (a, b) => b.total_ot - a.total_ot || a.name.localeCompare(b.name),
    );
  }

  async getTodayStatus(userId: string) {
    const user = await this.getUserOrThrow(userId);
    const employeeId = await this.resolveEmployeeId(user);
    const records = this.sortSessionsAsc(
      await this.odooService.fetchTodayAttendance(employeeId),
    );
    const config = await this.getConfig(userId);
    const { otById } = this.computeDailyStats(records, config);

    const sessions = records.map((record) =>
      this.toAttendanceView(record, userId, otById.get(record.id) ?? 0),
    );
    const totalHours = sessions.reduce(
      (sum, r) => sum + (Number(r.total_hours) || 0),
      0,
    );
    const totalOt = sessions.reduce(
      (sum, r) => sum + (Number(r.ot_hours) || 0),
      0,
    );
    const hasOpenSession = sessions.some((s) => !s.checkout_at);

    return {
      sessions,
      total_hours: Math.round(totalHours * 100) / 100,
      total_ot: Math.round(totalOt * 100) / 100,
      has_open_session: hasOpenSession,
      session_count: sessions.length,
    };
  }

  private async getUserOrThrow(userId: string): Promise<User> {
    const user = await this.userRepo.findOne({ where: { id: userId } });
    if (!user) {
      throw new BadRequestException('Người dùng không tồn tại');
    }
    return user;
  }

  private async resolveEmployeeId(user: User): Promise<number> {
    if (user.odoo_employee_id) {
      return user.odoo_employee_id;
    }

    if (!user.odoo_uid) {
      throw new ServiceUnavailableException(
        'Không tìm thấy liên kết nhân sự Odoo cho người dùng',
      );
    }

    const resolvedEmployeeId =
      await this.odooService.findEmployeeIdByUserUidOrEmployeeId(user.odoo_uid);

    if (!resolvedEmployeeId) {
      throw new ServiceUnavailableException(
        'Không tìm thấy employee Odoo cho người dùng',
      );
    }

    user.odoo_employee_id = resolvedEmployeeId;
    await this.userRepo.save(user);
    return resolvedEmployeeId;
  }

  private async fetchAttendanceById(
    employeeId: number,
    attendanceId: number,
    from: Date,
    to: Date,
  ): Promise<OdooAttendanceRecord | null> {
    for (let attempt = 1; attempt <= CHECKIN_CONFIRM_ATTEMPTS; attempt++) {
      const records = await this.odooService.fetchAttendanceHistory(
        employeeId,
        from,
        to,
      );
      const record = records.find((candidate) => candidate.id === attendanceId);
      if (record) return record;
      if (attempt < CHECKIN_CONFIRM_ATTEMPTS) {
        await new Promise((resolve) =>
          setTimeout(resolve, CHECKIN_CONFIRM_DELAY_MS * attempt),
        );
      }
    }

    this.logger.error(
      `Unable to confirm Odoo attendance after check-in: employee=${employeeId}, attendance=${attendanceId}`,
    );
    throw new ServiceUnavailableException(
      'Không thể xác nhận phiên checkin trên Odoo',
    );
  }

  private async tryAwardAttendanceEvent(
    userId: string,
    triggerType:
      | 'attendance_checkin'
      | 'attendance_checkout'
      | 'attendance_auto_checkout',
    attendanceId: number,
  ): Promise<AttendanceRewardResult> {
    try {
      const result = await this.rewardsService.awardAttendanceEvent(
        userId,
        triggerType,
        String(attendanceId),
        { attendance_id: attendanceId },
      );
      return {
        awarded: result.awarded === true,
        points:
          result.awarded === true && typeof result.transaction?.points === 'number'
            ? result.transaction.points
            : 0,
      };
    } catch (error) {
      this.logger.warn(
        `Rewards award failed for ${triggerType} user=${userId} attendance=${attendanceId}: ${String(error)}`,
      );
      return { awarded: false, points: 0 };
    }
  }

  private sortSessionsAsc(records: OdooAttendanceRecord[]) {
    return [...records].sort(
      (a, b) => new Date(a.check_in).getTime() - new Date(b.check_in).getTime(),
    );
  }

  private computeRangeOt(
    records: OdooAttendanceRecord[],
    config: PayrollConfig,
  ): Map<number, number> {
    const groups = new Map<string, OdooAttendanceRecord[]>();
    for (const record of records) {
      const dateKey = this.toDateKey(new Date(record.check_in));
      groups.set(dateKey, [...(groups.get(dateKey) ?? []), record]);
    }

    const otById = new Map<number, number>();
    for (const dayRecords of groups.values()) {
      const { otById: dailyOt } = this.computeDailyStats(dayRecords, config);
      for (const [id, ot] of dailyOt.entries()) {
        otById.set(id, ot);
      }
    }
    return otById;
  }

  private computeDailyStats(
    records: OdooAttendanceRecord[],
    config: PayrollConfig,
  ) {
    const ordered = this.sortSessionsAsc(records);
    const otById = new Map<number, number>();
    let runningHours = 0;
    let assignedOt = 0;

    for (const record of ordered) {
      const workedHours = this.getWorkedHours(record);
      runningHours += workedHours;
      const dailyOt = Math.max(
        0,
        Math.round(
          (runningHours - Number(config.standard_hours_per_day)) * 100,
        ) / 100,
      );
      const recordOt = Math.max(
        0,
        Math.round((dailyOt - assignedOt) * 100) / 100,
      );
      otById.set(record.id, recordOt);
      assignedOt += recordOt;
    }

    return { otById };
  }

  private getWorkedHours(
    record: Pick<
      OdooAttendanceRecord,
      'check_in' | 'check_out' | 'worked_hours'
    >,
    fallbackCheckout?: Date,
  ) {
    if (typeof record.worked_hours === 'number') {
      return Number(record.worked_hours) || 0;
    }

    const checkout = record.check_out
      ? new Date(record.check_out)
      : fallbackCheckout;
    if (!checkout) return 0;

    const diffMs = checkout.getTime() - new Date(record.check_in).getTime();
    return Math.round((diffMs / (1000 * 60 * 60)) * 100) / 100;
  }

  private toAttendanceView(
    record: OdooAttendanceRecord,
    userId: string,
    otHours: number,
    rewardResult: AttendanceRewardResult = { awarded: false, points: 0 },
  ): AttendanceView {
    return {
      id: String(record.id),
      user_id: userId,
      checkin_at: new Date(record.check_in),
      checkout_at: record.check_out ? new Date(record.check_out) : null,
      checkin_lat: null,
      checkin_lng: null,
      checkout_lat: null,
      checkout_lng: null,
      device_id: null,
      total_hours: Math.round(this.getWorkedHours(record) * 100) / 100,
      ot_hours: Math.round(otHours * 100) / 100,
      odoo_synced: true,
      odoo_synced_at: null,
      created_at: new Date(record.check_in),
      rewarded: rewardResult.awarded,
      reward_points: rewardResult.points,
    };
  }

  private getDayRange(reference: Date) {
    const start = new Date(reference);
    start.setUTCHours(0, 0, 0, 0);
    const end = new Date(start);
    end.setUTCDate(end.getUTCDate() + 1);
    return { start, end };
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

  private validateTimestamp(timestamp: Date) {
    if (Number.isNaN(timestamp.getTime())) {
      throw new BadRequestException('Timestamp không hợp lệ');
    }

    const now = new Date();
    const diff = now.getTime() - timestamp.getTime();
    if (diff > 24 * 60 * 60 * 1000) {
      throw new BadRequestException('Timestamp quá cũ (hơn 24 giờ)');
    }

    if (diff < -5 * 60 * 1000) {
      throw new BadRequestException('Timestamp không thể ở tương lai');
    }
  }

  private async getConfig(userId: string): Promise<PayrollConfig> {
    let config = await this.configRepo.findOne({ where: { user_id: userId } });
    if (!config) {
      config = this.configRepo.create({ user_id: userId });
      config = await this.configRepo.save(config);
    }
    return config;
  }

  private getWorkdayDates(from: Date, to: Date): string[] {
    const dates: string[] = [];
    const current = new Date(from);
    current.setUTCHours(0, 0, 0, 0);
    const end = to < new Date() ? to : new Date();
    end.setUTCHours(0, 0, 0, 0);

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
    const rangeEndExclusive = this.toStartOfUtcDay(to);

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

  private calculateApprovedOtHoursForLeaveInRange(
    leave: Pick<
      LeaveRequest,
      'start_time' | 'end_time' | 'start_date' | 'end_date'
    >,
    from: Date,
    to: Date,
  ): number {
    return this.calculateApprovedOtHoursForLeave(
      leave,
      this.toStartOfUtcDay(from),
      this.toStartOfUtcDay(to),
    );
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
}
