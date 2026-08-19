import {
  IsDateString,
  IsEnum,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  Min,
  Matches,
  IsBoolean,
  IsInt,
  ValidateIf,
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
  @IsEnum(['annual', 'sick', 'personal', 'ot', 'wfh'])
  type!: string;

  @IsDateString()
  start_date!: string;

  @IsDateString()
  end_date!: string;

  @IsOptional()
  @IsString()
  reason?: string;

  @IsOptional()
  @IsBoolean()
  is_half_day?: boolean;

  @ValidateIf((o: CreateLeaveDto) => o.is_half_day === true)
  @IsEnum(['morning', 'afternoon'])
  half_day_part?: string;

  @ValidateIf((o: CreateLeaveDto) => o.type === 'ot' || o.start_time != null)
  @IsNotEmpty()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/, { message: 'Must be HH:mm format' })
  start_time?: string;

  @ValidateIf((o: CreateLeaveDto) => o.type === 'ot' || o.end_time != null)
  @IsNotEmpty()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/, { message: 'Must be HH:mm format' })
  end_time?: string;

  @IsOptional()
  @IsNumber()
  @Type(() => Number)
  ot_time?: number;
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

export class LeaveBalanceQueryDto {
  @IsOptional()
  @IsInt()
  @Min(2000)
  @Max(9999)
  @Type(() => Number)
  year?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(12)
  @Type(() => Number)
  month?: number;
}

export class PayrollExportQueryDto {
  @Matches(/^\d{4}-(0[1-9]|1[0-2])$/, {
    message: 'Must be YYYY-MM format',
  })
  month!: string;
}

export class UpdateCompanyWfhConfigDto {
  @IsInt()
  @Min(2000)
  @Max(9999)
  @Type(() => Number)
  year!: number;

  @IsNumber()
  @Min(0)
  @Max(366)
  @Type(() => Number)
  allocated_days!: number;
}

export class UpdateUserWfhBalanceDto {
  @IsInt()
  @Min(2000)
  @Max(9999)
  @Type(() => Number)
  year!: number;

  @IsNumber()
  @Min(0)
  @Max(366)
  @Type(() => Number)
  allocated_days!: number;
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
