import { Body, Controller, Delete, Get, Patch, Post, Query } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { Public } from '../auth/decorators/public.decorator.js';
import { BotService } from './bot.service.js';
import {
  DeleteBotMessageDto,
  GetBotMessagesQueryDto,
  SendBotMessageDto,
  UpdateBotMessageDto,
} from './dto/bot.dto.js';

@ApiTags('Bot')
@Controller('bot')
export class BotController {
  constructor(private readonly botService: BotService) {}

  @Public()
  @Throttle({ default: { limit: 100, ttl: 60000 } }) // 100 requests per minute
  @Get('conversations')
  @ApiOperation({
    summary:
      'List active group conversations for bot integrations (public endpoint, rate limited)',
  })
  async listConversations() {
    return await this.botService.listBotConversations();
  }

  @Public()
  @Throttle({ default: { limit: 100, ttl: 60000 } })
  @Get('users')
  @ApiOperation({
    summary:
      'List active users for bot integrations (public endpoint, rate limited)',
  })
  async listUsers() {
    return await this.botService.listBotUsers();
  }

  @Public()
  @Throttle({ default: { limit: 100, ttl: 60000 } })
  @Post('messages')
  @ApiOperation({
    summary:
      'Send bot message to conversation or user (public endpoint, rate limited)',
  })
  async sendMessage(@Body() dto: SendBotMessageDto) {
    return await this.botService.sendBotMessage(dto);
  }

  @Public()
  @Throttle({ default: { limit: 100, ttl: 60000 } })
  @Get('messages')
  @ApiOperation({
    summary:
      'Get bot messages with pagination (public endpoint, rate limited)',
  })
  async getMessages(@Query() query: GetBotMessagesQueryDto) {
    return await this.botService.getBotMessages(query);
  }

  @Public()
  @Throttle({ default: { limit: 100, ttl: 60000 } })
  @Patch('messages')
  @ApiOperation({
    summary: 'Update bot message content (public endpoint, rate limited)',
  })
  async updateMessage(@Body() dto: UpdateBotMessageDto) {
    return await this.botService.updateBotMessage(dto);
  }

  @Public()
  @Throttle({ default: { limit: 100, ttl: 60000 } })
  @Delete('messages')
  @ApiOperation({
    summary: 'Delete bot message (soft delete) (public endpoint, rate limited)',
  })
  async deleteMessage(@Body() dto: DeleteBotMessageDto) {
    return await this.botService.deleteBotMessage(dto);
  }
}
