import {
  Injectable,
  BadRequestException,
  ForbiddenException,
  NotFoundException,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { LeaveRequest } from '../entities/leave-request.entity.js';
import { User } from '../../auth/entities/user.entity.js';
import { UserRole } from '../../auth/entities/user-role.entity.js';
import { Role } from '../../auth/entities/role.entity.js';
import { CreateLeaveDto } from '../dto/hr.dto.js';
import { FirebaseService } from '../../notification/services/firebase.service.js';
import { UserSession } from '../../auth/entities/user-session.entity.js';
import { canApproveLeaveRoles } from '../hr-role.utils.js';

@Injectable()
export class LeaveService {
  private readonly logger = new Logger(LeaveService.name);

  constructor(
    @InjectRepository(LeaveRequest)
    private readonly leaveRepo: Repository<LeaveRequest>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    @InjectRepository(UserRole)
    private readonly userRoleRepo: Repository<UserRole>,
    @InjectRepository(Role)
    private readonly roleRepo: Repository<Role>,
    @InjectRepository(UserSession)
    private readonly sessionRepo: Repository<UserSession>,
    private readonly firebaseService: FirebaseService,
  ) {}

  async create(userId: string, dto: CreateLeaveDto): Promise<LeaveRequest> {
    if (new Date(dto.end_date) < new Date(dto.start_date)) {
      throw new BadRequestException('Ngày kết thúc phải sau ngày bắt đầu');
    }
    if (dto.type === 'ot') {
      if (!dto.start_time || !dto.end_time) {
        throw new BadRequestException(
          'Đơn OT cần có giờ bắt đầu và giờ kết thúc',
        );
      }
      if (dto.end_time <= dto.start_time) {
        throw new BadRequestException(
          'Giờ kết thúc phải sau giờ bắt đầu',
        );
      }
    }
    const record = this.leaveRepo.create({
      user_id: userId,
      type: dto.type,
      start_date: dto.start_date,
      end_date: dto.end_date,
      start_time: dto.start_time ?? null,
      end_time: dto.end_time ?? null,
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
      { annual: 'phép năm', sick: 'nghỉ ốm', personal: 'việc riêng', ot: 'OT' }[
        leave.type
      ] || leave.type;
    const timeRange =
      leave.type === 'ot' && leave.start_time && leave.end_time
        ? ` (${leave.start_time} - ${leave.end_time})`
        : '';
    await this.notifyApprovers(
      `${employee?.name || 'Nhân viên'} xin ${typeLabel}`,
      `Từ ${leave.start_date} đến ${leave.end_date}${timeRange}`,
      { type: 'hr_leave_request', leave_id: leaveId },
    );

    return saved;
  }

  async approve(adminUserId: string, leaveId: string): Promise<LeaveRequest> {
    const leave = await this.leaveRepo.findOne({ where: { id: leaveId } });
    if (!leave) throw new NotFoundException('Đơn nghỉ không tồn tại');
    if (leave.status !== 'submitted')
      throw new BadRequestException('Chỉ có thể duyệt đơn đã gửi');

    leave.status = 'approved';
    leave.approved_by = adminUserId;
    leave.approved_at = new Date();
    leave.odoo_synced = false;
    const saved = await this.leaveRepo.save(leave);

    const admin = await this.userRepo.findOne({ where: { id: adminUserId } });
    const approvedTimeRange =
      leave.type === 'ot' && leave.start_time && leave.end_time
        ? ` (${leave.start_time} - ${leave.end_time})`
        : '';
    await this.notifyUser(
      leave.user_id,
      `${admin?.name || 'Quản lý'} đã duyệt đơn nghỉ của bạn`,
      `Từ ${leave.start_date} đến ${leave.end_date}${approvedTimeRange}`,
      { type: 'hr_leave_approved', leave_id: leaveId },
    );

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

    return saved;
  }

  async getLeaves(
    userId: string,
    status?: string,
    targetUserId?: string,
    roles?: string[],
  ): Promise<LeaveRequest[]> {
    const canApprove = canApproveLeaveRoles(roles);
    const qb = this.leaveRepo
      .createQueryBuilder('l')
      .leftJoin('l.requester', 'requester')
      .leftJoin('l.approver', 'approver')
      .addSelect(['requester.name', 'approver.name'])
      .orderBy('l.created_at', 'DESC');

    if (targetUserId && canApprove) {
      qb.where('l.user_id = :uid', { uid: targetUserId });
    } else if (canApprove && !targetUserId) {
      // Admin/manager sees all
    } else {
      qb.where('l.user_id = :uid', { uid: userId });
    }

    if (status) qb.andWhere('l.status = :status', { status });

    return qb.getMany();
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
      await this.firebaseService.sendPush(s.fcm_token, title, body, data);
    }
  }
}
