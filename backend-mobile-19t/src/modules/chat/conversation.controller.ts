import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Param,
  Query,
  HttpCode,
  HttpStatus,
  ForbiddenException,
  NotFoundException,
  BadRequestException,
  Header,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import { ChatService } from './services/chat.service.js';
import {
  CreateConversationDto,
  CreateGroupDto,
  UpdateConversationDto,
  AddMembersDto,
  UpdateMemberRoleDto,
  PaginationQueryDto,
  PinMessageDto,
  BookmarkMessageDto,
  EditMessageDto,
  CreateMessageReminderDto,
  UpdateMessageReminderDto,
  GetConversationMediaQueryDto,
  GetConversationFilesQueryDto,
  GetConversationLinksQueryDto,
} from './dto/chat.dto.js';

@ApiTags('Conversations')
@ApiBearerAuth()
@Controller('conversations')
export class ConversationController {
  constructor(private readonly chatService: ChatService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create a direct conversation' })
  async create(
    @CurrentUser('userId') userId: string,
    @Body() dto: CreateConversationDto,
  ) {
    return this.chatService.createDirectConversation(userId, dto.member_id);
  }

  @Get()
  @ApiOperation({ summary: 'List conversations' })
  async list(
    @CurrentUser('userId') userId: string,
    @Query() query: PaginationQueryDto,
  ) {
    return this.chatService.getConversations(userId, query.cursor);
  }

  @Post('group')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create a group conversation' })
  async createGroup(
    @CurrentUser('userId') userId: string,
    @Body() dto: CreateGroupDto,
  ) {
    try {
      return await this.chatService.createGroupConversation(
        userId,
        dto.name,
        dto.member_ids,
      );
    } catch (err: any) {
      if (err.message?.includes('At least') || err.message?.includes('invalid'))
        throw new BadRequestException(err.message);
      throw err;
    }
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get conversation details' })
  async getOne(
    @CurrentUser('userId') userId: string,
    @Param('id') convId: string,
  ) {
    try {
      const conv = await this.chatService.getConversationById(convId, userId);
      if (!conv) throw new NotFoundException();
      return conv;
    } catch (err: any) {
      if (err.code === 'FORBIDDEN') throw new ForbiddenException(err.message);
      throw err;
    }
  }

  @Get(':id/encryption-key')
  @ApiOperation({ summary: 'Get the active conversation encryption key' })
  async getEncryptionKey(
    @CurrentUser('userId') userId: string,
    @Param('id') convId: string,
  ) {
    try {
      return await this.chatService.getConversationEncryptionKey(
        userId,
        convId,
      );
    } catch (err: any) {
      if (err.code === 'FORBIDDEN') throw new ForbiddenException(err.message);
      throw err;
    }
  }

  @Get(':id/messages')
  @ApiOperation({ summary: 'Get messages with cursor pagination' })
  async getMessages(
    @CurrentUser('userId') userId: string,
    @Param('id') convId: string,
    @Query() query: PaginationQueryDto,
  ) {
    try {
      return await this.chatService.getMessages(
        convId,
        userId,
        query.cursor,
        30,
        query.dir || 'before',
      );
    } catch (err: any) {
      if (err.code === 'FORBIDDEN') throw new ForbiddenException(err.message);
      throw err;
    }
  }

  @Get(':id/messages/:messageId/seen-by')
  @ApiOperation({ summary: 'List members who have seen a message' })
  @Header(
    'Cache-Control',
    'no-store, no-cache, must-revalidate, proxy-revalidate',
  )
  @Header('Pragma', 'no-cache')
  @Header('Expires', '0')
  @Header('Surrogate-Control', 'no-store')
  async getMessageSeenBy(
    @CurrentUser('userId') userId: string,
    @Param('id') convId: string,
    @Param('messageId') messageId: string,
  ) {
    try {
      return await this.chatService.getMessageSeenBy(userId, convId, messageId);
    } catch (err: any) {
      if (err.code === 'FORBIDDEN') throw new ForbiddenException(err.message);
      if (err.code === 'NOT_FOUND') throw new NotFoundException(err.message);
      if (err.code === 'INVALID_MESSAGE_STATE')
        throw new BadRequestException(err.message);
      throw err;
    }
  }

  @Get(':id/messages/:messageId/reminders')
  @ApiOperation({ summary: 'List visible reminders for a message' })
  async getMessageReminders(
    @CurrentUser('userId') userId: string,
    @Param('id') convId: string,
    @Param('messageId') messageId: string,
  ) {
    try {
      return await this.chatService.listMessageReminders(
        userId,
        convId,
        messageId,
      );
    } catch (err: any) {
      if (err.code === 'FORBIDDEN') throw new ForbiddenException(err.message);
      if (err.code === 'NOT_FOUND') throw new NotFoundException(err.message);
      if (
        err.code === 'INVALID_MESSAGE_TYPE' ||
        err.code === 'INVALID_MESSAGE_STATE'
      ) {
        throw new BadRequestException(err.message);
      }
      throw err;
    }
  }

  @Get(':id/reminders')
  @ApiOperation({ summary: 'List upcoming reminders for a conversation' })
  async getConversationReminders(
    @CurrentUser('userId') userId: string,
    @Param('id') convId: string,
  ) {
    try {
      return await this.chatService.listConversationReminders(userId, convId);
    } catch (err: any) {
      if (err.code === 'FORBIDDEN') throw new ForbiddenException(err.message);
      throw err;
    }
  }

  @Post(':id/reminders')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create a reminder from a message' })
  async createMessageReminder(
    @CurrentUser('userId') userId: string,
    @Param('id') convId: string,
    @Body() dto: CreateMessageReminderDto,
  ) {
    try {
      return await this.chatService.createMessageReminder(userId, convId, dto);
    } catch (err: any) {
      if (err.code === 'FORBIDDEN') throw new ForbiddenException(err.message);
      if (err.code === 'NOT_FOUND') throw new NotFoundException(err.message);
      if (
        err.code === 'INVALID_MESSAGE_TYPE' ||
        err.code === 'INVALID_MESSAGE_STATE' ||
        err.code === 'INVALID_FORMAT' ||
        err.code === 'INVALID_REMIND_AT' ||
        err.code === 'DUPLICATE_REMINDER'
      ) {
        throw new BadRequestException(err.message);
      }
      throw err;
    }
  }

  @Patch(':id/reminders/:reminderId')
  @ApiOperation({ summary: 'Update a pending reminder' })
  async updateMessageReminder(
    @CurrentUser('userId') userId: string,
    @Param('id') convId: string,
    @Param('reminderId') reminderId: string,
    @Body() dto: UpdateMessageReminderDto,
  ) {
    try {
      return await this.chatService.updateMessageReminder(
        userId,
        convId,
        reminderId,
        dto,
      );
    } catch (err: any) {
      if (err.code === 'FORBIDDEN') throw new ForbiddenException(err.message);
      if (err.code === 'NOT_FOUND') throw new NotFoundException(err.message);
      if (
        err.code === 'INVALID_FORMAT' ||
        err.code === 'INVALID_REMIND_AT' ||
        err.code === 'INVALID_STATUS' ||
        err.code === 'DUPLICATE_REMINDER'
      ) {
        throw new BadRequestException(err.message);
      }
      throw err;
    }
  }

  @Delete(':id/reminders/:reminderId')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Cancel a pending reminder' })
  async cancelMessageReminder(
    @CurrentUser('userId') userId: string,
    @Param('id') convId: string,
    @Param('reminderId') reminderId: string,
  ) {
    try {
      return await this.chatService.cancelMessageReminder(
        userId,
        convId,
        reminderId,
      );
    } catch (err: any) {
      if (err.code === 'FORBIDDEN') throw new ForbiddenException(err.message);
      if (err.code === 'NOT_FOUND') throw new NotFoundException(err.message);
      if (err.code === 'INVALID_STATUS')
        throw new BadRequestException(err.message);
      throw err;
    }
  }

  @Delete(':id/messages/:messageId')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Recall a message' })
  async deleteMessage(
    @CurrentUser('userId') userId: string,
    @Param('id') convId: string,
    @Param('messageId') messageId: string,
  ) {
    try {
      return await this.chatService.recallMessage(userId, messageId);
    } catch (err: any) {
      if (err.code === 'FORBIDDEN') throw new ForbiddenException(err.message);
      if (err.code === 'NOT_FOUND') throw new NotFoundException(err.message);
      if (err.code === 'ALREADY_RECALLED')
        throw new BadRequestException(err.message);
      throw err;
    }
  }

  @Patch(':id/messages/:messageId')
  @ApiOperation({ summary: 'Edit a message' })
  async editMessage(
    @CurrentUser('userId') userId: string,
    @Param('id') convId: string,
    @Param('messageId') messageId: string,
    @Body() dto: EditMessageDto,
  ) {
    try {
      return await this.chatService.editMessage(
        userId,
        messageId,
        dto.content,
        dto.metadata,
        dto.blind_index_v1,
      );
    } catch (err: any) {
      if (err.code === 'FORBIDDEN') throw new ForbiddenException(err.message);
      if (err.code === 'NOT_FOUND') throw new NotFoundException(err.message);
      if (
        err.code === 'INVALID_MESSAGE_TYPE' ||
        err.code === 'INVALID_CONTENT' ||
        err.code === 'INVALID_MESSAGE_STATE' ||
        err.code === 'INVALID_FORMAT'
      ) {
        throw new BadRequestException(err.message);
      }
      throw err;
    }
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Update group conversation' })
  async update(
    @CurrentUser('userId') userId: string,
    @Param('id') convId: string,
    @Body() dto: UpdateConversationDto,
  ) {
    try {
      return await this.chatService.updateConversation(convId, userId, dto);
    } catch (err: any) {
      if (err.code === 'FORBIDDEN') throw new ForbiddenException(err.message);
      if (err.message?.includes('DIRECT'))
        throw new BadRequestException(err.message);
      throw err;
    }
  }

  @Post(':id/members')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Add members to group' })
  async addMembers(
    @CurrentUser('userId') userId: string,
    @Param('id') convId: string,
    @Body() dto: AddMembersDto,
  ) {
    try {
      return await this.chatService.addMembers(convId, userId, dto.member_ids);
    } catch (err: any) {
      if (err.code === 'FORBIDDEN') throw new ForbiddenException(err.message);
      throw err;
    }
  }

  @Delete(':id/members/:userId')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Remove member or leave group' })
  async removeMember(
    @CurrentUser('userId') actorId: string,
    @Param('id') convId: string,
    @Param('userId') targetUserId: string,
  ) {
    try {
      await this.chatService.removeMember(convId, actorId, targetUserId);
    } catch (err: any) {
      if (err.code === 'FORBIDDEN') throw new ForbiddenException(err.message);
      throw err;
    }
  }

  @Patch(':id/members/:userId')
  @ApiOperation({ summary: 'Change member role' })
  async updateMemberRole(
    @CurrentUser('userId') actorId: string,
    @Param('id') convId: string,
    @Param('userId') targetUserId: string,
    @Body() dto: UpdateMemberRoleDto,
  ) {
    try {
      await this.chatService.updateMemberRole(
        convId,
        actorId,
        targetUserId,
        dto.role,
      );
      return { message: 'Role updated' };
    } catch (err: any) {
      if (err.code === 'FORBIDDEN') throw new ForbiddenException(err.message);
      throw err;
    }
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Delete group (creator only)' })
  async deleteGroup(
    @CurrentUser('userId') userId: string,
    @Param('id') convId: string,
  ) {
    try {
      await this.chatService.deleteGroup(convId, userId);
    } catch (err: any) {
      if (err.code === 'FORBIDDEN') throw new ForbiddenException(err.message);
      throw err;
    }
  }

  // --- Private message bookmarks ---

  @Post(':id/bookmarks')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Bookmark a message for the current user' })
  async bookmarkMessage(
    @CurrentUser('userId') userId: string,
    @Param('id') convId: string,
    @Body() dto: BookmarkMessageDto,
  ) {
    try {
      return await this.chatService.bookmarkMessage(
        userId,
        convId,
        dto.message_id,
      );
    } catch (err: any) {
      if (err.code === 'FORBIDDEN') throw new ForbiddenException(err.message);
      if (err.code === 'NOT_FOUND') throw new NotFoundException(err.message);
      if (err.code === 'ALREADY_BOOKMARKED')
        throw new BadRequestException(err.message);
      throw err;
    }
  }

  @Get(':id/bookmarks')
  @ApiOperation({ summary: 'List current user bookmarks in a conversation' })
  async getBookmarks(
    @CurrentUser('userId') userId: string,
    @Param('id') convId: string,
  ) {
    try {
      return await this.chatService.getBookmarks(userId, convId);
    } catch (err: any) {
      if (err.code === 'FORBIDDEN') throw new ForbiddenException(err.message);
      throw err;
    }
  }

  @Delete(':id/bookmarks/:messageId')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Delete current user bookmark for a message' })
  async deleteBookmark(
    @CurrentUser('userId') userId: string,
    @Param('id') convId: string,
    @Param('messageId') messageId: string,
  ) {
    try {
      await this.chatService.deleteBookmark(userId, convId, messageId);
      return { message: 'Bookmark removed' };
    } catch (err: any) {
      if (err.code === 'FORBIDDEN') throw new ForbiddenException(err.message);
      if (err.code === 'NOT_FOUND') throw new NotFoundException(err.message);
      throw err;
    }
  }

  // --- Pinned messages ---

  @Post(':id/pins')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Pin a message' })
  async pinMessage(
    @CurrentUser('userId') userId: string,
    @Param('id') convId: string,
    @Body() dto: PinMessageDto,
  ) {
    try {
      await this.chatService.pinMessage(userId, convId, dto.message_id);
      return { message: 'Message pinned' };
    } catch (err: any) {
      if (err.code === 'FORBIDDEN') throw new ForbiddenException(err.message);
      if (err.code === 'NOT_FOUND') throw new NotFoundException(err.message);
      if (err.code === 'ALREADY_PINNED' || err.code === 'PIN_LIMIT')
        throw new BadRequestException(err.message);
      throw err;
    }
  }

  @Get(':id/pins')
  @ApiOperation({ summary: 'List pinned messages' })
  async getPinnedMessages(
    @CurrentUser('userId') userId: string,
    @Param('id') convId: string,
  ) {
    try {
      return await this.chatService.getPinnedMessages(userId, convId);
    } catch (err: any) {
      if (err.code === 'FORBIDDEN') throw new ForbiddenException(err.message);
      throw err;
    }
  }

  @Delete(':id/pins/:messageId')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Unpin a message' })
  async unpinMessage(
    @CurrentUser('userId') userId: string,
    @Param('id') convId: string,
    @Param('messageId') messageId: string,
  ) {
    try {
      await this.chatService.unpinMessage(userId, convId, messageId);
      return { message: 'Message unpinned' };
    } catch (err: any) {
      if (err.code === 'FORBIDDEN') throw new ForbiddenException(err.message);
      if (err.code === 'NOT_FOUND') throw new NotFoundException(err.message);
      throw err;
    }
  }

  @Delete(':id/pins')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Unpin all messages' })
  async unpinAllMessages(
    @CurrentUser('userId') userId: string,
    @Param('id') convId: string,
  ) {
    try {
      await this.chatService.unpinAllMessages(userId, convId);
      return { message: 'All messages unpinned' };
    } catch (err: any) {
      if (err.code === 'FORBIDDEN') throw new ForbiddenException(err.message);
      throw err;
    }
  }

  // --- Group Info Assets ---

  @Get(':id/media')
  @ApiOperation({
    summary: 'Get media (images, albums, videos) from conversation',
  })
  async getConversationMedia(
    @CurrentUser('userId') userId: string,
    @Param('id') convId: string,
    @Query() query: GetConversationMediaQueryDto,
  ) {
    try {
      return await this.chatService.getConversationMedia(
        userId,
        convId,
        query.cursor,
        query.limit || 20,
        query.type || 'all',
      );
    } catch (err: any) {
      if (err.code === 'FORBIDDEN') throw new ForbiddenException(err.message);
      throw err;
    }
  }

  @Get(':id/files')
  @ApiOperation({ summary: 'Get files from conversation' })
  async getConversationFiles(
    @CurrentUser('userId') userId: string,
    @Param('id') convId: string,
    @Query() query: GetConversationFilesQueryDto,
  ) {
    try {
      return await this.chatService.getConversationFiles(
        userId,
        convId,
        query.cursor,
        query.limit || 20,
      );
    } catch (err: any) {
      if (err.code === 'FORBIDDEN') throw new ForbiddenException(err.message);
      throw err;
    }
  }

  @Get(':id/links')
  @ApiOperation({ summary: 'Get messages with links from conversation' })
  async getConversationLinks(
    @CurrentUser('userId') userId: string,
    @Param('id') convId: string,
    @Query() query: GetConversationLinksQueryDto,
  ) {
    try {
      return await this.chatService.getConversationLinks(
        userId,
        convId,
        query.cursor,
        query.limit || 20,
      );
    } catch (err: any) {
      if (err.code === 'FORBIDDEN') throw new ForbiddenException(err.message);
      throw err;
    }
  }

  @Get(':id/assets-summary')
  @ApiOperation({
    summary:
      'Get assets summary for conversation (members, media, files, links count)',
  })
  async getConversationAssetsSummary(
    @CurrentUser('userId') userId: string,
    @Param('id') convId: string,
  ) {
    try {
      return await this.chatService.getConversationAssetsSummary(
        userId,
        convId,
      );
    } catch (err: any) {
      if (err.code === 'FORBIDDEN') throw new ForbiddenException(err.message);
      throw err;
    }
  }
}
