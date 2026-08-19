import {
  Controller,
  Post,
  Get,
  Body,
  Query,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import { AttendanceService } from './services/attendance.service.js';
import { CheckinDto, CheckoutDto, AttendanceQueryDto } from './dto/hr.dto.js';

@ApiTags('HR - Attendance')
@ApiBearerAuth()
@Controller('hr/attendance')
export class AttendanceController {
  constructor(private readonly attendanceService: AttendanceService) {}

  @Post('checkin')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Checkin with GPS and timestamp' })
  async checkin(
    @CurrentUser('userId') userId: string,
    @Body() dto: CheckinDto,
  ) {
    return this.attendanceService.checkin(userId, dto);
  }

  @Post('checkout')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Checkout with GPS and timestamp' })
  async checkout(
    @CurrentUser('userId') userId: string,
    @Body() dto: CheckoutDto,
  ) {
    return this.attendanceService.checkout(userId, dto);
  }

  @Get()
  @ApiOperation({ summary: 'Get attendance history' })
  async getHistory(
    @CurrentUser('userId') userId: string,
    @CurrentUser('roles') roles: string[],
    @Query() query: AttendanceQueryDto,
  ) {
    return this.attendanceService.getHistory(
      userId,
      query.from,
      query.to,
      query.user_id,
      roles,
    );
  }

  @Get('summary')
  @ApiOperation({ summary: 'Get attendance summary for date range' })
  async getSummary(
    @CurrentUser('userId') userId: string,
    @Query('from') from: string,
    @Query('to') to: string,
  ) {
    return this.attendanceService.getSummary(userId, from, to);
  }

  @Get('today')
  @ApiOperation({ summary: 'Get today attendance status' })
  async getTodayStatus(@CurrentUser('userId') userId: string) {
    return this.attendanceService.getTodayStatus(userId);
  }
}
