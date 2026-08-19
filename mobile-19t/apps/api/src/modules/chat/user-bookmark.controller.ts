import { Controller, Get, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import {
  GlobalBookmarkInboxQueryDto,
  BookmarkConversationTypeFilterDto,
} from './dto/chat.dto.js';
import { ChatService } from './services/chat.service.js';

@ApiTags('Users')
@ApiBearerAuth()
@Controller('users/me/bookmarks')
export class UserBookmarkController {
  constructor(private readonly chatService: ChatService) {}

  @Get()
  @ApiOperation({ summary: 'List bookmarked messages across all conversations' })
  async getGlobalBookmarkedMessages(
    @CurrentUser('userId') userId: string,
    @Query() query: GlobalBookmarkInboxQueryDto,
  ) {
    return this.chatService.getGlobalBookmarkedMessages(userId, {
      convType: query.conv_type as BookmarkConversationTypeFilterDto | undefined,
      cursor: query.cursor,
      limit: query.limit ?? 20,
    });
  }
}
