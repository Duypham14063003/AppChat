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
  IsDateString,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';

export enum MessageType {
  TEXT = 'text',
  IMAGE = 'image',
  ALBUM = 'album',
  FILE = 'file',
  VOICE = 'voice',
  VIDEO = 'video',
  SYSTEM = 'system',
}

export interface FileMessageMetadata {
  url: string;
  originalName: string;
  mimeType: string;
  size: number;
}

export interface BlindIndexPayloadV1 {
  version: number;
  algo: string;
  tokens: string[];
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
  @ApiPropertyOptional({
    description:
      'For file messages, metadata must include url, originalName, mimeType, and size.',
    example: {
      url: '/uploads/chat/123-report.pdf',
      originalName: 'report.pdf',
      mimeType: 'application/pdf',
      size: 153248,
    },
  })
  metadata?: Record<string, unknown>;

  @ApiPropertyOptional({
    description:
      'Opaque blind index hashes generated on the client for encrypted search.',
  })
  @IsOptional()
  @IsObject()
  blind_index_v1?: BlindIndexPayloadV1;
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

export class GetGlobalBookmarksQueryDto {
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

  @ApiPropertyOptional({ description: 'Filter by conversation ID' })
  @IsOptional()
  @IsUUID()
  conv_id?: string;

  @ApiPropertyOptional({
    description: 'Filter by message type',
    enum: MessageType,
  })
  @IsOptional()
  @IsEnum(MessageType)
  type?: MessageType;
}

export class GlobalBookmarkItemDto {
  @ApiProperty()
  message_id!: string;

  @ApiProperty()
  conv_id!: string;

  @ApiProperty()
  conv_type!: string;

  @ApiProperty()
  conv_name!: string;

  @ApiPropertyOptional({ nullable: true })
  conv_avatar_url!: string | null;

  @ApiProperty()
  sender_id!: string;

  @ApiProperty()
  sender_name!: string;

  @ApiProperty()
  message_type!: string;

  @ApiPropertyOptional({ nullable: true })
  message_content!: string | null;

  @ApiProperty()
  message_created_at!: string;

  @ApiProperty()
  marked_at!: string;
}

export class GlobalBookmarksResponseDto {
  @ApiProperty({ type: [GlobalBookmarkItemDto] })
  items!: GlobalBookmarkItemDto[];

  @ApiPropertyOptional({ nullable: true })
  next_cursor!: string | null;
}

export class CreateMessageReminderDto {
  @ApiProperty()
  @IsUUID()
  message_id!: string;

  @ApiProperty({ enum: ['self', 'everyone'] })
  @IsEnum(['self', 'everyone'] as const)
  scope!: 'self' | 'everyone';

  @ApiProperty()
  @IsDateString()
  remind_at!: string;
}

export class UpdateMessageReminderDto {
  @ApiPropertyOptional({ enum: ['self', 'everyone'] })
  @IsOptional()
  @IsEnum(['self', 'everyone'] as const)
  scope?: 'self' | 'everyone';

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  remind_at?: string;
}

export class SearchMessagesDto {
  @ApiPropertyOptional({
    description: 'Plaintext query for legacy search mode',
  })
  @IsOptional()
  @IsString()
  @MinLength(2)
  q?: string;

  @ApiPropertyOptional({ description: 'Filter by conversation ID' })
  @IsOptional()
  @IsUUID()
  conv_id?: string;

  @ApiPropertyOptional({
    type: [String],
    description:
      'Opaque blind index hashes for encrypted room-scoped search mode',
  })
  @IsOptional()
  @Transform(({ value }) =>
    Array.isArray(value) ? value : value == null ? undefined : [value],
  )
  @IsArray()
  @ArrayMinSize(1)
  @IsString({ each: true })
  q_hashes?: string[];

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
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(5000)
  content?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsObject()
  metadata?: Record<string, unknown>;

  @ApiPropertyOptional({
    description:
      'Opaque blind index hashes generated on the client for encrypted search.',
  })
  @IsOptional()
  @IsObject()
  blind_index_v1?: BlindIndexPayloadV1;
}

export class RecallMessageDto {
  @ApiPropertyOptional({ description: 'Reason for recalling (optional)' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;
}

export class MessageSeenByMemberDto {
  @ApiProperty()
  user_id!: string;

  @ApiProperty()
  name!: string;

  @ApiPropertyOptional({ nullable: true })
  avatar_url!: string | null;

  @ApiPropertyOptional({ nullable: true })
  seen_at!: string | null;
}

export class MessageSeenByResponseDto {
  @ApiProperty()
  conv_id!: string;

  @ApiProperty()
  message_id!: string;

  @ApiProperty({ type: [MessageSeenByMemberDto] })
  seen_by!: MessageSeenByMemberDto[];
}

// ===== Group Info Assets DTOs =====

export class GetConversationMediaQueryDto {
  @ApiPropertyOptional({ description: 'Cursor for pagination' })
  @IsOptional()
  @IsString()
  cursor?: string;

  @ApiPropertyOptional({ description: 'Results per page', default: 20 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number;

  @ApiPropertyOptional({
    description: 'Filter by media type',
    enum: ['all', 'image', 'video'],
    default: 'all',
  })
  @IsOptional()
  @IsEnum(['all', 'image', 'video'] as const)
  type?: 'all' | 'image' | 'video';
}

export class GetConversationFilesQueryDto {
  @ApiPropertyOptional({ description: 'Cursor for pagination' })
  @IsOptional()
  @IsString()
  cursor?: string;

  @ApiPropertyOptional({ description: 'Results per page', default: 20 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number;
}

export class GetConversationLinksQueryDto {
  @ApiPropertyOptional({ description: 'Cursor for pagination' })
  @IsOptional()
  @IsString()
  cursor?: string;

  @ApiPropertyOptional({ description: 'Results per page', default: 20 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number;
}

export class MediaItemDto {
  @ApiProperty()
  message_id!: string;

  @ApiProperty()
  conv_id!: string;

  @ApiProperty()
  sender_id!: string;

  @ApiProperty()
  sender_name!: string;

  @ApiProperty({ enum: MessageType })
  type!: string;

  @ApiPropertyOptional({ nullable: true })
  content!: string | null;

  @ApiProperty()
  created_at!: string;

  @ApiProperty()
  metadata!: Record<string, unknown>;
}

export class ConversationMediaResponseDto {
  @ApiProperty({ type: [MediaItemDto] })
  items!: MediaItemDto[];

  @ApiPropertyOptional({ nullable: true })
  next_cursor!: string | null;

  @ApiProperty()
  has_more!: boolean;
}

export class FileItemDto {
  @ApiProperty()
  message_id!: string;

  @ApiProperty()
  conv_id!: string;

  @ApiProperty()
  sender_id!: string;

  @ApiProperty()
  sender_name!: string;

  @ApiProperty()
  type!: string;

  @ApiPropertyOptional({ nullable: true })
  content!: string | null;

  @ApiProperty()
  created_at!: string;

  @ApiProperty()
  metadata!: Record<string, unknown>;
}

export class ConversationFilesResponseDto {
  @ApiProperty({ type: [FileItemDto] })
  items!: FileItemDto[];

  @ApiPropertyOptional({ nullable: true })
  next_cursor!: string | null;

  @ApiProperty()
  has_more!: boolean;
}

export class LinkItemDto {
  @ApiProperty()
  message_id!: string;

  @ApiProperty()
  conv_id!: string;

  @ApiProperty()
  sender_id!: string;

  @ApiProperty()
  sender_name!: string;

  @ApiProperty()
  type!: string;

  @ApiPropertyOptional({ nullable: true })
  content!: string | null;

  @ApiProperty()
  created_at!: string;

  @ApiProperty()
  metadata!: Record<string, unknown>;

  @ApiProperty({ type: [String] })
  links!: string[];
}

export class ConversationLinksResponseDto {
  @ApiProperty({ type: [LinkItemDto] })
  items!: LinkItemDto[];

  @ApiPropertyOptional({ nullable: true })
  next_cursor!: string | null;

  @ApiProperty()
  has_more!: boolean;
}

export class ConversationAssetsSummaryDto {
  @ApiProperty()
  members_count!: number;

  @ApiProperty()
  media_count!: number;

  @ApiProperty()
  files_count!: number;

  @ApiProperty()
  links_count!: number;
}
