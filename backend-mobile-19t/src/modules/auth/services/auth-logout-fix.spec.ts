import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { AuthService } from './auth.service.js';
import { User } from '../entities/user.entity.js';
import { Role } from '../entities/role.entity.js';
import { UserRole } from '../entities/user-role.entity.js';
import { UserPointWallet } from '../../rewards/entities/user-point-wallet.entity.js';
import { OdooService } from './odoo.service.js';
import { TokenService } from './token.service.js';
import { SessionService } from './session.service.js';
import { AuditLogService } from './audit-log.service.js';
import { UnauthorizedException } from '@nestjs/common';

// Mock node:crypto
jest.mock('node:crypto', () => ({
  randomUUID: () => 'fixed-session-id',
}));

function createRepoMock() {
  return {
    findOne: jest.fn(),
    save: jest.fn(),
    create: jest.fn((value: Record<string, unknown>) => ({ ...value })),
    update: jest.fn(),
  };
}

describe('AuthService Logout Fix', () => {
  let service: AuthService;
  const userRepo = createRepoMock();
  const roleRepo = createRepoMock();
  const userRoleRepo = createRepoMock();
  const walletRepo = createRepoMock();
  const odooService = { authenticate: jest.fn() };
  const tokenService = {
    generateAccessToken: jest.fn(),
    generateRefreshToken: jest.fn(),
    hashRefreshToken: jest.fn(),
    verifyRefreshToken: jest.fn(),
    getRefreshTtlMs: jest.fn(),
  };
  const sessionService = {
    findSessionById: jest.fn(),
    findSessionByUserAndDevice: jest.fn(),
    createSession: jest.fn(),
    findAllActiveSessions: jest.fn(),
    updateSession: jest.fn(),
    deleteSession: jest.fn(),
  };
  const auditLog = { logAuthEvent: jest.fn() };

  beforeEach(async () => {
    jest.clearAllMocks();
    tokenService.generateAccessToken.mockReturnValue('new-access-token');
    tokenService.generateRefreshToken.mockReturnValue('raw-refresh-token');
    tokenService.hashRefreshToken.mockResolvedValue('hashed-raw-token');
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

  describe('login', () => {
    it('should generate a structured refresh token <sessionId>.<rawToken>', async () => {
      odooService.authenticate.mockResolvedValue({ uid: 1, email: 't@t.com', name: 'T' });
      userRepo.findOne.mockResolvedValue({ id: 'u1', email: 't@t.com', is_active: true, userRoles: [] });
      
      const result = await service.login('t@t.com', 'p');

      expect(result.refreshToken).toBe('fixed-session-id.raw-refresh-token');
      expect(sessionService.createSession).toHaveBeenCalledWith(expect.objectContaining({
        id: 'fixed-session-id',
        refresh_token_hash: 'hashed-raw-token'
      }));
    });
  });

  describe('refreshTokens', () => {
    const mockUser = { id: 'u1', email: 't@t.com', is_active: true, userRoles: [] };
    const mockSession = { 
        id: 'fixed-session-id', 
        user_id: 'u1', 
        refresh_token_hash: 'hashed-raw-token',
        expires_at: new Date(Date.now() + 10000)
    };

    it('should use O(1) lookup when sessionId is present in token', async () => {
      sessionService.findSessionById.mockResolvedValue(mockSession);
      tokenService.verifyRefreshToken.mockResolvedValue(true);
      userRepo.findOne.mockResolvedValue(mockUser);

      const result = await service.refreshTokens('fixed-session-id.raw-refresh-token');

      expect(sessionService.findSessionById).toHaveBeenCalledWith('fixed-session-id');
      expect(sessionService.findAllActiveSessions).not.toHaveBeenCalled(); // Proof of O(1)
      expect(result.refreshToken).toBe('fixed-session-id.raw-refresh-token'); // No rotation
    });

    it('should fall back to O(N) lookup for old token format', async () => {
      sessionService.findAllActiveSessions.mockResolvedValue([mockSession]);
      tokenService.verifyRefreshToken.mockResolvedValue(true);
      userRepo.findOne.mockResolvedValue(mockUser);

      const result = await service.refreshTokens('old-style-token');

      expect(sessionService.findSessionById).not.toHaveBeenCalled();
      expect(sessionService.findAllActiveSessions).toHaveBeenCalled(); // Fallback to O(N)
      expect(result.refreshToken).toBe('old-style-token'); // No rotation
    });

    it('should throw Unauthorized if O(1) lookup fails', async () => {
      sessionService.findSessionById.mockResolvedValue(null);
      
      await expect(service.refreshTokens('sid.raw')).rejects.toThrow(UnauthorizedException);
    });
  });
});
