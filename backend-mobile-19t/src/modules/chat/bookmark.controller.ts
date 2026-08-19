import {
  BadRequestException,
  Controller,
  ForbiddenException,
  Get,
  Query,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import {
  GetGlobalBookmarksQueryDto,
  GlobalBookmarksResponseDto,
} from './dto/chat.dto.js';
import { ChatService } from './services/chat.service.js';

@ApiTags('Bookmarks')
@ApiBearerAuth()
@Controller('users/me/bookmarks')
export class BookmarkController {
  constructor(private readonly chatService: ChatService) {}

  @Get()
  @ApiOperation({
    summary: 'List current user bookmarks across all accessible conversations',
  })
  @ApiOkResponse({ type: GlobalBookmarksResponseDto })
  async getMyBookmarks(
    @CurrentUser('userId') userId: string,
    @Query() query: GetGlobalBookmarksQueryDto,
  ): Promise<GlobalBookmarksResponseDto> {
    try {
      return await this.chatService.getGlobalBookmarks(userId, query);
    } catch (err: any) {
      if (err.code === 'FORBIDDEN') throw new ForbiddenException(err.message);
      if (err.code === 'INVALID_CURSOR')
        throw new BadRequestException(err.message);
      throw err;
    }
  }
}
