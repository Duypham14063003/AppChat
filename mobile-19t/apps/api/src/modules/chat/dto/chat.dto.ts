import {
  IsUUID,
  IsString,
  IsOptional,
  IsEnum,
  IsObject,
  IsArray,
  IsInt,
  Min,
  Max,
  ArrayMinSize,
  ArrayMaxSize,
  MinLength,
  MaxLength,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';

export enum MessageType {
  TEXT = 'text',
  IMAGE = 'image',
  ALBUM = 'album',
  FILE = 'file',
  VOICE = 'voice',
  VIDEO = 'video',
  SYSTEM = 'system',
}

export enum MessageReminderScopeDto {
  SELF = 'self',
  EVERYONE = 'everyone',
}

export class SendMessageDto {
  @ApiProperty()
  @IsUUID()
  id!: string;

  @ApiProperty()
  @IsUUID()
  conv_id!: string;

  @ApiProperty({ enum: MessageType })
  @IsEnum(MessageType)
  type!: MessageType;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  content?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID()
  reply_to_id?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsObject()
  metadata?: Record<string, unknown>;
}

export class CreateConversationDto {
  @ApiProperty({
    description: 'User ID of the other member for DIRECT conversation',
  })
  @IsUUID()
  member_id!: string;
}

export class PaginationQueryDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  cursor?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  dir?: 'before' | 'after';
}

export class CreateGroupDto {
  @ApiProperty()
  @IsString()
  @MinLength(1)
  @MaxLength(255)
  name!: string;

  @ApiProperty({ type: [String] })
  @IsArray()
  @ArrayMinSize(2)
  @ArrayMaxSize(200)
  @IsUUID(undefined, { each: true })
  member_ids!: string[];
}

export class UpdateConversationDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(255)
  name?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  avatar_url?: string | null;
}

export class AddMembersDto {
  @ApiProperty({ type: [String] })
  @IsArray()
  @ArrayMinSize(1)
  @IsUUID(undefined, { each: true })
  member_ids!: string[];
}

export class UpdateMemberRoleDto {
  @ApiProperty({ enum: ['admin', 'member'] })
  @IsEnum(['admin', 'member'] as const)
  role!: 'admin' | 'member';
}

export class ToggleReactionDto {
  @ApiProperty()
  @IsUUID()
  message_id!: string;

  @ApiProperty()
  @IsUUID()
  conv_id!: string;

  @ApiProperty()
  @IsString()
  @MinLength(1)
  @MaxLength(10)
  emoji!: string;
}

export class PinMessageDto {
  @ApiProperty()
  @IsUUID()
  message_id!: string;
}

export class BookmarkMessageDto {
  @ApiProperty()
  @IsUUID()
  message_id!: string;
}

export enum BookmarkConversationTypeFilterDto {
  DIRECT = 'direct',
  GROUP = 'group',
}

export class GlobalBookmarkInboxQueryDto {
  @ApiPropertyOptional({
    description: 'Conversation type filter for the global bookmark inbox',
    enum: BookmarkConversationTypeFilterDto,
  })
  @IsOptional()
  @IsEnum(BookmarkConversationTypeFilterDto)
  conv_type?: BookmarkConversationTypeFilterDto;

  @ApiPropertyOptional({ description: 'Cursor for pagination' })
  @IsOptional()
  @IsString()
  cursor?: string;

  @ApiPropertyOptional({ description: 'Results per page', default: 20 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  limit?: number;
}

export class EditMessageDto {
  @ApiProperty()
  @IsString()
  @MinLength(1)
  @MaxLength(4000)
  content!: string;
}

export class CreateMessageReminderDto {
  @ApiProperty()
  @IsUUID()
  message_id!: string;

  @ApiProperty({ enum: MessageReminderScopeDto })
  @IsEnum(MessageReminderScopeDto)
  scope!: MessageReminderScopeDto;

  @ApiProperty({
    description: 'ISO datetime when the reminder should fire',
    example: '2026-04-23T08:30:00.000Z',
  })
  @IsString()
  remind_at!: string;
}

export class UpdateMessageReminderDto {
  @ApiPropertyOptional({ enum: MessageReminderScopeDto })
  @IsOptional()
  @IsEnum(MessageReminderScopeDto)
  scope?: MessageReminderScopeDto;

  @ApiPropertyOptional({
    description: 'ISO datetime when the reminder should fire',
    example: '2026-04-23T08:30:00.000Z',
  })
  @IsOptional()
  @IsString()
  remind_at?: string;
}

export class SearchMessagesDto {
  @IsString()
  @MinLength(2)
  q!: string;

  @ApiPropertyOptional({ description: 'Filter by conversation ID' })
  @IsOptional()
  @IsUUID()
  conv_id?: string;

  @ApiPropertyOptional({ description: 'Cursor for pagination' })
  @IsOptional()
  @IsString()
  cursor?: string;

  @ApiPropertyOptional({ description: 'Results per page', default: 20 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  limit?: number;
}
