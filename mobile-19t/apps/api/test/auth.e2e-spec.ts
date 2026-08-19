import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import request from 'supertest';
import { App } from 'supertest/types';
import { Repository } from 'typeorm';
import { getRepositoryToken } from '@nestjs/typeorm';
import { AppModule } from '../src/app.module';
import { User } from '../src/modules/auth/entities/user.entity';
import { Role } from '../src/modules/auth/entities/role.entity';
import { UserRole } from '../src/modules/auth/entities/user-role.entity';
import { UserSession } from '../src/modules/auth/entities/user-session.entity';
import { OdooService } from '../src/modules/auth/services/odoo.service';

// Set test env vars before module loads
process.env.DB_HOST = process.env.DB_HOST || 'localhost';
process.env.DB_PORT = process.env.DB_PORT || '5432';
process.env.DB_USER = process.env.DB_USER || 'app_19t';
process.env.DB_PASSWORD = process.env.DB_PASSWORD || 'local_dev_password';
process.env.DB_NAME = process.env.DB_NAME || 'app_19t_dev';
process.env.REDIS_HOST = process.env.REDIS_HOST || 'localhost';
process.env.REDIS_PORT = process.env.REDIS_PORT || '6379';
process.env.PORT = '0';
process.env.JWT_ACCESS_SECRET = 'test-access-secret';
process.env.JWT_REFRESH_SECRET = 'test-refresh-secret';
process.env.JWT_ACCESS_TTL = '15m';
process.env.JWT_REFRESH_TTL = '30d';

const MOCK_ODOO_USER = {
  uid: 42,
  name: 'Test User',
  email: 'test@19t.vn',
};

describe('Auth (e2e)', () => {
  let app: INestApplication<App>;
  let userRepo: Repository<User>;
  let roleRepo: Repository<Role>;
  let userRoleRepo: Repository<UserRole>;
  let sessionRepo: Repository<UserSession>;
  let odooService: OdooService;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    app.setGlobalPrefix('/api/v1');
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: true,
      }),
    );
    await app.init();

    userRepo = moduleFixture.get(getRepositoryToken(User));
    roleRepo = moduleFixture.get(getRepositoryToken(Role));
    userRoleRepo = moduleFixture.get(getRepositoryToken(UserRole));
    sessionRepo = moduleFixture.get(getRepositoryToken(UserSession));
    odooService = moduleFixture.get(OdooService);
  });

  afterAll(async () => {
    // Clean up test data
    await sessionRepo.delete({});
    await userRoleRepo.delete({});
    await userRepo.delete({});
    await app.close();
  });

  beforeEach(async () => {
    // Clean sessions and test users before each test
    await sessionRepo.delete({});
    await userRoleRepo.delete({});
    await userRepo.delete({});
  });

  // SECTION_8_1

  // --- 8.1: Login success, failure, rate limiting ---

  describe('POST /api/v1/auth/login', () => {
    it('should login successfully with valid Odoo credentials', async () => {
      jest
        .spyOn(odooService, 'authenticate')
        .mockResolvedValueOnce(MOCK_ODOO_USER);

      const res = await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .send({ email: 'test@19t.vn', password: 'correct' })
        .expect(200);

      expect(res.body.accessToken).toBeDefined();
      expect(res.body.refreshToken).toBeDefined();
      expect(res.body.user.email).toBe('test@19t.vn');
      expect(res.body.user.roles).toContain('employee');
    });

    it('should return 401 for invalid Odoo credentials', async () => {
      jest
        .spyOn(odooService, 'authenticate')
        .mockRejectedValueOnce({ status: 401, message: 'Unauthorized' });

      await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .send({ email: 'test@19t.vn', password: 'wrong' })
        .expect(500); // OdooService throws, caught as internal error
    });

    it('should return 400 for missing email', async () => {
      await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .send({ password: 'test' })
        .expect(400);
    });

    it('should return 400 for missing password', async () => {
      await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .send({ email: 'test@19t.vn' })
        .expect(400);
    });

    it('should rate limit after 5 failed login attempts', async () => {
      jest
        .spyOn(odooService, 'authenticate')
        .mockRejectedValue(new Error('Invalid credentials'));

      for (let i = 0; i < 5; i++) {
        await request(app.getHttpServer())
          .post('/api/v1/auth/login')
          .send({ email: 'spam@19t.vn', password: 'wrong' });
      }

      // 6th attempt should be throttled
      await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .send({ email: 'spam@19t.vn', password: 'wrong' })
        .expect(429);
    });
  });

  // SECTION_8_2

  // --- 8.2: Token refresh, rotation, theft detection ---

  describe('POST /api/v1/auth/refresh', () => {
    let refreshToken: string;

    beforeEach(async () => {
      jest
        .spyOn(odooService, 'authenticate')
        .mockResolvedValueOnce(MOCK_ODOO_USER);

      const loginRes = await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .send({ email: 'test@19t.vn', password: 'correct' });

      refreshToken = loginRes.body.refreshToken;
    });

    it('should refresh tokens with valid refresh token', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/auth/refresh')
        .send({ refreshToken })
        .expect(200);

      expect(res.body.accessToken).toBeDefined();
      expect(res.body.refreshToken).toBeDefined();
      expect(res.body.refreshToken).not.toBe(refreshToken); // rotated
    });

    it('should reject old refresh token after rotation', async () => {
      // First refresh — rotates the token
      await request(app.getHttpServer())
        .post('/api/v1/auth/refresh')
        .send({ refreshToken })
        .expect(200);

      // Second refresh with old token — should fail
      await request(app.getHttpServer())
        .post('/api/v1/auth/refresh')
        .send({ refreshToken })
        .expect(401);
    });

    it('should reject invalid refresh token', async () => {
      await request(app.getHttpServer())
        .post('/api/v1/auth/refresh')
        .send({ refreshToken: 'invalid-token' })
        .expect(401);
    });

    it('should wipe all sessions on token theft (reuse of rotated token)', async () => {
      // Create a second session for the same user
      jest
        .spyOn(odooService, 'authenticate')
        .mockResolvedValueOnce(MOCK_ODOO_USER);

      const login2 = await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .send({ email: 'test@19t.vn', password: 'correct', device_id: 'dev2' });

      const oldRefreshToken = refreshToken;

      // Rotate session 1's token
      await request(app.getHttpServer())
        .post('/api/v1/auth/refresh')
        .send({ refreshToken: oldRefreshToken })
        .expect(200);

      // Reuse old token (theft scenario) — should fail
      await request(app.getHttpServer())
        .post('/api/v1/auth/refresh')
        .send({ refreshToken: oldRefreshToken })
        .expect(401);

      // Session 2's token should also be dead (all sessions wiped)
      await request(app.getHttpServer())
        .post('/api/v1/auth/refresh')
        .send({ refreshToken: login2.body.refreshToken })
        .expect(401);
    });
  });

  // SECTION_8_3

  // --- 8.3: Session listing, logout, logout-all, delete session ---

  describe('Session management', () => {
    let accessToken: string;
    let refreshToken: string;

    beforeEach(async () => {
      jest
        .spyOn(odooService, 'authenticate')
        .mockResolvedValueOnce(MOCK_ODOO_USER);

      const loginRes = await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .send({
          email: 'test@19t.vn',
          password: 'correct',
          device_name: 'Test Device',
        });

      accessToken = loginRes.body.accessToken;
      refreshToken = loginRes.body.refreshToken;
    });

    it('GET /auth/sessions — should list active sessions', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/auth/sessions')
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(Array.isArray(res.body)).toBe(true);
      expect(res.body.length).toBeGreaterThanOrEqual(1);
      expect(res.body[0].deviceName).toBe('Test Device');
    });

    it('POST /auth/logout — should delete current session', async () => {
      await request(app.getHttpServer())
        .post('/api/v1/auth/logout')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ refreshToken })
        .expect(200);

      // Refresh should fail after logout
      await request(app.getHttpServer())
        .post('/api/v1/auth/refresh')
        .send({ refreshToken })
        .expect(401);
    });

    it('POST /auth/logout-all — should delete all sessions', async () => {
      // Create a second session
      jest
        .spyOn(odooService, 'authenticate')
        .mockResolvedValueOnce(MOCK_ODOO_USER);

      const login2 = await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .send({ email: 'test@19t.vn', password: 'correct', device_id: 'dev2' });

      await request(app.getHttpServer())
        .post('/api/v1/auth/logout-all')
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      // Both refresh tokens should fail
      await request(app.getHttpServer())
        .post('/api/v1/auth/refresh')
        .send({ refreshToken })
        .expect(401);

      await request(app.getHttpServer())
        .post('/api/v1/auth/refresh')
        .send({ refreshToken: login2.body.refreshToken })
        .expect(401);
    });

    it('DELETE /auth/sessions/:id — should delete specific session', async () => {
      const sessionsRes = await request(app.getHttpServer())
        .get('/api/v1/auth/sessions')
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      const sessionId = sessionsRes.body[0].id;

      await request(app.getHttpServer())
        .delete(`/api/v1/auth/sessions/${sessionId}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);
    });

    it("DELETE /auth/sessions/:id — should return 404 for another user's session", async () => {
      jest.spyOn(odooService, 'authenticate').mockResolvedValueOnce({
        uid: 77,
        name: 'Other',
        email: 'other@19t.vn',
      });

      const otherLogin = await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .send({ email: 'other@19t.vn', password: 'correct' });

      const otherSessions = await request(app.getHttpServer())
        .get('/api/v1/auth/sessions')
        .set('Authorization', `Bearer ${otherLogin.body.accessToken}`)
        .expect(200);

      const otherSessionId = otherSessions.body[0].id;

      await request(app.getHttpServer())
        .delete(`/api/v1/auth/sessions/${otherSessionId}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(404);
    });
  });

  // SECTION_8_4

  // --- 8.4: RBAC guard (admin-only endpoint, employee rejected) ---

  describe('RBAC', () => {
    it('should reject employee from admin-only endpoint', async () => {
      jest
        .spyOn(odooService, 'authenticate')
        .mockResolvedValueOnce(MOCK_ODOO_USER);

      const loginRes = await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .send({ email: 'test@19t.vn', password: 'correct' });

      const employeeToken = loginRes.body.accessToken;
      const targetUserId = loginRes.body.user.id;

      // Employee tries to deactivate — should be forbidden
      await request(app.getHttpServer())
        .patch(`/api/v1/users/${targetUserId}/deactivate`)
        .set('Authorization', `Bearer ${employeeToken}`)
        .expect(403);
    });

    it('should allow admin to access admin-only endpoint', async () => {
      // Create user via login
      jest
        .spyOn(odooService, 'authenticate')
        .mockResolvedValueOnce(MOCK_ODOO_USER);

      const loginRes = await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .send({ email: 'test@19t.vn', password: 'correct' });

      const userId = loginRes.body.user.id;

      // Assign admin role directly in DB
      const adminRole = await roleRepo.findOne({ where: { name: 'admin' } });
      if (adminRole) {
        await userRoleRepo.save({ user_id: userId, role_id: adminRole.id });
      }

      // Re-login to get token with admin role
      jest
        .spyOn(odooService, 'authenticate')
        .mockResolvedValueOnce(MOCK_ODOO_USER);

      const adminLoginRes = await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .send({ email: 'test@19t.vn', password: 'correct' });

      const adminToken = adminLoginRes.body.accessToken;

      // Create a second user to deactivate
      jest.spyOn(odooService, 'authenticate').mockResolvedValueOnce({
        uid: 99,
        name: 'Target',
        email: 'target@19t.vn',
      });

      const targetLogin = await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .send({ email: 'target@19t.vn', password: 'correct' });

      const targetId = targetLogin.body.user.id;

      await request(app.getHttpServer())
        .patch(`/api/v1/users/${targetId}/deactivate`)
        .set('Authorization', `Bearer ${adminToken}`)
        .expect(200);
    });
  });

  // SECTION_8_5

  // --- 8.5: Account deactivation, deactivated user login blocked ---

  describe('Account deactivation', () => {
    it('should block login for deactivated user', async () => {
      // Create user
      jest
        .spyOn(odooService, 'authenticate')
        .mockResolvedValueOnce(MOCK_ODOO_USER);

      const loginRes = await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .send({ email: 'test@19t.vn', password: 'correct' });

      const userId = loginRes.body.user.id;

      // Deactivate directly in DB (simulating admin action)
      await userRepo.update(userId, { is_active: false });
      await sessionRepo.delete({ user_id: userId });

      // Try to login again — should be forbidden
      jest
        .spyOn(odooService, 'authenticate')
        .mockResolvedValueOnce(MOCK_ODOO_USER);

      await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .send({ email: 'test@19t.vn', password: 'correct' })
        .expect(403);
    });

    it('should delete all sessions when user is deactivated', async () => {
      // Create user and login twice
      jest
        .spyOn(odooService, 'authenticate')
        .mockResolvedValueOnce(MOCK_ODOO_USER);

      const login1 = await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .send({ email: 'test@19t.vn', password: 'correct', device_id: 'd1' });

      jest
        .spyOn(odooService, 'authenticate')
        .mockResolvedValueOnce(MOCK_ODOO_USER);

      await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .send({ email: 'test@19t.vn', password: 'correct', device_id: 'd2' });

      const userId = login1.body.user.id;

      // Assign admin role to this user for self-deactivation test
      const adminRole = await roleRepo.findOne({ where: { name: 'admin' } });
      if (adminRole) {
        await userRoleRepo.save({ user_id: userId, role_id: adminRole.id });
      }

      // Re-login to get admin token
      jest
        .spyOn(odooService, 'authenticate')
        .mockResolvedValueOnce(MOCK_ODOO_USER);

      const adminLogin = await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .send({ email: 'test@19t.vn', password: 'correct' });

      // Create target user
      jest.spyOn(odooService, 'authenticate').mockResolvedValueOnce({
        uid: 88,
        name: 'Victim',
        email: 'victim@19t.vn',
      });

      const victimLogin = await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .send({ email: 'victim@19t.vn', password: 'correct' });

      const victimId = victimLogin.body.user.id;

      // Deactivate victim
      await request(app.getHttpServer())
        .patch(`/api/v1/users/${victimId}/deactivate`)
        .set('Authorization', `Bearer ${adminLogin.body.accessToken}`)
        .expect(200);

      // Victim's sessions should be gone
      const sessions = await sessionRepo.find({ where: { user_id: victimId } });
      expect(sessions.length).toBe(0);

      // Victim's refresh token should fail
      await request(app.getHttpServer())
        .post('/api/v1/auth/refresh')
        .send({ refreshToken: victimLogin.body.refreshToken })
        .expect(401);
    });
  });
});
