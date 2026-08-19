import {
  IsDateString,
  IsEnum,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  Min,
  Matches,
  IsBoolean,
  IsInt,
} from 'class-validator';
import { Type } from 'class-transformer';

// --- Attendance DTOs ---

export class CheckinDto {
  @IsDateString()
  timestamp!: string;

  @IsOptional()
  @IsNumber()
  lat?: number;

  @IsOptional()
  @IsNumber()
  lng?: number;

  @IsOptional()
  @IsString()
  device_id?: string;
}

export class CheckoutDto {
  @IsDateString()
  timestamp!: string;

  @IsOptional()
  @IsNumber()
  lat?: number;

  @IsOptional()
  @IsNumber()
  lng?: number;

  @IsOptional()
  @IsString()
  device_id?: string;
}

export class AttendanceQueryDto {
  @IsOptional()
  @IsDateString()
  from?: string;

  @IsOptional()
  @IsDateString()
  to?: string;

  @IsOptional()
  @IsUUID()
  user_id?: string;
}

// --- Leave DTOs ---

export class CreateLeaveDto {
  @IsEnum(['annual', 'sick', 'personal', 'ot'])
  type!: string;

  @IsDateString()
  start_date!: string;

  @IsDateString()
  end_date!: string;

  @IsOptional()
  @IsString()
  reason?: string;

  @IsOptional()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/, { message: 'Must be HH:mm format' })
  start_time?: string;

  @IsOptional()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/, { message: 'Must be HH:mm format' })
  end_time?: string;
}

export class RejectLeaveDto {
  @IsString()
  reject_reason!: string;
}

export class LeaveQueryDto {
  @IsOptional()
  @IsEnum(['draft', 'submitted', 'approved', 'rejected'])
  status?: string;

  @IsOptional()
  @IsUUID()
  user_id?: string;
}

// --- Payroll Config DTO ---

export class UpdatePayrollConfigDto {
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(28)
  @Type(() => Number)
  payroll_start_day?: number;

  @IsOptional()
  @IsNumber()
  @Min(1)
  @Max(24)
  @Type(() => Number)
  standard_hours_per_day?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(31)
  @Type(() => Number)
  standard_days_per_month?: number;

  @IsOptional()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/, { message: 'Must be HH:mm format' })
  work_start_time?: string;

  @IsOptional()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/, { message: 'Must be HH:mm format' })
  checkin_reminder_time?: string | null;

  @IsOptional()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/, { message: 'Must be HH:mm format' })
  checkout_reminder_time?: string | null;

  @IsOptional()
  @IsBoolean()
  auto_checkout_enabled?: boolean;

  @IsOptional()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/, { message: 'Must be HH:mm format' })
  auto_checkout_time?: string;
}
