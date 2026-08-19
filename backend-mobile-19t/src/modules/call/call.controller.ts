import {
  Controller,
  Post,
  Get,
  Body,
  Param,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { CallService } from './services/call.service.js';
import { StartCallDto } from './dto/call.dto.js';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';

@ApiTags('Calls')
@ApiBearerAuth()
@Controller('calls')
export class CallController {
  constructor(private readonly callService: CallService) {}

  @Post('start')
  @ApiOperation({ summary: 'Bắt đầu cuộc gọi mới' })
  async startCall(
    @CurrentUser('userId') userId: string,
    @CurrentUser('sessionId') sessionId: string | undefined,
    @Body() dto: StartCallDto,
  ) {
    return this.callService.startCall(userId, dto, sessionId);
  }

  @Post(':id/accept')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Chấp nhận cuộc gọi' })
  async acceptCall(
    @CurrentUser('userId') userId: string,
    @Param('id') id: string,
  ) {
    return this.callService.acceptCall(userId, id);
  }

  @Post(':id/reject')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Từ chối cuộc gọi' })
  async rejectCall(
    @CurrentUser('userId') userId: string,
    @Param('id') id: string,
  ) {
    return this.callService.rejectCall(userId, id);
  }

  @Post(':id/end')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Kết thúc cuộc gọi' })
  async endCall(
    @CurrentUser('userId') userId: string,
    @CurrentUser('sessionId') sessionId: string | undefined,
    @Param('id') id: string,
  ) {
    return this.callService.endCall(userId, id, sessionId);
  }

  @Get(':id/token')
  @ApiOperation({ summary: 'Lấy Agora token cho cuộc gọi' })
  async getToken(
    @CurrentUser('userId') userId: string,
    @Param('id') id: string,
  ) {
    return this.callService.getAgoraToken(userId, id);
  }

  @Get('active')
  @ApiOperation({ summary: 'Lấy cuộc gọi đến đang chờ (ringing) của tôi' })
  async getActiveIncomingCall(@CurrentUser('userId') userId: string) {
    return this.callService.getActiveIncomingCall(userId);
  }

  @Get('history')
  @ApiOperation({ summary: 'Lấy lịch sử cuộc gọi của tôi' })
  async getHistory(@CurrentUser('userId') userId: string) {
    return this.callService.getHistory(userId);
  }
}
