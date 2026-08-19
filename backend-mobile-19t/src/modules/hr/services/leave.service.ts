import {
  Injectable,
  BadRequestException,
  ForbiddenException,
  NotFoundException,
  Logger,
} from '@nestjs/common';
import { InjectDataSource, InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import { LeaveRequest } from '../entities/leave-request.entity.js';
import { User } from '../../auth/entities/user.entity.js';
import { UserRole } from '../../auth/entities/user-role.entity.js';
import { Role } from '../../auth/entities/role.entity.js';
import { CreateLeaveDto } from '../dto/hr.dto.js';
import { FirebaseService } from '../../notification/services/firebase.service.js';
import { UserSession } from '../../auth/entities/user-session.entity.js';
import { LeaveRequestDay } from '../entities/leave-request-day.entity.js';
import { YearlyLeaveBalance } from '../entities/yearly-leave-balance.entity.js';
import { CompanyWfhYearlyConfig } from '../entities/company-wfh-yearly-config.entity.js';
import { YearlyWfhBalance } from '../entities/yearly-wfh-balance.entity.js';
import { PayrollConfigService } from '../services/payroll-config.service.js';
import { canApproveLeaveRoles } from '../hr-role.utils.js';
import { AuditLogService } from '../../auth/services/audit-log.service.js';

type LeaveDurationPart = {
  leave_date: string;
  duration_days: number;
  half_day_part: string | null;
};

type LeaveBalanceSnapshot = {
  year: number;
  employment_status: string;
  is_paid_leave_eligible: boolean;
  allocated_days: number;
  used_paid_days: number;
  remaining_paid_days: number;
  has_remaining_paid_leave: boolean;
};

type WfhBalanceSnapshot = {
  year: number;
  allocated_days: number;
  used_days: number;
  remaining_days: number;
  has_remaining_days: boolean;
  is_override: boolean;
};

export type LeaveListItem = LeaveRequest & {
  user_name: string | null;
  approved_by_name: string | null;
  cancelled_by_name: string | null;
};

@Injectable()
export class LeaveService {
  private readonly logger = new Logger(LeaveService.name);

  constructor(
    @InjectRepository(LeaveRequest)
    private readonly leaveRepo: Repository<LeaveRequest>,
    @InjectRepository(LeaveRequestDay)
    private readonly leaveDayRepo: Repository<LeaveRequestDay>,
    @InjectRepository(YearlyLeaveBalance)
    private readonly yearlyBalanceRepo: Repository<YearlyLeaveBalance>,
    @InjectRepository(CompanyWfhYearlyConfig)
    private readonly companyWfhConfigRepo: Repository<CompanyWfhYearlyConfig>,
    @InjectRepository(YearlyWfhBalance)
    private readonly yearlyWfhBalanceRepo: Repository<YearlyWfhBalance>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    @InjectRepository(UserRole)
    private readonly userRoleRepo: Repository<UserRole>,
    @InjectRepository(Role)
    private readonly roleRepo: Repository<Role>,
    @InjectRepository(UserSession)
    private readonly sessionRepo: Repository<UserSession>,
    @InjectDataSource()
    private readonly dataSource: DataSource,
    private readonly firebaseService: FirebaseService,
    private readonly payrollConfigService: PayrollConfigService,
    private readonly auditLogService: AuditLogService,
  ) {}

  async create(userId: string, dto: CreateLeaveDto): Promise<LeaveRequest> {
    if (new Date(dto.end_date) < new Date(dto.start_date)) {
      throw new BadRequestException('Ngày kết thúc phải sau ngày bắt đầu');
    }
    if (dto.type === 'ot') {
      if (!dto.start_time || !dto.end_time) {
        throw new BadRequestException(
          'Đơn OT phải có giờ bắt đầu và giờ kết thúc',
        );
      }
      // if (dto.end_time <= dto.start_time) {
      //   throw new BadRequestException('Giờ kết thúc phải lớn hơn giờ bắt đầu');
      // }
      if (dto.is_half_day || dto.half_day_part) {
        throw new BadRequestException('Đơn OT không hỗ trợ tuỳ chọn nửa ngày');
      }
    } else {
      if (dto.start_time || dto.end_time) {
        throw new BadRequestException('Đơn nghỉ phép không hỗ trợ theo giờ');
      }
      if (
        dto.type === 'wfh' &&
        new Date(dto.start_date).getUTCFullYear() !==
          new Date(dto.end_date).getUTCFullYear()
      ) {
        throw new BadRequestException('Đơn WFH phải nằm trong cùng một năm');
      }
      if (dto.is_half_day) {
        if (dto.start_date !== dto.end_date) {
          throw new BadRequestException(
            'Đơn nghỉ nửa ngày phải bắt đầu và kết thúc trong cùng một ngày',
          );
        }
        if (!dto.half_day_part) {
          throw new BadRequestException(
            'Đơn nghỉ nửa ngày phải chọn buổi sáng hoặc buổi chiều',
          );
        }
      } else if (dto.half_day_part) {
        throw new BadRequestException(
          'Chỉ được chọn buổi khi đơn nghỉ là nửa ngày',
        );
      }
    }

    const requestedDays =
      dto.type === 'ot' ? 0 : this.calculateRequestedDays(dto);

    let otTime = dto.ot_time ?? 0;
    if (dto.type === 'ot' && !dto.ot_time && dto.start_time && dto.end_time) {
      otTime = this.calculateOtHours(
        dto.start_date,
        dto.end_date,
        dto.start_time,
        dto.end_time,
      );
    }

    const record = this.leaveRepo.create({
      user_id: userId,
      type: dto.type,
      start_date: dto.start_date,
      end_date: dto.end_date,
      start_time: dto.start_time ?? null,
      end_time: dto.end_time ?? null,
      is_half_day: dto.is_half_day ?? false,
      half_day_part: dto.half_day_part ?? null,
      requested_days: requestedDays,
      ot_time: otTime,
      paid_days: 0,
      unpaid_days: 0,
      reason: dto.reason ?? null,
      status: 'draft',
    });
    return this.leaveRepo.save(record);
  }

  async submit(userId: string, leaveId: string): Promise<LeaveRequest> {
    const leave = await this.leaveRepo.findOne({ where: { id: leaveId } });
    if (!leave) throw new NotFoundException('Đơn nghỉ không tồn tại');
    if (leave.user_id !== userId)
      throw new ForbiddenException('Không phải đơn của bạn');
    if (leave.status !== 'draft')
      throw new BadRequestException('Chỉ có thể gửi đơn nháp');

    leave.status = 'submitted';
    const saved = await this.leaveRepo.save(leave);

    // Notify admins
    const employee = await this.userRepo.findOne({ where: { id: userId } });
    const typeLabel =
      {
        annual: 'phép năm',
        sick: 'nghỉ ốm',
        personal: 'việc riêng',
        wfh: 'WFH',
      }[leave.type] || leave.type;
    await this.notifyApprovers(
      `${employee?.name || 'Nhân viên'} xin ${typeLabel}`,
      `Từ ${leave.start_date} đến ${leave.end_date}`,
      { type: 'hr_leave_request', leave_id: leaveId },
    );

    return saved;
  }

  async approve(adminUserId: string, leaveId: string): Promise<LeaveRequest> {
    const leave = await this.leaveRepo.findOne({ where: { id: leaveId } });
    if (!leave) throw new NotFoundException('Đơn nghỉ không tồn tại');
    if (leave.status !== 'submitted')
      throw new BadRequestException('Chỉ có thể duyệt đơn đã gửi');

    const saved = await this.dataSource.transaction(async (manager) => {
      const leaveRepo = manager.getRepository(LeaveRequest);
      const leaveDayRepo = manager.getRepository(LeaveRequestDay);
      const yearlyBalanceRepo = manager.getRepository(YearlyLeaveBalance);
      const companyWfhConfigRepo = manager.getRepository(
        CompanyWfhYearlyConfig,
      );
      const yearlyWfhBalanceRepo = manager.getRepository(YearlyWfhBalance);
      const userRepo = manager.getRepository(User);

      const leaveToApprove = await leaveRepo.findOne({
        where: { id: leaveId },
      });
      if (!leaveToApprove)
        throw new NotFoundException('Đơn nghỉ không tồn tại');
      if (leaveToApprove.status !== 'submitted') {
        throw new BadRequestException('Chỉ có thể duyệt đơn đã gửi');
      }

      const employee = await userRepo.findOne({
        where: { id: leaveToApprove.user_id },
      });
      if (!employee) throw new NotFoundException('Nhân viên không tồn tại');

      leaveToApprove.status = 'approved';
      leaveToApprove.approved_by = adminUserId;
      leaveToApprove.approved_at = new Date();
      leaveToApprove.odoo_synced = false;

      await leaveDayRepo.delete({ leave_request_id: leaveId });

      let paidDays = 0;
      let unpaidDays = 0;
      const dayRows: LeaveRequestDay[] = [];

      if (leaveToApprove.type === 'wfh') {
        const wfhBalance = await this.getOrCreateWfhBalance(
          yearlyWfhBalanceRepo,
          companyWfhConfigRepo,
          leaveToApprove.user_id,
          new Date(
            `${leaveToApprove.start_date}T00:00:00.000Z`,
          ).getUTCFullYear(),
        );
        const remainingDays = Math.max(
          0,
          this.roundDays(
            Number(wfhBalance.allocated_days) - Number(wfhBalance.used_days),
          ),
        );
        if (remainingDays < Number(leaveToApprove.requested_days)) {
          throw new BadRequestException('Không đủ quota WFH còn lại để duyệt');
        }

        const requestedParts = this.expandLeaveParts(leaveToApprove);
        for (const part of requestedParts) {
          dayRows.push(
            leaveDayRepo.create({
              leave_request_id: leaveId,
              leave_date: part.leave_date,
              duration_days: part.duration_days,
              half_day_part: part.half_day_part,
              is_paid: false,
            }),
          );
        }
        if (dayRows.length > 0) {
          await leaveDayRepo.save(dayRows);
        }

        wfhBalance.used_days = this.roundDays(
          Number(wfhBalance.used_days) + Number(leaveToApprove.requested_days),
        );
        await yearlyWfhBalanceRepo.save(wfhBalance);
      } else if (leaveToApprove.type !== 'ot') {
        const requestedParts = this.expandLeaveParts(leaveToApprove);
        for (const part of requestedParts) {
          const policyRows = await this.applyPaidLeavePolicy(
            yearlyBalanceRepo,
            employee,
            leaveToApprove.type,
            part,
          );
          for (const row of policyRows) {
            paidDays += row.is_paid ? row.duration_days : 0;
            unpaidDays += row.is_paid ? 0 : row.duration_days;
            dayRows.push(
              leaveDayRepo.create({
                leave_request_id: leaveId,
                leave_date: row.leave_date,
                duration_days: row.duration_days,
                half_day_part: row.half_day_part,
                is_paid: row.is_paid,
              }),
            );
          }
        }
        if (dayRows.length > 0) {
          await leaveDayRepo.save(dayRows);
        }
      }

      leaveToApprove.paid_days = this.roundDays(paidDays);
      leaveToApprove.unpaid_days = this.roundDays(unpaidDays);
      return leaveRepo.save(leaveToApprove);
    });

    const admin = await this.userRepo.findOne({ where: { id: adminUserId } });
    await this.notifyUser(
      leave.user_id,
      `${admin?.name || 'Quản lý'} đã duyệt đơn nghỉ của bạn`,
      `Từ ${leave.start_date} đến ${leave.end_date}`,
      { type: 'hr_leave_approved', leave_id: leaveId },
    );

    await this.auditLogService.logEvent({
      category: 'hr_leave',
      type: 'hr_leave.approved',
      userId: adminUserId,
      entityType: 'leave_request',
      entityId: leaveId,
      status: 'approved',
      metadata: {
        requesterUserId: leave.user_id,
        previousStatus: 'submitted',
        newStatus: 'approved',
        leaveType: leave.type,
        startDate: leave.start_date,
        endDate: leave.end_date,
      },
    });

    return saved;
  }

  async reject(
    adminUserId: string,
    leaveId: string,
    rejectReason: string,
  ): Promise<LeaveRequest> {
    const leave = await this.leaveRepo.findOne({ where: { id: leaveId } });
    if (!leave) throw new NotFoundException('Đơn nghỉ không tồn tại');
    if (leave.status !== 'submitted')
      throw new BadRequestException('Chỉ có thể từ chối đơn đã gửi');

    leave.status = 'rejected';
    leave.reject_reason = rejectReason;
    const saved = await this.leaveRepo.save(leave);

    const admin = await this.userRepo.findOne({ where: { id: adminUserId } });
    await this.notifyUser(
      leave.user_id,
      `${admin?.name || 'Quản lý'} đã từ chối đơn nghỉ`,
      rejectReason,
      { type: 'hr_leave_rejected', leave_id: leaveId },
    );

    await this.auditLogService.logEvent({
      category: 'hr_leave',
      type: 'hr_leave.rejected',
      userId: adminUserId,
      entityType: 'leave_request',
      entityId: leaveId,
      status: 'rejected',
      reason: rejectReason,
      metadata: {
        requesterUserId: leave.user_id,
        previousStatus: 'submitted',
        newStatus: 'rejected',
      },
    });

    return saved;
  }

  async cancelApprovedLeave(
    actorUserId: string,
    leaveId: string,
    reason: string,
  ): Promise<LeaveRequest> {
    const cancelReason = reason.trim();
    if (!cancelReason) {
      throw new BadRequestException('Vui lòng nhập lý do hủy đơn');
    }

    const existingLeave = await this.leaveRepo.findOne({
      where: { id: leaveId },
    });
    if (!existingLeave) {
      throw new NotFoundException('Đơn nghỉ không tồn tại');
    }
    if (existingLeave.status !== 'approved') {
      throw new BadRequestException('Chỉ có thể hủy đơn đã duyệt');
    }

    const saved = await this.dataSource.transaction(async (manager) => {
      const leaveRepo = manager.getRepository(LeaveRequest);
      const leaveDayRepo = manager.getRepository(LeaveRequestDay);
      const yearlyBalanceRepo = manager.getRepository(YearlyLeaveBalance);
      const yearlyWfhBalanceRepo = manager.getRepository(YearlyWfhBalance);

      const leave = await leaveRepo.findOne({
        where: { id: leaveId },
        lock: { mode: 'pessimistic_write' },
      });
      if (!leave) {
        throw new NotFoundException('Đơn nghỉ không tồn tại');
      }
      if (leave.status !== 'approved') {
        throw new BadRequestException('Chỉ có thể hủy đơn đã duyệt');
      }

      const leaveDays = await leaveDayRepo.find({
        where: { leave_request_id: leaveId },
      });

      if (leave.type === 'wfh') {
        const year = new Date(
          `${leave.start_date}T00:00:00.000Z`,
        ).getUTCFullYear();
        const balance = await yearlyWfhBalanceRepo.findOne({
          where: { user_id: leave.user_id, year },
          lock: { mode: 'pessimistic_write' },
        });
        if (!balance) {
          throw new BadRequestException('Không tìm thấy quota WFH để hoàn lại');
        }
        balance.used_days = this.roundDays(
          Math.max(0, Number(balance.used_days) - Number(leave.requested_days)),
        );
        await yearlyWfhBalanceRepo.save(balance);
      } else if (leave.type !== 'ot') {
        const paidDaysByYear = new Map<number, number>();
        for (const day of leaveDays) {
          if (!day.is_paid) continue;
          const year = Number(day.leave_date.slice(0, 4));
          paidDaysByYear.set(
            year,
            this.roundDays(
              (paidDaysByYear.get(year) ?? 0) + Number(day.duration_days),
            ),
          );
        }

        const recordedPaidDays = [...paidDaysByYear.values()].reduce(
          (sum, days) => this.roundDays(sum + days),
          0,
        );
        const missingPaidDays = this.roundDays(
          Math.max(0, Number(leave.paid_days) - recordedPaidDays),
        );
        if (missingPaidDays > 0) {
          const startYear = Number(leave.start_date.slice(0, 4));
          paidDaysByYear.set(
            startYear,
            this.roundDays(
              (paidDaysByYear.get(startYear) ?? 0) + missingPaidDays,
            ),
          );
        }

        for (const [year, paidDays] of paidDaysByYear) {
          const balance = await yearlyBalanceRepo.findOne({
            where: { user_id: leave.user_id, year },
            lock: { mode: 'pessimistic_write' },
          });
          if (!balance) {
            throw new BadRequestException(
              `Không tìm thấy quota phép năm ${year} để hoàn lại`,
            );
          }
          balance.used_paid_days = this.roundDays(
            Math.max(0, Number(balance.used_paid_days) - paidDays),
          );
          await yearlyBalanceRepo.save(balance);
        }
      }

      leave.status = 'cancelled';
      leave.cancelled_by = actorUserId;
      leave.cancelled_at = new Date();
      leave.cancel_reason = cancelReason;
      leave.odoo_synced = false;
      return leaveRepo.save(leave);
    });

    const actor = await this.userRepo.findOne({
      where: { id: actorUserId },
    });
    await this.notifyUser(
      existingLeave.user_id,
      `${actor?.name || 'Quản lý'} đã hủy đơn đã duyệt của bạn`,
      cancelReason,
      { type: 'hr_leave_cancelled', leave_id: leaveId },
    );

    await this.auditLogService.logEvent({
      category: 'hr_leave',
      type: 'hr_leave.cancelled',
      userId: actorUserId,
      entityType: 'leave_request',
      entityId: leaveId,
      status: 'cancelled',
      reason: cancelReason,
      metadata: {
        requesterUserId: existingLeave.user_id,
        previousStatus: 'approved',
        newStatus: 'cancelled',
        leaveType: existingLeave.type,
        startDate: existingLeave.start_date,
        endDate: existingLeave.end_date,
      },
    });

    return saved;
  }

  async getLeaves(
    userId: string,
    status?: string,
    targetUserId?: string,
    roles?: string[],
    year?: number,
    month?: number,
  ): Promise<{ otHours: number; leaves: LeaveListItem[] }> {
    const canApprove = canApproveLeaveRoles(roles);

    const qb = this.leaveRepo
      .createQueryBuilder('l')
      .leftJoin('l.requester', 'requester')
      .addSelect('requester.name', 'user_name')
      .leftJoin('l.approver', 'approver')
      .addSelect('approver.name', 'approved_by_name')
      .leftJoin('l.canceller', 'canceller')
      .addSelect('canceller.name', 'cancelled_by_name')
      .orderBy('l.created_at', 'DESC');

    if (targetUserId && canApprove) {
      qb.where('l.user_id = :uid', { uid: targetUserId });
    } else if (canApprove && !targetUserId) {
      // Admin/manager sees all
    } else {
      qb.where('l.user_id = :uid', { uid: userId });
    }

    if (status) qb.andWhere('l.status = :status', { status });

    if (year != null && month != null) {
      const startDay =
        await this.payrollConfigService.getPayrollConfigStartDay(userId);
      const cycleStart = new Date(Date.UTC(year, month - 2, startDay))
        .toISOString()
        .slice(0, 10);
      const cycleEnd = new Date(Date.UTC(year, month - 1, startDay))
        .toISOString()
        .slice(0, 10);

      qb.andWhere('l.start_date < :cycleEnd AND l.end_date >= :cycleStart', {
        cycleStart,
        cycleEnd,
      });
    }

    const { entities, raw } = await qb.getRawAndEntities();

    // tổng số giờ OT trong kỳ lương hiện tại
    const otHours = entities.reduce((sum, leave) => {
      if (leave.type === 'ot' && leave.status === 'approved') {
        return sum + Number(leave.ot_time);
      }
      return sum;
    }, 0);

    return {
      otHours: otHours ?? 0,
      leaves: entities.map((leave, index) => ({
        ...leave,
        user_name: raw[index]?.user_name ?? null,
        approved_by_name: raw[index]?.approved_by_name ?? null,
        cancelled_by_name: raw[index]?.cancelled_by_name ?? null,
      })),
    };
  }

  async getLeaveBalance(
    userId: string,
    year?: number,
  ): Promise<LeaveBalanceSnapshot> {
    const employee = await this.userRepo.findOne({ where: { id: userId } });
    if (!employee) {
      throw new NotFoundException('Nhân viên không tồn tại');
    }

    const referenceDate = new Date();
    const targetYear = year ?? referenceDate.getUTCFullYear();

    let balance = await this.yearlyBalanceRepo.findOne({
      where: {
        user_id: userId,
        year: targetYear,
      },
    });

    if (!balance) {
      balance = this.yearlyBalanceRepo.create({
        user_id: userId,
        year: targetYear,
        allocated_days: employee.employment_status === 'official' ? 12 : 0,
        used_paid_days: 0,
      });
    }

    const allocatedDays =
      employee.employment_status === 'official'
        ? Number(balance.allocated_days)
        : 0;
    const usedPaidDays =
      employee.employment_status === 'official'
        ? Number(balance.used_paid_days)
        : 0;
    const remainingPaidDays = Math.max(
      0,
      this.roundDays(allocatedDays - usedPaidDays),
    );

    return {
      year: targetYear,
      employment_status: employee.employment_status,
      is_paid_leave_eligible: employee.employment_status === 'official',
      allocated_days: allocatedDays,
      used_paid_days: usedPaidDays,
      remaining_paid_days: remainingPaidDays,
      has_remaining_paid_leave: remainingPaidDays > 0,
    };
  }

  async getWfhBalance(
    userId: string,
    year?: number,
  ): Promise<WfhBalanceSnapshot> {
    const employee = await this.userRepo.findOne({ where: { id: userId } });
    if (!employee) {
      throw new NotFoundException('Nhân viên không tồn tại');
    }

    const targetYear = year ?? new Date().getUTCFullYear();
    const balance = await this.getOrCreateWfhBalance(
      this.yearlyWfhBalanceRepo,
      this.companyWfhConfigRepo,
      userId,
      targetYear,
    );

    return this.toWfhBalanceSnapshot(balance);
  }

  async getCompanyWfhConfig(
    year?: number,
  ): Promise<CompanyWfhYearlyConfig | null> {
    const targetYear = year ?? new Date().getUTCFullYear();
    return this.companyWfhConfigRepo.findOne({ where: { year: targetYear } });
  }

  async updateCompanyWfhConfig(
    year: number,
    allocatedDays: number,
  ): Promise<CompanyWfhYearlyConfig> {
    let config = await this.companyWfhConfigRepo.findOne({ where: { year } });
    if (!config) {
      config = this.companyWfhConfigRepo.create({
        year,
        allocated_days: this.roundDays(allocatedDays),
      });
    } else {
      config.allocated_days = this.roundDays(allocatedDays);
    }

    const saved = await this.companyWfhConfigRepo.save(config);

    await this.yearlyWfhBalanceRepo.update(
      { year, is_override: false },
      {
        allocated_days: saved.allocated_days,
      },
    );

    return saved;
  }

  async getUserWfhBalance(
    userId: string,
    year?: number,
  ): Promise<WfhBalanceSnapshot> {
    return this.getWfhBalance(userId, year);
  }

  async updateUserWfhBalance(
    userId: string,
    year: number,
    allocatedDays: number,
  ): Promise<WfhBalanceSnapshot> {
    const employee = await this.userRepo.findOne({ where: { id: userId } });
    if (!employee) {
      throw new NotFoundException('Nhân viên không tồn tại');
    }

    let balance = await this.yearlyWfhBalanceRepo.findOne({
      where: { user_id: userId, year },
    });

    if (!balance) {
      balance = this.yearlyWfhBalanceRepo.create({
        user_id: userId,
        year,
        allocated_days: this.roundDays(allocatedDays),
        used_days: 0,
        is_override: true,
      });
    } else {
      balance.allocated_days = this.roundDays(allocatedDays);
      balance.is_override = true;
    }

    const saved = await this.yearlyWfhBalanceRepo.save(balance);
    return this.toWfhBalanceSnapshot(saved);
  }

  private async notifyApprovers(
    title: string,
    body: string,
    data: Record<string, string>,
  ) {
    const approverRoles = await this.roleRepo.find({
      where: [{ name: 'admin' }, { name: 'manager' }],
    });
    if (approverRoles.length === 0) return;

    const approverRoleIds = approverRoles.map((role) => role.id);
    const approverUserRoles = await this.userRoleRepo
      .createQueryBuilder('userRole')
      .where('userRole.role_id IN (:...roleIds)', { roleIds: approverRoleIds })
      .getMany();

    const notifiedUserIds = new Set<string>();
    for (const ur of approverUserRoles) {
      if (notifiedUserIds.has(ur.user_id)) continue;
      notifiedUserIds.add(ur.user_id);
      await this.notifyUser(ur.user_id, title, body, data);
    }
  }

  private async notifyUser(
    userId: string,
    title: string,
    body: string,
    data: Record<string, string>,
  ) {
    if (!this.firebaseService.isEnabled()) return;
    const sessions = await this.sessionRepo.find({
      where: { user_id: userId },
      select: ['id', 'fcm_token'],
    });
    for (const s of sessions) {
      if (!s.fcm_token) continue;
      try {
        await this.firebaseService.sendPush(s.fcm_token, title, body, data);
      } catch (err: any) {
        this.logger.error(
          `Failed to send leave push notification to session ${s.id}: ${err.message}`,
        );
      }
    }
  }

  private calculateRequestedDays(dto: CreateLeaveDto): number {
    if (dto.is_half_day) {
      return 0.5;
    }

    const parts = this.expandDateRange(dto.start_date, dto.end_date);
    if (parts.length === 0) {
      throw new BadRequestException(
        'Đơn nghỉ phải chứa ít nhất một ngày làm việc',
      );
    }
    return parts.length;
  }

  private expandLeaveParts(leave: LeaveRequest): LeaveDurationPart[] {
    if (leave.is_half_day) {
      return [
        {
          leave_date: leave.start_date,
          duration_days: 0.5,
          half_day_part: leave.half_day_part,
        },
      ];
    }

    return this.expandDateRange(leave.start_date, leave.end_date).map(
      (date) => ({
        leave_date: date,
        duration_days: 1,
        half_day_part: null,
      }),
    );
  }

  private expandDateRange(startDate: string, endDate: string): string[] {
    const results: string[] = [];
    const cursor = new Date(`${startDate}T00:00:00.000Z`);
    const end = new Date(`${endDate}T00:00:00.000Z`);

    while (cursor <= end) {
      const day = cursor.getUTCDay();
      if (day !== 0 && day !== 6) {
        results.push(cursor.toISOString().substring(0, 10));
      }
      cursor.setUTCDate(cursor.getUTCDate() + 1);
    }

    return results;
  }

  private async applyPaidLeavePolicy(
    balanceRepo: Repository<YearlyLeaveBalance>,
    employee: User,
    leaveType: string,
    part: LeaveDurationPart,
  ): Promise<
    Array<{
      leave_date: string;
      duration_days: number;
      half_day_part: string | null;
      is_paid: boolean;
    }>
  > {
    if (leaveType !== 'annual' || employee.employment_status !== 'official') {
      return [
        {
          leave_date: part.leave_date,
          duration_days: part.duration_days,
          half_day_part: part.half_day_part,
          is_paid: false,
        },
      ];
    }

    const [year] = part.leave_date.split('-').map(Number);
    let balance = await balanceRepo.findOne({
      where: { user_id: employee.id, year },
    });

    if (!balance) {
      balance = balanceRepo.create({
        user_id: employee.id,
        year,
        allocated_days: 12,
        used_paid_days: 0,
      });
    }

    const remaining = Math.max(
      0,
      this.roundDays(
        Number(balance.allocated_days) - Number(balance.used_paid_days),
      ),
    );
    const paidDuration = Math.min(remaining, part.duration_days);
    const unpaidDuration = this.roundDays(part.duration_days - paidDuration);
    const rows: Array<{
      leave_date: string;
      duration_days: number;
      half_day_part: string | null;
      is_paid: boolean;
    }> = [];

    if (paidDuration > 0) {
      rows.push({
        leave_date: part.leave_date,
        duration_days: this.roundDays(paidDuration),
        half_day_part: part.half_day_part,
        is_paid: true,
      });
      balance.used_paid_days = this.roundDays(
        Number(balance.used_paid_days) + paidDuration,
      );
      await balanceRepo.save(balance);
    }

    if (unpaidDuration > 0) {
      rows.push({
        leave_date: part.leave_date,
        duration_days: unpaidDuration,
        half_day_part: paidDuration === 0 ? part.half_day_part : null,
        is_paid: false,
      });
    }

    return rows;
  }

  private roundDays(value: number): number {
    return Math.round(value * 10) / 10;
  }

  private async getOrCreateWfhBalance(
    balanceRepo: Repository<YearlyWfhBalance>,
    companyConfigRepo: Repository<CompanyWfhYearlyConfig>,
    userId: string,
    year: number,
  ): Promise<YearlyWfhBalance> {
    let balance = await balanceRepo.findOne({
      where: {
        user_id: userId,
        year,
      },
    });
    if (balance) {
      return balance;
    }

    const config = await companyConfigRepo.findOne({ where: { year } });
    if (!config) {
      throw new BadRequestException(
        `Admin chưa cấu hình quota WFH cho năm ${year}`,
      );
    }

    balance = balanceRepo.create({
      user_id: userId,
      year,
      allocated_days: this.roundDays(Number(config.allocated_days)),
      used_days: 0,
      is_override: false,
    });
    return balanceRepo.save(balance);
  }

  private toWfhBalanceSnapshot(balance: YearlyWfhBalance): WfhBalanceSnapshot {
    const allocatedDays = Number(balance.allocated_days);
    const usedDays = Number(balance.used_days);
    const remainingDays = Math.max(0, this.roundDays(allocatedDays - usedDays));

    return {
      year: balance.year,
      allocated_days: allocatedDays,
      used_days: usedDays,
      remaining_days: remainingDays,
      has_remaining_days: remainingDays > 0,
      is_override: balance.is_override,
    };
  }

  private calculateOtHours(
    startDate: string,
    endDate: string,
    startTime: string,
    endTime: string,
  ): number {
    const start = new Date(`${startDate}T${startTime}:00.000Z`);
    const end = new Date(`${endDate}T${endTime}:00.000Z`);
    const diffMinutes = (end.getTime() - start.getTime()) / (1000 * 60);
    return this.roundDays(diffMinutes / 60);
  }
}
