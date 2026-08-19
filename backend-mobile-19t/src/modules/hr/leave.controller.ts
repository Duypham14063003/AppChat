import {
  Controller,
  Post,
  Get,
  Patch,
  Body,
  Param,
  Query,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import { Roles } from '../auth/decorators/roles.decorator.js';
import { LeaveService, type LeaveListItem } from './services/leave.service.js';
import {
  CreateLeaveDto,
  CancelLeaveDto,
  RejectLeaveDto,
  LeaveQueryDto,
  LeaveBalanceQueryDto,
  UpdateCompanyWfhConfigDto,
  UpdateUserWfhBalanceDto,
} from './dto/hr.dto.js';

@ApiTags('HR - Leave')
@ApiBearerAuth()
@Controller('hr/leaves')
export class LeaveController {
  constructor(private readonly leaveService: LeaveService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create leave request (draft)' })
  async create(
    @CurrentUser('userId') userId: string,
    @Body() dto: CreateLeaveDto,
  ) {
    return this.leaveService.create(userId, dto);
  }

  @Get()
  @ApiOperation({ summary: 'List leave requests' })
  async list(
    @CurrentUser('userId') userId: string,
    @CurrentUser('roles') roles: string[],
    @Query() query: LeaveQueryDto,
  ): Promise<{ otHours: number; leaves: LeaveListItem[] }> {
    return this.leaveService.getLeaves(
      userId,
      query.status,
      query.user_id,
      roles,
      query.year,
      query.month,
    );
  }

  @Get('balance')
  @ApiOperation({ summary: 'Get current user yearly paid leave balance' })
  async getBalance(
    @CurrentUser('userId') userId: string,
    @Query() query: LeaveBalanceQueryDto,
  ) {
    return this.leaveService.getLeaveBalance(userId, query.year);
  }

  @Get('wfh-balance')
  @ApiOperation({ summary: 'Get current user yearly WFH balance' })
  async getWfhBalance(
    @CurrentUser('userId') userId: string,
    @Query() query: LeaveBalanceQueryDto,
  ) {
    return this.leaveService.getWfhBalance(userId, query.year);
  }

  @Patch(':id/submit')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Submit leave request for approval' })
  async submit(
    @CurrentUser('userId') userId: string,
    @Param('id') leaveId: string,
  ) {
    return this.leaveService.submit(userId, leaveId);
  }

  @Roles('admin', 'manager')
  @Patch(':id/approve')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Approve leave request (Admin/Manager)' })
  async approve(
    @CurrentUser('userId') adminUserId: string,
    @Param('id') leaveId: string,
  ) {
    return this.leaveService.approve(adminUserId, leaveId);
  }

  @Roles('admin', 'manager')
  @Patch(':id/reject')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Reject leave request (Admin/Manager)' })
  async reject(
    @CurrentUser('userId') adminUserId: string,
    @Param('id') leaveId: string,
    @Body() dto: RejectLeaveDto,
  ) {
    return this.leaveService.reject(adminUserId, leaveId, dto.reject_reason);
  }

  @Roles('admin', 'manager')
  @Patch(':id/cancel')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Cancel an approved leave request (Admin/Manager)' })
  async cancel(
    @CurrentUser('userId') actorUserId: string,
    @Param('id') leaveId: string,
    @Body() dto: CancelLeaveDto,
  ) {
    return this.leaveService.cancelApprovedLeave(
      actorUserId,
      leaveId,
      dto.reason,
    );
  }

  @Roles('admin')
  @Get('admin/wfh-config')
  @ApiOperation({ summary: 'Get company yearly WFH config (Admin)' })
  async getCompanyWfhConfig(@Query() query: LeaveBalanceQueryDto) {
    return this.leaveService.getCompanyWfhConfig(query.year);
  }

  @Roles('admin')
  @Patch('admin/wfh-config')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Create or update company yearly WFH config (Admin)',
  })
  async updateCompanyWfhConfig(@Body() dto: UpdateCompanyWfhConfigDto) {
    return this.leaveService.updateCompanyWfhConfig(
      dto.year,
      dto.allocated_days,
    );
  }

  @Roles('admin')
  @Get('admin/users/:userId/wfh-balance')
  @ApiOperation({ summary: 'Get user yearly WFH balance (Admin)' })
  async getUserWfhBalance(
    @Param('userId') userId: string,
    @Query() query: LeaveBalanceQueryDto,
  ) {
    return this.leaveService.getUserWfhBalance(userId, query.year);
  }

  @Roles('admin')
  @Patch('admin/users/:userId/wfh-balance')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Update user yearly WFH balance (Admin)' })
  async updateUserWfhBalance(
    @Param('userId') userId: string,
    @Body() dto: UpdateUserWfhBalanceDto,
  ) {
    return this.leaveService.updateUserWfhBalance(
      userId,
      dto.year,
      dto.allocated_days,
    );
  }
}
