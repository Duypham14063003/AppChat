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
import { LeaveService } from './services/leave.service.js';
import { CreateLeaveDto, RejectLeaveDto, LeaveQueryDto } from './dto/hr.dto.js';

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
  ) {
    return this.leaveService.getLeaves(
      userId,
      query.status,
      query.user_id,
      roles,
    );
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
}
