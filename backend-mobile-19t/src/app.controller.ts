import { Controller, Get, Post, Body } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { ApiBearerAuth } from '@nestjs/swagger';
import { CurrentUser } from './modules/auth/decorators/current-user.decorator.js';
import { Public } from './modules/auth/decorators/public.decorator.js';
import { AuthService } from './modules/auth/services/auth.service.js';
import { ApnsService } from './modules/notification/services/apns.service.js';

@ApiTags('Config')
@Controller()
export class AppController {
  constructor(
    private readonly authService: AuthService,
    private readonly apnsService: ApnsService,
  ) {}

  @Get('health')
  @ApiOperation({ summary: 'Health check' })
  getHealth() {
    return { status: 'ok' };
  }

  @ApiBearerAuth()
  @Get('config')
  @ApiOperation({ summary: 'Get initial config for the current user' })
  getConfig(@CurrentUser('userId') userId: string) {
    return this.authService.getInitialConfig(userId);
  }

  @Public()
  @Post('test-apns')
  @ApiOperation({ summary: 'Test APNS VoIP push notification' })
  async testApnsPush(
    @Body()
    body: {
      token: string;
      type?: 'call_invite' | 'call_answer' | 'call_reject' | 'call_end';
      callerId?: string;
      callerName?: string;
    },
  ) {
    const {
      token,
      type = 'call_invite',
      callerId = 'test-caller',
      callerName = 'Test Caller',
    } = body;

    const data = {
      type,
      caller_id: callerId,
      caller_name: callerName,
      call_id: `test-${Date.now()}`,
    };

    const result = await this.apnsService.sendVoipPush(token, data);
    return {
      success: result.success,
      message: result.success
        ? 'VoIP push sent successfully'
        : 'Failed to send VoIP push',
      badTokens: result.badTokens,
    };
  }
}
