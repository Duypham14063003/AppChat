import { Controller, Get, Query, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { ChatService } from './services/chat.service.js';
import { SearchMessagesDto } from './dto/chat.dto.js';

@ApiTags('Search')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('search')
export class SearchController {
  constructor(private readonly chatService: ChatService) {}

  @Get('messages')
  @ApiOperation({ summary: 'Search messages with full-text search' })
  async searchMessages(@Query() dto: SearchMessagesDto, @Req() req: any) {
    const userId = req.user.id as string;
    return this.chatService.searchMessages(
      userId,
      dto.q,
      dto.conv_id,
      dto.cursor,
      dto.limit ?? 20,
    );
  }
}
