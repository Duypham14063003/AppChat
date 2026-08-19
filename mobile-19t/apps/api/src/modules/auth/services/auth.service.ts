import {
  Injectable,
  ForbiddenException,
  UnauthorizedException,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../entities/user.entity.js';
import { Role } from '../entities/role.entity.js';
import { UserRole } from '../entities/user-role.entity.js';
import { OdooService, OdooEmployee } from './odoo.service.js';
import { TokenService, JwtPayload } from './token.service.js';
import { SessionService } from './session.service.js';
import { AuditLogService } from './audit-log.service.js';

export interface LoginResult {
  accessToken: string;
  refreshToken: string;
  user: {
    id: string;
    email: string;
    name: string;
    department: string | null;
    jobTitle: string | null;
    avatarUrl: string | null;
    roles: string[];
  };
}

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    @InjectRepository(User) private readonly userRepo: Repository<User>,
    @InjectRepository(Role) private readonly roleRepo: Repository<Role>,
    @InjectRepository(UserRole)
    private readonly userRoleRepo: Repository<UserRole>,
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
      this.auditLog.logAuthEvent({
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
    const payload: JwtPayload = { sub: user!.id, email: user!.email, roles };
    const accessToken = this.tokenService.generateAccessToken(payload);
    const refreshToken = this.tokenService.generateRefreshToken();
    const refreshTokenHash =
      await this.tokenService.hashRefreshToken(refreshToken);

    // 4. Create session (replace existing session for same device)
    if (deviceId) {
      const existing = await this.sessionService.findSessionByUserAndDevice(
        user!.id,
        deviceId,
      );
      if (existing) await this.sessionService.deleteSession(existing.id);
    }

    await this.sessionService.createSession({
      user_id: user!.id,
      device_id: deviceId,
      device_name: deviceName,
      refresh_token_hash: refreshTokenHash,
      last_ip: ip,
      expires_at: new Date(Date.now() + this.tokenService.getRefreshTtlMs()),
    });

    // 5. Audit log
    this.auditLog.logAuthEvent({
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
      user: {
        id: user!.id,
        email: user!.email,
        name: user!.name,
        department: user!.department,
        jobTitle: user!.job_title,
        avatarUrl: user!.avatar_url,
        roles,
      },
    };
  }

  async refreshTokens(
    oldRefreshToken: string,
    ip?: string,
  ): Promise<{ accessToken: string; refreshToken: string }> {
    // Find session by checking all active sessions
    const allSessions = await this.sessionService.findAllActiveSessions();

    let matchedSession:
      | import('../entities/user-session.entity.js').UserSession
      | null = null;
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

    if (!matchedSession) {
      // Token theft detection: check if this token was previously valid
      // If no session matches, it could be a reused/stolen token
      // We can't easily detect which user it belongs to without storing old hashes
      // So we just reject
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

    // Rotate: generate new tokens
    const payload: JwtPayload = { sub: user.id, email: user.email, roles };
    const accessToken = this.tokenService.generateAccessToken(payload);
    const newRefreshToken = this.tokenService.generateRefreshToken();
    const newHash = await this.tokenService.hashRefreshToken(newRefreshToken);

    // Update session with new token hash
    await this.sessionService.updateSession(matchedSession.id, {
      refresh_token_hash: newHash,
      last_used_at: new Date(),
      last_ip: ip,
      expires_at: new Date(Date.now() + this.tokenService.getRefreshTtlMs()),
    });

    return { accessToken, refreshToken: newRefreshToken };
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

    this.auditLog.logAuthEvent({
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
    this.auditLog.logAuthEvent({
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
    this.auditLog.logAuthEvent({
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
        avatarUrl: u.avatar_url,
      })),
      total,
      nextCursor,
      hasMore,
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
      syncedOdooUids.push(odooUid);

      const department = emp.department_id ? emp.department_id[1] : null;
      const jobTitle = emp.job_title || null;

      const existing = await this.userRepo.findOne({
        where: { odoo_uid: odooUid },
      });
      if (existing) {
        await this.userRepo.update(existing.id, {
          name: emp.name,
          email: emp.work_email,
          department,
          job_title: jobTitle,
          is_active: true,
        });
        updated++;
      } else {
        const user = this.userRepo.create({
          odoo_uid: odooUid,
          email: emp.work_email,
          name: emp.name,
          department,
          job_title: jobTitle,
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
        .andWhere('odoo_uid NOT IN (:...uids)', { uids: syncedOdooUids })
        .execute();
      deactivated = result.affected ?? 0;
    }

    this.logger.log(
      `Odoo sync: ${created} created, ${updated} updated, ${deactivated} deactivated`,
    );
    return { created, updated, deactivated };
  }
}
