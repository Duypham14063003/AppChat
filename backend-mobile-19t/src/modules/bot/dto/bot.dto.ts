import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsBoolean,
  IsEmail,
  IsInt,
  IsObject,
  IsOptional,
  IsString,
  IsUrl,
  IsUUID,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateIf,
} from 'class-validator';
import { Type } from 'class-transformer';

// Admin DTOs

export class CreateBotDto {
  @ApiProperty({
    description: 'Bot name',
    example: 'Notification Bot',
  })
  @IsString()
  @MinLength(1)
  @MaxLength(255)
  name!: string;

  @ApiProperty({
    description: 'Bot email (must follow pattern: bot-*@system.local)',
    example: 'bot-notifications@system.local',
  })
  @IsEmail()
  @Matches(/^bot-[a-z0-9-]+@system\.local$/, {
    message: 'Email must follow pattern: bot-*@system.local',
  })
  email!: string;

  @ApiPropertyOptional({
    description: 'Bot description',
    example: 'Sends notifications from external systems',
  })
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  description?: string;

  @ApiPropertyOptional({
    description: 'Bot avatar URL',
    example: 'https://example.com/bot-avatar.png',
  })
  @IsOptional()
  @IsUrl()
  avatar_url?: string;
}

export class UpdateBotDto {
  @ApiPropertyOptional({
    description: 'Bot name',
    example: 'Updated Bot Name',
  })
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(255)
  name?: string;

  @ApiPropertyOptional({
    description: 'Bot description',
    example: 'Updated description',
  })
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  description?: string;

  @ApiPropertyOptional({
    description: 'Bot avatar URL',
    example: 'https://example.com/new-avatar.png',
  })
  @IsOptional()
  @IsUrl()
  avatar_url?: string;
}

export class ListBotsQueryDto {
  @ApiPropertyOptional({
    description: 'Include inactive bots',
    example: false,
  })
  @IsOptional()
  @IsBoolean()
  @Type(() => Boolean)
  include_inactive?: boolean;
}

// External API DTO

export class SendBotMessageDto {
  @ApiProperty({
    description: 'Bot ID to send message as',
    example: '12345678-1234-1234-1234-123456789012',
  })
  @IsUUID()
  bot_id!: string;

  @ApiPropertyOptional({
    description: 'Target group conversation ID (mutually exclusive with user_id)',
    example: '6998761a-f0db-4dfd-8d95-ecc23cfae783',
  })
  @IsOptional()
  @IsUUID()
  @ValidateIf((o) => !o.user_id)
  conversation_id?: string;

  @ApiPropertyOptional({
    description: 'Target user ID for direct message (mutually exclusive with conversation_id)',
    example: '87654321-4321-4321-4321-210987654321',
  })
  @IsOptional()
  @IsUUID()
  @ValidateIf((o) => !o.conversation_id)
  user_id?: string;

  @ApiProperty({
    description: 'Plain text content that the bot will send',
    example: 'Thong bao tu he thong web ngoai',
  })
  @IsString()
  @MaxLength(5000)
  content!: string;

  @ApiPropertyOptional({
    description:
      'Optional client-supplied UUID for idempotent retries. Reusing the same value avoids duplicate messages.',
    example: '550e8400-e29b-41d4-a716-446655440000',
  })
  @IsOptional()
  @IsUUID()
  external_message_id?: string;

  @ApiPropertyOptional({
    description:
      'Optional JSON metadata. Useful for mentions, links, or source-system context.',
  })
  @IsOptional()
  @IsObject()
  metadata?: Record<string, unknown>;
}

// Bot message management DTOs

export class GetBotMessagesQueryDto {
  @ApiProperty({
    description: 'Bot ID',
    example: '12345678-1234-1234-1234-123456789012',
  })
  @IsUUID()
  bot_id!: string;

  @ApiPropertyOptional({
    description: 'Filter by conversation ID',
    example: '87654321-4321-4321-4321-210987654321',
  })
  @IsOptional()
  @IsUUID()
  conversation_id?: string;

  @ApiPropertyOptional({
    description: 'Page number (starts from 1)',
    example: 1,
    default: 1,
  })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Type(() => Number)
  page?: number;

  @ApiPropertyOptional({
    description: 'Number of messages per page',
    example: 20,
    default: 20,
  })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(100)
  @Type(() => Number)
  limit?: number;
}

export class UpdateBotMessageDto {
  @ApiProperty({
    description: 'Bot ID that owns the message',
    example: '12345678-1234-1234-1234-123456789012',
  })
  @IsUUID()
  bot_id!: string;

  @ApiProperty({
    description: 'Message ID to update',
    example: 'abcdef12-3456-7890-abcd-ef1234567890',
  })
  @IsUUID()
  message_id!: string;

  @ApiProperty({
    description: 'New message content',
    example: 'Updated message content',
  })
  @IsString()
  @MaxLength(5000)
  content!: string;

  @ApiPropertyOptional({
    description: 'Updated metadata',
  })
  @IsOptional()
  @IsObject()
  metadata?: Record<string, unknown>;
}

export class DeleteBotMessageDto {
  @ApiProperty({
    description: 'Bot ID that owns the message',
    example: '12345678-1234-1234-1234-123456789012',
  })
  @IsUUID()
  bot_id!: string;

  @ApiProperty({
    description: 'Message ID to delete',
    example: 'abcdef12-3456-7890-abcd-ef1234567890',
  })
  @IsUUID()
  message_id!: string;
}
