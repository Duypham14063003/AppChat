import {
  Controller,
  Post,
  Get,
  Delete,
  Patch,
  Body,
  Param,
  Req,
  HttpCode,
  HttpStatus,
  NotFoundException,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import type { Request } from 'express';
import { AuthService } from './services/auth.service.js';
import { SessionService } from './services/session.service.js';
import { LoginDto, RefreshDto } from './dto/auth.dto.js';
import { Public } from './decorators/public.decorator.js';
import { Roles } from './decorators/roles.decorator.js';
import { CurrentUser } from './decorators/current-user.decorator.js';

@ApiTags('Auth')
@Controller('auth')
export class AuthController {
  constructor(
    private readonly authService: AuthService,
    private readonly sessionService: SessionService,
  ) {}

  @Public()
  @Throttle({ default: { limit: 5, ttl: 900000 } })
  @Post('login')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Login via Odoo SSO' })
  async login(@Body() dto: LoginDto, @Req() req: Request) {
    const ip = req.ip || req.socket.remoteAddress;
    const userAgent = req.headers['user-agent'];
    return this.authService.login(
      dto.email,
      dto.password,
      ip,
      userAgent,
      dto.device_id,
      dto.device_name,
    );
  }

  @Public()
  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Refresh access token' })
  async refresh(@Body() dto: RefreshDto, @Req() req: Request) {
    const ip = req.ip || req.socket.remoteAddress;
    return this.authService.refreshTokens(dto.refreshToken, ip);
  }

  @ApiBearerAuth()
  @Get('sessions')
  @ApiOperation({ summary: 'List active sessions' })
  async getSessions(@CurrentUser('userId') userId: string) {
    const sessions = await this.sessionService.findSessionsByUser(userId);
    return sessions.map((s) => ({
      id: s.id,
      deviceName: s.device_name,
      lastUsedAt: s.last_used_at,
      lastIp: s.last_ip,
      createdAt: s.created_at,
    }));
  }

  @ApiBearerAuth()
  @Post('logout')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Logout current device' })
  async logout(
    @CurrentUser('userId') userId: string,
    @Body() dto: RefreshDto,
    @Req() req: Request,
  ) {
    const ip = req.ip || req.socket.remoteAddress;
    const userAgent = req.headers['user-agent'];
    await this.authService.logout(userId, dto.refreshToken, ip, userAgent);
    return { message: 'Logged out successfully' };
  }

  @ApiBearerAuth()
  @Post('logout-all')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Logout all devices' })
  async logoutAll(@CurrentUser('userId') userId: string, @Req() req: Request) {
    const ip = req.ip || req.socket.remoteAddress;
    const userAgent = req.headers['user-agent'];
    await this.authService.logoutAll(userId, ip, userAgent);
    return { message: 'All sessions terminated' };
  }

  @ApiBearerAuth()
  @Delete('sessions/:id')
  @ApiOperation({ summary: 'Delete specific session' })
  async deleteSession(
    @CurrentUser('userId') userId: string,
    @Param('id') sessionId: string,
  ) {
    const session = await this.sessionService.findSessionById(sessionId);
    if (!session || session.user_id !== userId) {
      throw new NotFoundException();
    }
    await this.sessionService.deleteSession(sessionId);
    return { message: 'Session deleted' };
  }

  @ApiBearerAuth()
  @Patch('sessions/fcm-token')
  @ApiOperation({ summary: 'Update FCM token for current session' })
  async updateFcmToken(
    @CurrentUser('userId') userId: string,
    @Body() body: { device_id: string; fcm_token: string },
  ) {
    const session = await this.sessionService.findSessionByUserAndDevice(
      userId,
      body.device_id,
    );
    if (!session) {
      throw new NotFoundException('Session not found');
    }
    await this.sessionService.updateSession(session.id, {
      fcm_token: body.fcm_token,
    });
    return { message: 'FCM token updated' };
  }
}
