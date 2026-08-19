import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { AuthService } from './auth.service';
import { User } from '../entities/user.entity';
import { Role } from '../entities/role.entity';
import { UserRole } from '../entities/user-role.entity';
import { UserPointWallet } from '../../rewards/entities/user-point-wallet.entity';
import { OdooService } from './odoo.service';
import { TokenService } from './token.service';
import { SessionService } from './session.service';
import { AuditLogService } from './audit-log.service';

function createRepoMock() {
  return {
    findOne: jest.fn(),
    save: jest.fn(),
    create: jest.fn((value: Record<string, unknown>) => ({ ...value })),
    update: jest.fn(),
    createQueryBuilder: jest.fn(),
  };
}

describe('AuthService', () => {
  let service: AuthService;
  const userRepo = createRepoMock();
  const roleRepo = createRepoMock();
  const userRoleRepo = createRepoMock();
  const walletRepo = createRepoMock();
  const odooService = {
    authenticate: jest.fn(),
    fetchEmployees: jest.fn(),
  };
  const tokenService = {
    generateAccessToken: jest.fn(),
    generateRefreshToken: jest.fn(),
    hashRefreshToken: jest.fn(),
    verifyRefreshToken: jest.fn(),
    getRefreshTtlMs: jest.fn(),
  };
  const sessionService = {
    findSessionByUserAndDevice: jest.fn(),
    createSession: jest.fn(),
    findAllActiveSessions: jest.fn(),
    updateSession: jest.fn(),
    deleteSession: jest.fn(),
    findSessionsByUser: jest.fn(),
    deleteAllSessions: jest.fn(),
  };
  const auditLog = {
    logAuthEvent: jest.fn(),
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    tokenService.generateAccessToken.mockReturnValue('access-token');
    tokenService.generateRefreshToken.mockReturnValue('refresh-token');
    tokenService.hashRefreshToken.mockResolvedValue('refresh-hash');
    tokenService.getRefreshTtlMs.mockReturnValue(86_400_000);

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: getRepositoryToken(User), useValue: userRepo },
        { provide: getRepositoryToken(Role), useValue: roleRepo },
        { provide: getRepositoryToken(UserRole), useValue: userRoleRepo },
        { provide: getRepositoryToken(UserPointWallet), useValue: walletRepo },
        { provide: OdooService, useValue: odooService },
        { provide: TokenService, useValue: tokenService },
        { provide: SessionService, useValue: sessionService },
        { provide: AuditLogService, useValue: auditLog },
      ],
    }).compile();

    service = module.get(AuthService);
  });

  it('returns a mobile-ready user object from login', async () => {
    const existingUser = {
      id: 'user-1',
      email: 'user@example.com',
      name: 'Huynh Thi Minh Anh',
      department: 'QC',
      job_title: 'QC',
      phone_number: '0901234567',
      employment_status: 'official',
      avatar_url: '/uploads/avatars/abc.jpg',
      is_active: true,
      userRoles: [{ role: { name: 'employee' } }],
    };

    odooService.authenticate.mockResolvedValue({
      uid: 101,
      email: 'user@example.com',
      name: 'Huynh Thi Minh Anh',
    });
    userRepo.findOne
      .mockResolvedValueOnce(existingUser)
      .mockResolvedValueOnce(existingUser);
    sessionService.findSessionByUserAndDevice.mockResolvedValue(null);

    const result = await service.login(
      'user@example.com',
      'secret',
      '127.0.0.1',
      'ios',
      'device-1',
      'iPhone',
    );

    expect(result.user).toEqual(
      expect.objectContaining({
        id: 'user-1',
        email: 'user@example.com',
        name: 'Huynh Thi Minh Anh',
        department: 'QC',
        job_title: 'QC',
        phone_number: '0901234567',
        employment_status: 'official',
        avatar_url: '/uploads/avatars/abc.jpg',
        roles: ['employee'],
      }),
    );
  });

  it('returns a mobile-ready user object from refresh', async () => {
    const user = {
      id: 'user-1',
      email: 'user@example.com',
      name: 'Huynh Thi Minh Anh',
      department: 'QC',
      job_title: 'QC',
      phone_number: '0901234567',
      employment_status: 'official',
      avatar_url: '/uploads/avatars/abc.jpg',
      is_active: true,
      userRoles: [{ role: { name: 'employee' } }],
    };

    sessionService.findAllActiveSessions.mockResolvedValue([
      {
        id: 'session-1',
        user_id: 'user-1',
        refresh_token_hash: 'refresh-hash',
        expires_at: new Date(Date.now() + 60_000),
      },
    ]);
    tokenService.verifyRefreshToken.mockResolvedValue(true);
    userRepo.findOne.mockResolvedValue(user);

    const result = await service.refreshTokens('refresh-token', '127.0.0.1');

    expect(result.user).toEqual(
      expect.objectContaining({
        id: 'user-1',
        email: 'user@example.com',
        name: 'Huynh Thi Minh Anh',
        department: 'QC',
        job_title: 'QC',
        phone_number: '0901234567',
        employment_status: 'official',
        avatar_url: '/uploads/avatars/abc.jpg',
        roles: ['employee'],
      }),
    );
  });

  it('returns a full user object with roles after profile updates', async () => {
    userRepo.findOne.mockResolvedValue({
      id: 'user-1',
      email: 'user@example.com',
      name: 'Huynh Thi Minh Anh',
      department: 'QC',
      job_title: 'QC',
      phone_number: '0901234567',
      employment_status: 'official',
      avatar_url: '/uploads/avatars/abc.jpg',
      userRoles: [{ role: { name: 'employee' } }],
    });

    const result = await service.updateProfile('user-1', {
      name: '  Huynh Thi Minh Anh  ',
    });

    expect(userRepo.update).toHaveBeenCalledWith('user-1', {
      name: 'Huynh Thi Minh Anh',
    });
    expect(result).toEqual(
      expect.objectContaining({
        id: 'user-1',
        email: 'user@example.com',
        name: 'Huynh Thi Minh Anh',
        department: 'QC',
        job_title: 'QC',
        phone_number: '0901234567',
        employment_status: 'official',
        avatar_url: '/uploads/avatars/abc.jpg',
        roles: ['employee'],
      }),
    );
  });

  it('returns initial config from the current user profile', async () => {
    userRepo.findOne.mockResolvedValue({
      id: 'user-1',
      email: 'user@example.com',
      name: 'Huynh Thi Minh Anh',
      department: 'QC',
      job_title: 'QC',
      phone_number: '0901234567',
      employment_status: 'official',
      avatar_url: '/uploads/avatars/abc.jpg',
      is_active: true,
      userRoles: [{ role: { name: 'employee' } }],
    });
    walletRepo.findOne.mockResolvedValue({ balance: 125 });

    const result = await service.getInitialConfig('user-1');

    expect(result).toEqual({
      phone_number: '0901234567',
      points: 125,
    });
  });
});
