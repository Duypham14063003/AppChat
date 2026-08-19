import {
  BadRequestException,
  Controller,
  Get,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
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
  async searchMessages(
    @CurrentUser('userId') userId: string,
    @Query() dto: SearchMessagesDto,
  ) {
    try {
      return await this.chatService.searchMessages(
        userId,
        dto.q,
        dto.conv_id,
        dto.cursor,
        dto.limit ?? 20,
        dto.q_hashes,
      );
    } catch (error: any) {
      if (error?.code === 'INVALID_FORMAT') {
        throw new BadRequestException(error.message);
      }
      throw error;
    }
  }
}
