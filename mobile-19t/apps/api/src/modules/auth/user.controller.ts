import {
  Controller,
  Get,
  Patch,
  Param,
  Query,
  Req,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import type { Request } from 'express';
import { AuthService } from './services/auth.service.js';
import { Roles } from './decorators/roles.decorator.js';
import { CurrentUser } from './decorators/current-user.decorator.js';
import { ListUsersDto } from './dto/auth.dto.js';

@ApiTags('Users')
@Controller('users')
export class UserController {
  constructor(private readonly authService: AuthService) {}

  @ApiBearerAuth()
  @Get()
  @ApiOperation({ summary: 'List active users for contact selection' })
  async listUsers(
    @CurrentUser('userId') currentUserId: string,
    @Query() query: ListUsersDto,
  ) {
    return this.authService.listUsers(
      currentUserId,
      query.search,
      query.cursor,
      query.limit ?? 50,
    );
  }

  @ApiBearerAuth()
  @Roles('admin')
  @Patch(':id/deactivate')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Deactivate user account (Admin only)' })
  async deactivateUser(
    @Param('id') targetUserId: string,
    @CurrentUser('userId') adminUserId: string,
    @Req() req: Request,
  ) {
    const ip = req.ip || req.socket.remoteAddress;
    await this.authService.deactivateUser(targetUserId, adminUserId, ip);
    return { message: 'User deactivated' };
  }
}
