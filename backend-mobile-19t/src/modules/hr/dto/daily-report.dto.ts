import {
  IsEnum,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsArray,
  ValidateNested,
  IsNumber,
  Min,
  Max,
  IsUUID,
  IsDateString,
} from 'class-validator';
import { Type } from 'class-transformer';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class DailyReportTaskDto {
  @ApiProperty()
  @IsNotEmpty()
  id!: string | number; // Odoo task ID

  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  name!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsArray()
  user_ids?: number[];

  @ApiPropertyOptional()
  @IsOptional()
  @IsArray()
  stage_id?: [number, string];

  @ApiPropertyOptional()
  @IsOptional()
  @IsArray()
  tag_ids?: number[];

  // Dev specific evening fields
  @ApiPropertyOptional({ enum: ['done', 'doing'] })
  @IsOptional()
  @IsEnum(['done', 'doing'])
  status?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(100)
  progress?: number;

  // QC specific evening fields
  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  @Min(0)
  qc_done?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  @Min(0)
  qc_miss?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  @Min(0)
  qc_fail?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  qc_note?: string;

  // Raw fields from Odoo needed for rewards
  @ApiPropertyOptional()
  @IsOptional()
  subtask_count?: number;

  @ApiPropertyOptional()
  @IsOptional()
  priority?: string;

  @ApiPropertyOptional()
  @IsOptional()
  date_deadline?: string | null;

  @ApiPropertyOptional()
  @IsOptional()
  description?: string | null;

  @ApiPropertyOptional()
  @IsOptional()
  parent_id?: any;

  @ApiPropertyOptional()
  @IsOptional()
  @IsArray()
  child_ids?: number[];
}

export class DailyReportProjectDto {
  @ApiProperty()
  @IsNumber()
  project_id!: number;

  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  project_name!: string;

  @ApiProperty({ type: [DailyReportTaskDto] })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => DailyReportTaskDto)
  tasks!: DailyReportTaskDto[];
}

export class CreateDailyReportDto {
  @ApiProperty({ enum: ['morning', 'evening', 'ot'] })
  @IsEnum(['morning', 'evening', 'ot'])
  report_type!: 'morning' | 'evening' | 'ot';

  @ApiProperty({ enum: ['dev', 'qc'] })
  @IsEnum(['dev', 'qc'])
  report_role!: 'dev' | 'qc';

  @ApiProperty({ type: [DailyReportProjectDto] })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => DailyReportProjectDto)
  projects!: DailyReportProjectDto[];

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  note?: string;
}

export class DailyReportResponseDto {
  @ApiProperty()
  id!: string;

  @ApiProperty()
  user_id!: string;

  @ApiPropertyOptional()
  user_name?: string;

  @ApiProperty({ enum: ['morning', 'evening', 'ot'] })
  report_type!: string;

  @ApiProperty({ enum: ['dev', 'qc'] })
  report_role!: string;

  @ApiProperty()
  report_date!: string;

  @ApiProperty({ type: [DailyReportProjectDto] })
  projects!: DailyReportProjectDto[];

  @ApiPropertyOptional()
  note?: string | null;

  @ApiPropertyOptional()
  chat_message_id?: string | null;

  @ApiProperty()
  total_points_earned!: number;

  @ApiProperty()
  created_at!: Date;
}

export class DailyReportAuditLogQueryDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  event_type?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  status?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  report_id?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  task_id?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID()
  user_id?: string;

  @ApiPropertyOptional({ minimum: 1, maximum: 100, default: 20 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number;
}

export class PublicDailyReportQueryDto {
  @ApiPropertyOptional({ enum: ['morning', 'evening', 'ot'] })
  @IsOptional()
  @IsEnum(['morning', 'evening', 'ot'])
  report_type?: 'morning' | 'evening' | 'ot';

  @ApiPropertyOptional({ enum: ['dev', 'qc'] })
  @IsOptional()
  @IsEnum(['dev', 'qc'])
  report_role?: 'dev' | 'qc';

  @ApiPropertyOptional()
  @IsOptional()
  @IsUUID()
  user_id?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  user_name?: string;

  @ApiPropertyOptional({ description: 'Inclusive start date (YYYY-MM-DD)' })
  @IsOptional()
  @IsDateString()
  from_date?: string;

  @ApiPropertyOptional({ description: 'Inclusive end date (YYYY-MM-DD)' })
  @IsOptional()
  @IsDateString()
  to_date?: string;

  @ApiPropertyOptional({ minimum: 1, default: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number;

  @ApiPropertyOptional({ minimum: 1, maximum: 500, default: 100 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(500)
  limit?: number;
}

export class PublicDailyReportResponseDto extends DailyReportResponseDto {
  @ApiProperty()
  declare user_name: string;

  @ApiPropertyOptional()
  updated_at?: Date;
}

export class PublicDailyReportListResponseDto {
  @ApiProperty({ type: [PublicDailyReportResponseDto] })
  items!: PublicDailyReportResponseDto[];

  @ApiProperty()
  total!: number;

  @ApiProperty()
  page!: number;

  @ApiProperty()
  limit!: number;

  @ApiProperty()
  has_more!: boolean;
}
