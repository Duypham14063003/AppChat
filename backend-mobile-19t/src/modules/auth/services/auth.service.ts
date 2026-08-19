import { randomUUID } from 'node:crypto';
import {
  Injectable,
  BadRequestException,
  ForbiddenException,
  NotFoundException,
  UnauthorizedException,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../entities/user.entity.js';
import { Role } from '../entities/role.entity.js';
import { UserRole } from '../entities/user-role.entity.js';
import { UserPointWallet } from '../../rewards/entities/user-point-wallet.entity.js';
import { OdooService } from './odoo.service.js';
import { TokenService, JwtPayload } from './token.service.js';
import { SessionService } from './session.service.js';
import { AuditLogService } from './audit-log.service.js';
import { UpdateProfileDto } from '../dto/auth.dto.js';

export interface AuthUserResponse {
  id: string;
  email: string;
  name: string;
  department: string | null;
  job_title: string | null;
  phone_number: string | null;
  employment_status: string | null;
  avatar_url: string | null;
  roles: string[];
  jobTitle: string | null;
  phoneNumber: string | null;
  employmentStatus: string | null;
  avatarUrl: string | null;
}

export interface LoginResult {
  accessToken: string;
  refreshToken: string;
  user: AuthUserResponse;
}

export interface InitialConfigResponse {
  phone_number: string | null;
  points: number;
  payroll_start_config?: number;
  roles?: string[];
}

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    @InjectRepository(User) private readonly userRepo: Repository<User>,
    @InjectRepository(Role) private readonly roleRepo: Repository<Role>,
    @InjectRepository(UserRole)
    private readonly userRoleRepo: Repository<UserRole>,
    @InjectRepository(UserPointWallet)
    private readonly walletRepo: Repository<UserPointWallet>,
    private readonly odooService: OdooService,
    private readonly tokenService: TokenService,
    private readonly sessionService: SessionService,
    private readonly auditLog: AuditLogService,
  ) {}

  async login(
    email: string,
    password: string,
    ip?: string,
    userAgent?: string,
    deviceId?: string,
    deviceName?: string,
  ): Promise<LoginResult> {
    // 1. Authenticate via Odoo
    const odooUser = await this.odooService.authenticate(email, password);

    // 2. Find or create user
    let user = await this.userRepo.findOne({
      where: { odoo_uid: odooUser.uid },
      relations: ['userRoles', 'userRoles.role'],
    });

    if (user && !user.is_active) {
      await this.auditLog.logAuthEvent({
        type: 'auth.login.failure',
        email,
        ip,
        userAgent,
        reason: 'Account deactivated',
      });
      throw new ForbiddenException('Tài khoản đã bị vô hiệu hóa');
    }

    let isNewUser = false;
    if (!user) {
      isNewUser = true;
      user = this.userRepo.create({
        odoo_uid: odooUser.uid,
        email: odooUser.email,
        name: odooUser.name,
        is_active: true,
      });
      user = await this.userRepo.save(user);

      // Assign default Employee role
      const employeeRole = await this.roleRepo.findOne({
        where: { name: 'employee' },
      });
      if (employeeRole) {
        await this.userRoleRepo.save({
          user_id: user.id,
          role_id: employeeRole.id,
        });
      }
    } else {
      // Update user info from Odoo
      await this.userRepo.update(user.id, {
        name: odooUser.name,
        email: odooUser.email,
        last_seen_at: new Date(),
      });
    }

    // Reload with roles
    user = await this.userRepo.findOne({
      where: { id: user.id },
      relations: ['userRoles', 'userRoles.role'],
    });

    const roles = user!.userRoles.map((ur) => ur.role.name);

    // 3. Generate tokens
    const sessionId = randomUUID();
    const payload: JwtPayload = {
      sub: user!.id,
      email: user!.email,
      roles,
      sessionId,
    };
    const accessToken = this.tokenService.generateAccessToken(payload);
    const rawRefreshToken = this.tokenService.generateRefreshToken();
    const refreshToken = `${sessionId}.${rawRefreshToken}`;
    const refreshTokenHash =
      await this.tokenService.hashRefreshToken(rawRefreshToken);

    // 4. Create session (replace existing session for same device)
    if (deviceId) {
      const existing = await this.sessionService.findSessionByUserAndDevice(
        user!.id,
        deviceId,
      );
      if (existing) await this.sessionService.deleteSession(existing.id);
    }

    await this.sessionService.createSession({
      id: sessionId,
      user_id: user!.id,
      device_id: deviceId,
      device_name: deviceName,
      refresh_token_hash: refreshTokenHash,
      last_ip: ip,
      expires_at: new Date(Date.now() + this.tokenService.getRefreshTtlMs()),
    });

    // 5. Audit log
    await this.auditLog.logAuthEvent({
      type: 'auth.login.success',
      userId: user!.id,
      email: user!.email,
      ip,
      userAgent,
      metadata: { isNewUser },
    });

    return {
      accessToken,
      refreshToken,
      user: this.buildAuthUserResponse(user!, roles),
    };
  }

  async refreshTokens(
    oldRefreshToken: string,
    ip?: string,
  ): Promise<{
    accessToken: string;
    refreshToken: string;
    user: AuthUserResponse;
  }> {
    let matchedSession:
      | import('../entities/user-session.entity.js').UserSession
      | null = null;

    // 1. Try O(1) lookup for new token format: <sessionId>.<rawToken>
    const [sessionId, rawToken] = oldRefreshToken.split('.');
    if (sessionId && rawToken) {
      const session = await this.sessionService.findSessionById(sessionId);
      if (session) {
        const isValid = await this.tokenService.verifyRefreshToken(
          rawToken,
          session.refresh_token_hash,
        );
        if (isValid) {
          matchedSession = session;
        }
      }
    } else {
      // 2. Fallback to O(N) lookup for old token format (Backward Compatibility)
      const allSessions = await this.sessionService.findAllActiveSessions();
      for (const session of allSessions) {
        const isValid = await this.tokenService.verifyRefreshToken(
          oldRefreshToken,
          session.refresh_token_hash,
        );
        if (isValid) {
          matchedSession = session;
          break;
        }
      }
    }

    if (!matchedSession) {
      throw new UnauthorizedException('Session expired, please login again');
    }

    // Check expiry
    if (matchedSession.expires_at < new Date()) {
      await this.sessionService.deleteSession(matchedSession.id);
      throw new UnauthorizedException('Session expired, please login again');
    }

    // Load user with roles
    const user = await this.userRepo.findOne({
      where: { id: matchedSession.user_id },
      relations: ['userRoles', 'userRoles.role'],
    });

    if (!user || !user.is_active) {
      await this.sessionService.deleteSession(matchedSession.id);
      throw new UnauthorizedException('Session expired, please login again');
    }

    const roles = user.userRoles.map((ur) => ur.role.name);

    // 3. Generate new Access Token (No Refresh Token Rotation)
    const payload: JwtPayload = {
      sub: user.id,
      email: user.email,
      roles,
      sessionId: matchedSession.id,
    };
    const accessToken = this.tokenService.generateAccessToken(payload);

    // Update session metadata
    await this.sessionService.updateSession(matchedSession.id, {
      last_used_at: new Date(),
      last_ip: ip,
    });

    return {
      accessToken,
      refreshToken: oldRefreshToken, // Reuse the same refresh token
      user: this.buildAuthUserResponse(user, roles),
    };
  }

  async logout(
    userId: string,
    refreshToken: string,
    ip?: string,
    userAgent?: string,
  ): Promise<void> {
    const sessions = await this.sessionService.findSessionsByUser(userId);
    for (const session of sessions) {
      const isMatch = await this.tokenService.verifyRefreshToken(
        refreshToken,
        session.refresh_token_hash,
      );
      if (isMatch) {
        await this.sessionService.deleteSession(session.id);
        break;
      }
    }

    await this.auditLog.logAuthEvent({
      type: 'auth.logout',
      userId,
      ip,
      userAgent,
    });
  }

  async logoutAll(
    userId: string,
    ip?: string,
    userAgent?: string,
  ): Promise<void> {
    await this.sessionService.deleteAllSessions(userId);
    await this.auditLog.logAuthEvent({
      type: 'auth.logout.all',
      userId,
      ip,
      userAgent,
    });
  }

  async deactivateUser(
    targetUserId: string,
    adminUserId: string,
    ip?: string,
  ): Promise<void> {
    await this.userRepo.update(targetUserId, { is_active: false });
    await this.sessionService.deleteAllSessions(targetUserId);
    await this.auditLog.logAuthEvent({
      type: 'auth.account.deactivated',
      userId: targetUserId,
      ip,
      metadata: { deactivatedBy: adminUserId },
    });
  }

  async listUsers(
    currentUserId: string,
    search?: string,
    cursor?: string,
    limit: number = 50,
  ): Promise<{
    users: Array<{
      id: string;
      name: string;
      email: string;
      department: string | null;
      jobTitle: string | null;
      phoneNumber: string | null;
      avatarUrl: string | null;
    }>;
    total: number;
    nextCursor: string | null;
    hasMore: boolean;
  }> {
    const qb = this.userRepo
      .createQueryBuilder('user')
      .select([
        'user.id',
        'user.name',
        'user.email',
        'user.department',
        'user.job_title',
        'user.phone_number',
        'user.avatar_url',
      ])
      .where('user.is_active = :active', { active: true })
      .andWhere('user.id != :currentUserId', { currentUserId })
      .orderBy('user.name', 'ASC')
      .addOrderBy('user.id', 'ASC');

    if (search) {
      qb.andWhere('(user.name ILIKE :search OR user.email ILIKE :search)', {
        search: `%${search}%`,
      });
    }

    if (cursor) {
      const cursorUser = await this.userRepo.findOne({
        where: { id: cursor },
        select: ['id', 'name'],
      });
      if (cursorUser) {
        qb.andWhere(
          '(user.name > :cursorName OR (user.name = :cursorName AND user.id > :cursorId))',
          { cursorName: cursorUser.name, cursorId: cursorUser.id },
        );
      }
    }

    const total = await qb.getCount();
    const users = await qb.take(limit + 1).getMany();
    const hasMore = users.length > limit;
    if (hasMore) users.pop();

    const nextCursor =
      hasMore && users.length > 0 ? users[users.length - 1].id : null;

    return {
      users: users.map((u) => ({
        id: u.id,
        name: u.name,
        email: u.email,
        department: u.department,
        jobTitle: u.job_title,
        phoneNumber: u.phone_number,
        avatarUrl: u.avatar_url,
      })),
      total,
      nextCursor,
      hasMore,
    };
  }

  async updateProfile(
    userId: string,
    dto: UpdateProfileDto,
  ): Promise<{
    id: string;
    email: string;
    name: string;
    department: string | null;
    job_title: string | null;
    phone_number: string | null;
    employment_status: string | null;
    avatar_url: string | null;
    roles: string[];
    jobTitle: string | null;
    phoneNumber: string | null;
    employmentStatus: string | null;
    avatarUrl: string | null;
  }> {
    const updates: Partial<User> = {};

    if (dto.name !== undefined) {
      const trimmedName = dto.name.trim();
      if (!trimmedName) {
        throw new BadRequestException('Tên không được để trống');
      }
      updates.name = trimmedName;
    }

    if (dto.avatar_url !== undefined) {
      updates.avatar_url = dto.avatar_url?.trim() || null;
    }

    if (dto.phone_number !== undefined) {
      updates.phone_number = dto.phone_number?.trim() || null;
    }

    if (Object.keys(updates).length === 0) {
      throw new BadRequestException('Không có thông tin nào để cập nhật');
    }

    await this.userRepo.update(userId, updates);

    const user = await this.getActiveUserWithRolesOrThrow(userId);

    return this.buildAuthUserResponse(user, this.getRoleNames(user));
  }

  async getInitialConfig(userId: string): Promise<InitialConfigResponse> {
    const user = await this.getActiveUserWithRolesOrThrow(userId);
    const wallet = await this.walletRepo.findOne({
      where: { user_id: userId },
      select: ['balance'],
    });

    return {
      phone_number: user.phone_number ?? null,
      points: Number(wallet?.balance ?? 0),
      payroll_start_config: 25,
      roles: user.job_title ? [user.job_title] : this.getRoleNames(user),
    };
  }

  async syncUsersFromOdoo(): Promise<{
    created: number;
    updated: number;
    deactivated: number;
  }> {
    const employees = await this.odooService.fetchEmployees();
    if (employees.length === 0) {
      this.logger.warn('No employees fetched from Odoo, skipping sync');
      return { created: 0, updated: 0, deactivated: 0 };
    }

    let created = 0;
    let updated = 0;
    const syncedOdooUids: number[] = [];

    const employeeRole = await this.roleRepo.findOne({
      where: { name: 'employee' },
    });

    for (const emp of employees) {
      if (!emp.work_email) continue; // skip employees without email

      const odooUid = emp.user_id ? emp.user_id[0] : emp.id;
      const odooEmployeeId = emp.id;
      syncedOdooUids.push(odooUid);

      const department = emp.department_id ? emp.department_id[1] : null;
      const jobTitle = emp.job_title || null;
      const phoneNumber = emp.work_phone || null;

      const existing = await this.userRepo.findOne({
        where: { odoo_uid: odooUid },
      });
      if (existing) {
        await this.userRepo.update(existing.id, {
          name: emp.name,
          email: emp.work_email,
          odoo_employee_id: odooEmployeeId,
          department,
          job_title: jobTitle,
          phone_number: phoneNumber,
          is_active: true,
        });
        updated++;
      } else {
        const user = this.userRepo.create({
          odoo_uid: odooUid,
          odoo_employee_id: odooEmployeeId,
          email: emp.work_email,
          name: emp.name,
          department,
          job_title: jobTitle,
          phone_number: phoneNumber,
          is_active: true,
        });
        const saved = await this.userRepo.save(user);
        if (employeeRole) {
          await this.userRoleRepo.save({
            user_id: saved.id,
            role_id: employeeRole.id,
          });
        }
        created++;
      }
    }

    // Deactivate users not in Odoo
    let deactivated = 0;
    if (syncedOdooUids.length > 0) {
      const result = await this.userRepo
        .createQueryBuilder()
        .update(User)
        .set({ is_active: false })
        .where('odoo_uid IS NOT NULL')
        .andWhere('is_active = true')
        .andWhere('is_bot = false')
        .andWhere('odoo_uid NOT IN (:...uids)', { uids: syncedOdooUids })
        .execute();
      deactivated = result.affected ?? 0;
    }

    this.logger.log(
      `Odoo sync: ${created} created, ${updated} updated, ${deactivated} deactivated`,
    );
    return { created, updated, deactivated };
  }

  private buildAuthUserResponse(
    user: Pick<
      User,
      | 'id'
      | 'email'
      | 'name'
      | 'department'
      | 'job_title'
      | 'phone_number'
      | 'employment_status'
      | 'avatar_url'
    >,
    roles: string[],
  ): AuthUserResponse {
    const department = user.department ?? null;
    const jobTitle = user.job_title ?? null;
    const phoneNumber = user.phone_number ?? null;
    const employmentStatus = user.employment_status ?? null;
    const avatarUrl = user.avatar_url ?? null;

    return {
      id: user.id,
      email: user.email,
      name: user.name,
      department,
      job_title: jobTitle,
      phone_number: phoneNumber,
      employment_status: employmentStatus,
      avatar_url: avatarUrl,
      roles,
      jobTitle,
      phoneNumber,
      employmentStatus,
      avatarUrl,
    };
  }

  private getRoleNames(user: Pick<User, 'userRoles'>): string[] {
    return (user.userRoles ?? []).map((userRole) => userRole.role.name);
  }

  private async getActiveUserWithRolesOrThrow(
    userId: string,
  ): Promise<User & { userRoles: UserRole[] }> {
    const user = await this.userRepo.findOne({
      where: { id: userId, is_active: true },
      relations: ['userRoles', 'userRoles.role'],
    });

    if (!user) {
      throw new NotFoundException('Người dùng không tồn tại');
    }

    return user as User & { userRoles: UserRole[] };
  }
}
