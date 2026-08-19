import {
  Injectable,
  ConflictException,
  BadRequestException,
  ForbiddenException,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Between } from 'typeorm';
import { Attendance } from '../entities/attendance.entity.js';
import { PayrollConfig } from '../entities/payroll-config.entity.js';
import { User } from '../../auth/entities/user.entity.js';
import { CheckinDto, CheckoutDto } from '../dto/hr.dto.js';

@Injectable()
export class AttendanceService {
  private readonly logger = new Logger(AttendanceService.name);

  constructor(
    @InjectRepository(Attendance)
    private readonly attendanceRepo: Repository<Attendance>,
    @InjectRepository(PayrollConfig)
    private readonly configRepo: Repository<PayrollConfig>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
  ) {}

  async checkin(userId: string, dto: CheckinDto): Promise<Attendance> {
    const timestamp = new Date(dto.timestamp);

    // Validate timestamp not > 24h old
    const now = new Date();
    const diff = now.getTime() - timestamp.getTime();
    if (diff > 24 * 60 * 60 * 1000) {
      throw new BadRequestException('Timestamp quá cũ (hơn 24 giờ)');
    }

    // Check no open session (checkin without checkout)
    const { todayStart, todayEnd } = this.getTodayRange();

    const openSession = await this.attendanceRepo
      .createQueryBuilder('a')
      .where('a.user_id = :userId', { userId })
      .andWhere('a.checkin_at >= :todayStart', { todayStart })
      .andWhere('a.checkin_at < :todayEnd', { todayEnd })
      .andWhere('a.checkout_at IS NULL')
      .getOne();

    if (openSession) {
      throw new ConflictException(
        'Bạn đang có phiên chưa checkout. Hãy checkout trước khi checkin lại.',
      );
    }

    const record = this.attendanceRepo.create({
      user_id: userId,
      checkin_at: timestamp,
      checkin_lat: dto.lat ?? null,
      checkin_lng: dto.lng ?? null,
      device_id: dto.device_id ?? null,
    });

    return this.attendanceRepo.save(record);
  }

  async checkout(userId: string, dto: CheckoutDto): Promise<Attendance> {
    const timestamp = new Date(dto.timestamp);

    // Find the latest open session today (checkin without checkout)
    const { todayStart, todayEnd } = this.getTodayRange();

    const openSession = await this.attendanceRepo
      .createQueryBuilder('a')
      .where('a.user_id = :userId', { userId })
      .andWhere('a.checkin_at >= :todayStart', { todayStart })
      .andWhere('a.checkin_at < :todayEnd', { todayEnd })
      .andWhere('a.checkout_at IS NULL')
      .orderBy('a.checkin_at', 'DESC')
      .getOne();

    if (!openSession) {
      throw new BadRequestException('Không có phiên checkin đang mở');
    }

    // Calculate session hours
    const diffMs = timestamp.getTime() - openSession.checkin_at.getTime();
    const sessionHours =
      Math.round((diffMs / (1000 * 60 * 60)) * 100) / 100;

    openSession.checkout_at = timestamp;
    openSession.checkout_lat = dto.lat ?? null;
    openSession.checkout_lng = dto.lng ?? null;
    openSession.total_hours = sessionHours;

    // Calculate daily OT: sum all completed sessions today
    const config = await this.getConfig();
    const allToday = await this.attendanceRepo
      .createQueryBuilder('a')
      .where('a.user_id = :userId', { userId })
      .andWhere('a.checkin_at >= :todayStart', { todayStart })
      .andWhere('a.checkin_at < :todayEnd', { todayEnd })
      .andWhere('a.checkout_at IS NOT NULL')
      .andWhere('a.id != :currentId', { currentId: openSession.id })
      .getMany();

    const previousHours = allToday.reduce(
      (sum, r) => sum + (Number(r.total_hours) || 0),
      0,
    );
    const dailyTotal = previousHours + sessionHours;
    const dailyOt = Math.max(
      0,
      Math.round(
        (dailyTotal - Number(config.standard_hours_per_day)) * 100,
      ) / 100,
    );

    // Store OT on the last session of the day
    openSession.ot_hours = Math.max(
      0,
      Math.round(
        (dailyOt -
          allToday.reduce((sum, r) => sum + (Number(r.ot_hours) || 0), 0)) *
          100,
      ) / 100,
    );

    return this.attendanceRepo.save(openSession);
  }

  async getHistory(
    userId: string,
    from?: string,
    to?: string,
    targetUserId?: string,
    roles?: string[],
  ): Promise<Attendance[]> {
    const queryUserId = targetUserId || userId;

    if (targetUserId && targetUserId !== userId) {
      if (!roles?.includes('admin')) {
        throw new ForbiddenException('Không có quyền xem dữ liệu người khác');
      }
    }

    const qb = this.attendanceRepo
      .createQueryBuilder('a')
      .where('a.user_id = :userId', { userId: queryUserId })
      .orderBy('a.checkin_at', 'DESC');

    if (from) qb.andWhere('a.checkin_at >= :from', { from });
    if (to) qb.andWhere('a.checkin_at <= :to', { to });

    return qb.getMany();
  }

  async getSummary(userId: string, from: string, to: string) {
    const config = await this.getConfig();
    const records = await this.attendanceRepo
      .createQueryBuilder('a')
      .where('a.user_id = :userId', { userId })
      .andWhere('a.checkin_at >= :from', { from })
      .andWhere('a.checkin_at <= :to', { to })
      .getMany();

    const totalDays = new Set(
      records.map((r) => new Date(r.checkin_at).toISOString().substring(0, 10)),
    ).size;
    const totalHours = records.reduce(
      (sum, r) => sum + (Number(r.total_hours) || 0),
      0,
    );
    const totalOt = records.reduce(
      (sum, r) => sum + (Number(r.ot_hours) || 0),
      0,
    );

    // Count late days — only check the FIRST checkin of each day
    const [startH, startM] = config.work_start_time.split(':').map(Number);
    const firstCheckinByDay = new Map<string, Date>();
    for (const r of records) {
      const dateKey = new Date(r.checkin_at).toISOString().substring(0, 10);
      const existing = firstCheckinByDay.get(dateKey);
      if (!existing || new Date(r.checkin_at) < existing) {
        firstCheckinByDay.set(dateKey, new Date(r.checkin_at));
      }
    }
    const daysLate = [...firstCheckinByDay.values()].filter((checkin) => {
      const ictHour = (checkin.getUTCHours() + 7) % 24;
      const ictMin = checkin.getUTCMinutes();
      return ictHour > startH || (ictHour === startH && ictMin > startM);
    }).length;

    return {
      total_days: totalDays,
      total_hours: Math.round(totalHours * 100) / 100,
      total_ot: Math.round(totalOt * 100) / 100,
      days_late: daysLate,
      days_absent: this.countWorkdays(new Date(from), new Date(to)) - totalDays,
    };
  }

  private countWorkdays(from: Date, to: Date): number {
    let count = 0;
    const current = new Date(from);
    const end = to < new Date() ? to : new Date();
    while (current <= end) {
      const day = current.getDay();
      if (day !== 0 && day !== 6) count++;
      current.setDate(current.getDate() + 1);
    }
    return count;
  }

  async getTodayStatus(userId: string) {
    const { todayStart, todayEnd } = this.getTodayRange();

    const sessions = await this.attendanceRepo
      .createQueryBuilder('a')
      .where('a.user_id = :userId', { userId })
      .andWhere('a.checkin_at >= :todayStart', { todayStart })
      .andWhere('a.checkin_at < :todayEnd', { todayEnd })
      .orderBy('a.checkin_at', 'ASC')
      .getMany();

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

  private getTodayRange() {
    const todayStart = new Date();
    todayStart.setUTCHours(0, 0, 0, 0);
    const todayEnd = new Date(todayStart);
    todayEnd.setUTCDate(todayEnd.getUTCDate() + 1);
    return { todayStart, todayEnd };
  }

  private async getConfig(): Promise<PayrollConfig> {
    let config = await this.configRepo.findOne({ where: { id: 1 } });
    if (!config) {
      config = this.configRepo.create({ id: 1 });
      config = await this.configRepo.save(config);
    }
    return config;
  }
}
