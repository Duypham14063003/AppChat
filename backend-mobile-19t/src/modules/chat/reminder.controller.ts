import { Controller, Get, ForbiddenException } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import { ChatService } from './services/chat.service.js';

@ApiTags('Reminders')
@ApiBearerAuth()
@Controller('users/me/reminders')
export class ReminderController {
  constructor(private readonly chatService: ChatService) {}

  @Get()
  @ApiOperation({
    summary: 'List current user upcoming reminders across all conversations',
  })
  async getMyUpcomingReminders(@CurrentUser('userId') userId: string) {
    try {
      return await this.chatService.getUpcomingReminders(userId);
    } catch (err: any) {
      if (err.code === 'FORBIDDEN') throw new ForbiddenException(err.message);
      throw err;
    }
  }
}
