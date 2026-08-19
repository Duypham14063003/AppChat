import { Controller, Get, Query, Res, StreamableFile } from '@nestjs/common';
import type { Response } from 'express';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import { Roles } from '../auth/decorators/roles.decorator.js';
import { PayrollExportQueryDto, PayrollSummaryQueryDto } from './dto/hr.dto.js';
import { PayrollExportService } from './services/payroll-export.service.js';
import { EMPLOYEE_MANAGEMENT_ROLES } from './hr-role.utils.js';

@ApiTags('HR - Reports')
@ApiBearerAuth()
@Controller('hr/reports')
export class PayrollExportController {
  constructor(private readonly payrollExportService: PayrollExportService) {}

  @Roles(...EMPLOYEE_MANAGEMENT_ROLES)
  @Get('payroll-summary')
  @ApiOperation({ summary: 'Get an employee payroll attendance summary' })
  async getEmployeePayrollSummary(
    @CurrentUser('userId') userId: string,
    @CurrentUser('roles') roles: string[],
    @Query() query: PayrollSummaryQueryDto,
  ) {
    return this.payrollExportService.getEmployeePayrollSummary(
      userId,
      roles,
      query.month,
      query.user_id,
    );
  }

  @Roles('admin', 'manager')
  @Get('payroll-export')
  @ApiOperation({ summary: 'Download payroll workbook export (.xlsx)' })
  async exportPayrollWorkbook(
    @CurrentUser('userId') userId: string,
    @CurrentUser('roles') roles: string[],
    @Query() query: PayrollExportQueryDto,
    @Res({ passthrough: true }) response: Response,
  ): Promise<StreamableFile> {
    const result = await this.payrollExportService.exportPayrollWorkbook(
      userId,
      roles,
      query.month,
    );

    response.setHeader('Content-Type', result.contentType);
    response.setHeader(
      'Content-Disposition',
      `attachment; filename="${result.filename}"`,
    );

    return new StreamableFile(result.buffer);
  }
}
