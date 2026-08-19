import {
  Controller,
  Get,
  Patch,
  Body,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import { PayrollConfigService } from './services/payroll-config.service.js';
import { UpdatePayrollConfigDto } from './dto/hr.dto.js';

@ApiTags('HR - Config')
@ApiBearerAuth()
@Controller('hr/config')
export class PayrollConfigController {
  constructor(private readonly configService: PayrollConfigService) {}

  @Get()
  @ApiOperation({ summary: 'Get payroll config' })
  async getConfig(@CurrentUser('userId') userId: string) {
    return this.configService.getConfig(userId);
  }

  @Get('start-day')
  @ApiOperation({ summary: 'Get payroll start day only' })
  async getStartDay(@CurrentUser('userId') userId: string) {
    return this.configService.getPayrollConfigStartDay(userId);
  }

  @Patch()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Update current user payroll config' })
  async updateConfig(
    @CurrentUser('userId') userId: string,
    @Body() dto: UpdatePayrollConfigDto,
  ) {
    return this.configService.updateConfig(userId, dto);
  }
}
