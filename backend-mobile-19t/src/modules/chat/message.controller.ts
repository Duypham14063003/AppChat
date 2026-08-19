import {
  Controller,
  Get,
  Patch,
  Post,
  Delete,
  Body,
  Param,
  HttpCode,
  HttpStatus,
  ForbiddenException,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import { ChatService } from './services/chat.service.js';
import { EditMessageDto, RecallMessageDto } from './dto/chat.dto.js';

@ApiTags('Messages')
@ApiBearerAuth()
@Controller('messages')
export class MessageController {
  constructor(private readonly chatService: ChatService) {}

  @Get(':id')
  @ApiOperation({ summary: 'Get a message by id' })
  async getMessage(
    @CurrentUser('userId') userId: string,
    @Param('id') messageId: string,
  ) {
    try {
      return await this.chatService.getMessageForUser(userId, messageId);
    } catch (err: any) {
      if (err.code === 'FORBIDDEN') throw new ForbiddenException(err.message);
      if (err.code === 'NOT_FOUND') throw new NotFoundException(err.message);
      throw err;
    }
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Edit a text message' })
  async editMessage(
    @CurrentUser('userId') userId: string,
    @Param('id') messageId: string,
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

  @Post(':id/recall')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Recall a message' })
  async recallMessage(
    @CurrentUser('userId') userId: string,
    @Param('id') messageId: string,
    @Body() dto: RecallMessageDto,
  ) {
    try {
      return await this.chatService.recallMessage(
        userId,
        messageId,
        dto.reason,
      );
    } catch (err: any) {
      if (err.code === 'FORBIDDEN') throw new ForbiddenException(err.message);
      if (err.code === 'NOT_FOUND') throw new NotFoundException(err.message);
      throw err;
    }
  }
}
