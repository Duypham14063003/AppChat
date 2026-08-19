import {
  Controller,
  Get,
  NotFoundException,
  Param,
  Query,
} from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { Public } from '../auth/decorators/public.decorator.js';
import { DailyReportService } from './services/daily-report.service.js';
import { PublicDailyReportQueryDto } from './dto/daily-report.dto.js';

@ApiTags('Public - Daily Reports')
@Public()
@Controller('public/daily-reports')
export class PublicDailyReportController {
  constructor(private readonly dailyReportService: DailyReportService) {}

  @Get()
  @ApiOperation({ summary: 'List public historical daily reports' })
  async listReports(@Query() query: PublicDailyReportQueryDto) {
    return this.dailyReportService.listPublicReports(query);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get a public daily report by ID' })
  async getReport(@Param('id') id: string) {
    const report = await this.dailyReportService.getPublicReportById(id);
    if (!report) {
      throw new NotFoundException('Daily report not found');
    }

    return report;
  }
}
