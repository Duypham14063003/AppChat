import {
  Controller,
  Get,
  Patch,
  Body,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { Roles } from '../auth/decorators/roles.decorator.js';
import { PayrollConfigService } from './services/payroll-config.service.js';
import { UpdatePayrollConfigDto } from './dto/hr.dto.js';

@ApiTags('HR - Config')
@ApiBearerAuth()
@Controller('hr/config')
export class PayrollConfigController {
  constructor(private readonly configService: PayrollConfigService) {}

  @Get()
  @ApiOperation({ summary: 'Get payroll config' })
  async getConfig() {
    return this.configService.getConfig();
  }

  @Roles('admin')
  @Patch()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Update payroll config (Admin only)' })
  async updateConfig(@Body() dto: UpdatePayrollConfigDto) {
    return this.configService.updateConfig(dto);
  }
}
