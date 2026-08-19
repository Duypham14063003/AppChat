import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsDateString,
  IsEmail,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  Min,
} from 'class-validator';

export class EmployeeListQueryDto {
  @IsOptional() @IsString() search?: string;
  @IsOptional() @IsString() department?: string;
  @IsOptional() @IsString() job_title?: string;
  @IsOptional() @IsBoolean() @Type(() => Boolean) is_active?: boolean;
  @IsOptional() @IsString() employment_status?: string;
  @IsOptional() @IsInt() @Min(1) @Type(() => Number) page = 1;
  @IsOptional() @IsInt() @Min(1) @Max(100) @Type(() => Number) limit = 20;
}

export class UpdateEmployeeProfileDto {
  @IsOptional() @IsDateString() date_of_birth?: string;
  @IsOptional() @IsString() gender?: string;
  @IsOptional() @IsString() identity_number?: string;
  @IsOptional() @IsDateString() identity_issued_date?: string;
  @IsOptional() @IsString() identity_issued_place?: string;
  @IsOptional() @IsString() permanent_address?: string;
  @IsOptional() @IsString() current_address?: string;
  @IsOptional() @IsString() personal_phone?: string;
  @IsOptional() @IsEmail() personal_email?: string;
  @IsOptional() @IsString() emergency_contact_name?: string;
  @IsOptional() @IsString() emergency_contact_phone?: string;
  @IsOptional() @IsString() emergency_contact_relationship?: string;
  @IsOptional() @IsString() marital_status?: string;
  @IsOptional() @IsString() tax_code?: string;
  @IsOptional() @IsString() bank_account_number?: string;
  @IsOptional() @IsString() bank_name?: string;
  @IsOptional() @IsString() bank_code?: string;
  @IsOptional() @IsString() bank_account_name?: string;
  @IsOptional() @IsEnum(['generated', 'uploaded']) bank_qr_source?:
    | 'generated'
    | 'uploaded';
  @IsOptional() @IsDateString() joined_at?: string;
}

export class CreateEmployeeContractDto {
  @IsUUID() user_id!: string;
  @IsEnum(['internship', 'probation', 'official', 'temporary']) type!:
    | 'internship'
    | 'probation'
    | 'official'
    | 'temporary';
  @IsOptional() @IsDateString() signed_date?: string;
  @IsDateString() start_date!: string;
  @IsOptional() @IsDateString() end_date?: string;
  @IsOptional() @IsEnum(['draft', 'active']) status?: 'draft' | 'active';
  @IsOptional() @IsString() notes?: string;
}

export class UpdateEmployeeContractDto {
  @IsOptional()
  @IsEnum(['internship', 'probation', 'official', 'temporary'])
  type?: 'internship' | 'probation' | 'official' | 'temporary';
  @IsOptional() @IsDateString() signed_date?: string;
  @IsOptional() @IsDateString() start_date?: string;
  @IsOptional() @IsDateString() end_date?: string;
  @IsOptional() @IsEnum(['draft', 'active', 'expired', 'terminated']) status?:
    | 'draft'
    | 'active'
    | 'expired'
    | 'terminated';
  @IsOptional() @IsString() notes?: string;
}

export class RenewEmployeeContractDto extends CreateEmployeeContractDto {}
