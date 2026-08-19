import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsDateString,
  IsEnum,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  IsUrl,
  IsUUID,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';
import {
  POC_OUTCOMES,
  POC_PRIORITIES,
  POC_PRODUCT_TYPES,
  POC_STATUSES,
  type PocOutcome,
  type PocPriority,
  type PocProductType,
  type PocStatus,
} from '../poc.constants.js';

export class CreatePocDto {
  @IsString() @MinLength(2) @MaxLength(255) customer_name!: string;
  @IsString() @MinLength(2) @MaxLength(255) title!: string;
  @IsString() @MinLength(2) @MaxLength(10000) requirement!: string;
  @IsEnum(POC_PRODUCT_TYPES) product_type!: PocProductType;
  @IsOptional() @IsEnum(POC_PRIORITIES) priority?: PocPriority;
  @IsDateString() demo_at!: string;
  @IsOptional() @IsUUID() working_conversation_id?: string;
  @IsOptional() @IsUUID() source_message_id?: string;
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(20)
  @IsUrl({}, { each: true })
  reference_links?: string[];
}

export class VersionedPocDto {
  @IsInt() @Min(1) @Type(() => Number) version!: number;
}

export class AssignPocDto extends VersionedPocDto {
  @IsUUID() developer_user_id!: string;
  @IsDateString() planned_start_at!: string;
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.25)
  @Max(10000)
  @Type(() => Number)
  estimated_hours!: number;
  @IsOptional() @IsDateString() demo_at?: string;
}

export class UpdatePocPlanDto extends VersionedPocDto {
  @IsOptional() @IsUUID() developer_user_id?: string;
  @IsOptional() @IsDateString() planned_start_at?: string;
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.25)
  @Max(10000)
  @Type(() => Number)
  estimated_hours?: number;
  @IsOptional() @IsDateString() demo_at?: string;
  @IsOptional() @IsUrl() @MaxLength(1000) poc_url?: string;
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(20)
  @IsUrl({}, { each: true })
  reference_links?: string[];
  @IsOptional() @IsUUID() working_conversation_id?: string;
}

export class TransitionPocDto extends VersionedPocDto {
  @IsEnum(POC_STATUSES) status!: PocStatus;
  @IsOptional() @IsEnum(POC_OUTCOMES) outcome?: PocOutcome;
  @IsOptional() @IsDateString() demo_at?: string;
  @IsOptional() @IsDateString() planned_start_at?: string;
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.25)
  @Max(10000)
  @Type(() => Number)
  estimated_hours?: number;
  @IsOptional() @IsString() @MaxLength(2000) cancel_reason?: string;
}

export class PocListQueryDto {
  @IsOptional()
  @IsEnum(['all', 'my_requests', 'my_pocs', 'unassigned', 'week'])
  mode: 'all' | 'my_requests' | 'my_pocs' | 'unassigned' | 'week' = 'all';
  @IsOptional() @IsEnum(POC_STATUSES) status?: PocStatus;
  @IsOptional() @IsUUID() developer_user_id?: string;
  @IsOptional() @IsUUID() sale_user_id?: string;
  @IsOptional() @IsEnum(POC_PRIORITIES) priority?: PocPriority;
  @IsOptional() @IsString() @MaxLength(200) search?: string;
  @IsOptional() @IsDateString() week?: string;
  @IsOptional() @IsInt() @Min(1) @Type(() => Number) page = 1;
  @IsOptional() @IsInt() @Min(1) @Max(100) @Type(() => Number) limit = 20;
}

export class CapacityQueryDto {
  @IsDateString() week!: string;
}

export class CapacityPreviewDto {
  @IsDateString() planned_start_at!: string;
  @IsDateString() demo_at!: string;
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.25)
  @Max(10000)
  @Type(() => Number)
  estimated_hours!: number;
  @IsOptional() @IsUUID() exclude_poc_id?: string;
}

export class WeeklyReportQueryDto {
  @IsDateString() week!: string;
}
