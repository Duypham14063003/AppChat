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

  @Patch(':id/messages/:messageId')
  @ApiOperation({ summary: 'Edit a message sent by the current user' })
  async editMessage(
    @CurrentUser('userId') userId: string,
    @Param('id') convId: string,
    @Param('messageId') messageId: string,
    @Body() dto: EditMessageDto,
  ) {
    try {
      return await this.chatService.editMessage(
        userId,
        convId,
        messageId,
        dto.content,
      );
    } catch (err: any) {
      if (err.code === 'FORBIDDEN') throw new ForbiddenException(err.message);
      if (err.code === 'NOT_FOUND') throw new NotFoundException(err.message);
      if (
        err.code === 'INVALID_MESSAGE_TYPE' ||
        err.code === 'ALREADY_RECALLED' ||
        err.code === 'INVALID_CONTENT'
      ) {
        throw new BadRequestException(err.message);
      }
      throw err;
    }
  }

  @Delete(':id/messages/:messageId')
  @ApiOperation({ summary: 'Recall a message sent by the current user' })
  async recallMessage(
    @CurrentUser('userId') userId: string,
    @Param('id') convId: string,
    @Param('messageId') messageId: string,
  ) {
    try {
      return await this.chatService.recallMessage(userId, convId, messageId);
    } catch (err: any) {
      if (err.code === 'FORBIDDEN') throw new ForbiddenException(err.message);
      if (err.code === 'NOT_FOUND') throw new NotFoundException(err.message);
      if (err.code === 'ALREADY_RECALLED') {
        throw new BadRequestException(err.message);
      }
      throw err;
    }
  }

  @Get(':id/messages/:messageId/reminders')
  @ApiOperation({ summary: 'List reminders for a message' })
  async listMessageReminders(
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
      throw err;
    }
  }

  @Post(':id/reminders')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create a chat message reminder' })
  async createReminder(
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
        err.code === 'INVALID_REMIND_AT' ||
        err.code === 'INVALID_REMINDER_SCOPE' ||
        err.code === 'INVALID_REMINDER_SOURCE' ||
        err.code === 'REMINDER_DUPLICATE'
      ) {
        throw new BadRequestException(err.message);
      }
      throw err;
    }
  }

  @Patch(':id/reminders/:reminderId')
  @ApiOperation({ summary: 'Update a chat message reminder' })
  async updateReminder(
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
        err.code === 'INVALID_REMIND_AT' ||
        err.code === 'INVALID_REMINDER_SCOPE' ||
        err.code === 'REMINDER_DUPLICATE' ||
        err.code === 'REMINDER_FINALIZED'
      ) {
        throw new BadRequestException(err.message);
      }
      throw err;
    }
  }

  @Delete(':id/reminders/:reminderId')
  @ApiOperation({ summary: 'Cancel a chat message reminder' })
  async cancelReminder(
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
      if (err.code === 'REMINDER_FINALIZED') {
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

  // --- Message bookmarks ---

  @Post(':id/bookmarks')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Bookmark a message for the current user' })
  async bookmarkMessage(
    @CurrentUser('userId') userId: string,
    @Param('id') convId: string,
    @Body() dto: BookmarkMessageDto,
  ) {
    try {
      await this.chatService.bookmarkMessage(userId, convId, dto.message_id);
      return { message: 'Message bookmarked' };
    } catch (err: any) {
      if (err.code === 'FORBIDDEN') throw new ForbiddenException(err.message);
      if (err.code === 'NOT_FOUND') throw new NotFoundException(err.message);
      if (err.code === 'ALREADY_BOOKMARKED')
        throw new BadRequestException(err.message);
      throw err;
    }
  }

  @Get(':id/bookmarks')
  @ApiOperation({ summary: 'List bookmarked messages for the current user' })
  async getBookmarkedMessages(
    @CurrentUser('userId') userId: string,
    @Param('id') convId: string,
  ) {
    try {
      return await this.chatService.getBookmarkedMessages(userId, convId);
    } catch (err: any) {
      if (err.code === 'FORBIDDEN') throw new ForbiddenException(err.message);
      throw err;
    }
  }

  @Delete(':id/bookmarks/:messageId')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Remove a bookmark for the current user' })
  async removeBookmark(
    @CurrentUser('userId') userId: string,
    @Param('id') convId: string,
    @Param('messageId') messageId: string,
  ) {
    try {
      await this.chatService.removeBookmark(userId, convId, messageId);
      return { message: 'Message unbookmarked' };
    } catch (err: any) {
      if (err.code === 'FORBIDDEN') throw new ForbiddenException(err.message);
      if (err.code === 'NOT_FOUND') throw new NotFoundException(err.message);
      throw err;
    }
  }
}
