import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { ThrottlerModule } from '@nestjs/throttler';
import { BullModule } from '@nestjs/bullmq';
import { APP_GUARD } from '@nestjs/core';

import {
  User,
  Role,
  UserRole,
  UserSession,
  AuditLog,
} from './entities/index.js';
import { UserPointWallet } from '../rewards/entities/user-point-wallet.entity.js';
import { OdooService } from './services/odoo.service.js';
import { TokenService } from './services/token.service.js';
import { SessionService } from './services/session.service.js';
import { AuthService } from './services/auth.service.js';
import { AuditLogService } from './services/audit-log.service.js';
import { JwtStrategy } from './guards/jwt.strategy.js';
import { JwtAuthGuard } from './guards/jwt-auth.guard.js';
import { RolesGuard } from './guards/roles.guard.js';
import { AuthController } from './auth.controller.js';
import { UserController } from './user.controller.js';
import {
  SessionCleanupProcessor,
  SESSION_CLEANUP_QUEUE,
} from './jobs/session-cleanup.processor.js';
import {
  UserSyncProcessor,
  USER_SYNC_QUEUE,
} from './jobs/user-sync.processor.js';

import type { StringValue } from 'ms';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      User,
      Role,
      UserRole,
      UserSession,
      AuditLog,
      UserPointWallet,
    ]),
    PassportModule.register({ defaultStrategy: 'jwt' }),
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.get<string>('JWT_ACCESS_SECRET'),
        signOptions: {
          expiresIn: config.get<string>('JWT_ACCESS_TTL', '15m') as StringValue,
        },
      }),
    }),
    ThrottlerModule.forRoot([{ ttl: 900000, limit: 5 }]),
    BullModule.registerQueue({ name: SESSION_CLEANUP_QUEUE }),
    BullModule.registerQueue({ name: USER_SYNC_QUEUE }),
  ],
  controllers: [AuthController, UserController],
  providers: [
    OdooService,
    TokenService,
    SessionService,
    AuthService,
    AuditLogService,
    JwtStrategy,
    SessionCleanupProcessor,
    UserSyncProcessor,
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    { provide: APP_GUARD, useClass: RolesGuard },
  ],
  exports: [
    AuthService,
    TokenService,
    SessionService,
    OdooService,
    AuditLogService,
    JwtModule,
    TypeOrmModule,
  ],
})
export class AuthModule {}
