import {
  BadRequestException,
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import {
  AssignPocDto,
  CapacityPreviewDto,
  CapacityQueryDto,
  CreatePocDto,
  PocListQueryDto,
  TransitionPocDto,
  UpdatePocPlanDto,
  WeeklyReportQueryDto,
} from './dto/poc.dto.js';
import { PocCalendarService } from './services/poc-calendar.service.js';
import { PocCapacityService } from './services/poc-capacity.service.js';
import { PocService } from './services/poc.service.js';
import { PocWeeklyReportService } from './services/poc-weekly-report.service.js';

@ApiTags('PoC Coordination')
@ApiBearerAuth()
@Controller('pocs')
export class PocController {
  constructor(
    private readonly pocs: PocService,
    private readonly capacity: PocCapacityService,
    private readonly calendar: PocCalendarService,
    private readonly weekly: PocWeeklyReportService,
  ) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create a PoC request' })
  create(@CurrentUser('userId') userId: string, @Body() dto: CreatePocDto) {
    return this.pocs.create(userId, dto);
  }

  @Get()
  @ApiOperation({ summary: 'List and filter PoCs' })
  list(@CurrentUser('userId') userId: string, @Query() query: PocListQueryDto) {
    return this.pocs.list(userId, query);
  }

  @Get('capacity')
  @ApiOperation({ summary: 'Get planned PoC capacity for a week' })
  capacityView(@Query() query: CapacityQueryDto) {
    return this.capacity.getWeek(query.week);
  }

  @Post('capacity/preview')
  @ApiOperation({ summary: 'Preview candidate developer capacity' })
  async capacityPreview(@Body() dto: CapacityPreviewDto) {
    const start = new Date(dto.planned_start_at);
    const demo = new Date(dto.demo_at);
    if (start >= demo) {
      throw new BadRequestException('planned_start_at must be before demo_at');
    }
    return this.capacity.preview({
      week: dto.planned_start_at,
      plannedStartAt: start,
      demoAt: demo,
      estimatedHours: dto.estimated_hours,
      excludePocId: dto.exclude_poc_id,
    });
  }

  @Get('weekly-report')
  @ApiOperation({ summary: 'View weekly PoC report' })
  weeklyReport(@Query() query: WeeklyReportQueryDto) {
    return this.weekly.view(query.week);
  }

  @Post('weekly-report/publish')
  @ApiOperation({ summary: 'Create or refresh stable weekly PoC report' })
  publishWeeklyReport(@Query() query: WeeklyReportQueryDto) {
    return this.weekly.publish(query.week);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get PoC detail and history' })
  detail(@CurrentUser('userId') userId: string, @Param('id') id: string) {
    return this.pocs.detail(userId, id);
  }

  @Patch(':id/assignment')
  @ApiOperation({ summary: 'Assign or reassign one primary developer' })
  assign(
    @CurrentUser('userId') userId: string,
    @Param('id') id: string,
    @Body() dto: AssignPocDto,
  ) {
    return this.pocs.assign(userId, id, dto);
  }

  @Patch(':id/plan')
  @ApiOperation({ summary: 'Update PoC plan, links, or working conversation' })
  updatePlan(
    @CurrentUser('userId') userId: string,
    @Param('id') id: string,
    @Body() dto: UpdatePocPlanDto,
  ) {
    return this.pocs.updatePlan(userId, id, dto);
  }

  @Patch(':id/status')
  @ApiOperation({ summary: 'Apply a valid PoC lifecycle transition' })
  transition(
    @CurrentUser('userId') userId: string,
    @Param('id') id: string,
    @Body() dto: TransitionPocDto,
  ) {
    return this.pocs.transition(userId, id, dto);
  }
}
