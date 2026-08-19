import { IsEnum, IsNotEmpty, IsUUID } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class StartCallDto {
  @ApiProperty()
  @IsUUID()
  @IsNotEmpty()
  receiverId!: string;

  @ApiProperty({ enum: ['audio', 'video'] })
  @IsEnum(['audio', 'video'])
  type!: 'audio' | 'video';
}
