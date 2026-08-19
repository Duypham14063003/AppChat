import {
  Controller,
  Body,
  Get,
  Post,
  Patch,
  Param,
  Query,
  Req,
  HttpCode,
  HttpStatus,
  UseInterceptors,
  UploadedFile,
  BadRequestException,
  PayloadTooLargeException,
} from '@nestjs/common';
import {
  ApiTags,
  ApiBearerAuth,
  ApiOperation,
  ApiConsumes,
} from '@nestjs/swagger';
import { FileInterceptor } from '@nestjs/platform-express';
import type { Request } from 'express';
import { diskStorage } from 'multer';
import { extname, join } from 'path';
import { mkdirSync } from 'fs';
import { v4 as uuidv4 } from 'uuid';
import { AuthService } from './services/auth.service.js';
import { Roles } from './decorators/roles.decorator.js';
import { CurrentUser } from './decorators/current-user.decorator.js';
import { ListUsersDto, UpdateProfileDto } from './dto/auth.dto.js';

const AVATAR_UPLOAD_DIR = join(process.cwd(), 'uploads', 'avatars');
const ALLOWED_AVATAR_MIME_TYPES = [
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/gif',
];
const MAX_AVATAR_FILE_SIZE = 5 * 1024 * 1024; // 5MB

mkdirSync(AVATAR_UPLOAD_DIR, { recursive: true });

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
  @Patch('me')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Update current user profile' })
  async updateMyProfile(
    @CurrentUser('userId') userId: string,
    @Body() dto: UpdateProfileDto,
  ) {
    return this.authService.updateProfile(userId, dto);
  }

  @ApiBearerAuth()
  @Post('me/avatar')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Upload avatar for current user' })
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(
    FileInterceptor('file', {
      storage: diskStorage({
        destination: AVATAR_UPLOAD_DIR,
        filename: (_req, file, cb) => {
          const ext = extname(file.originalname).toLowerCase() || '.jpg';
          const filename = `${uuidv4()}-${Date.now()}${ext}`;
          cb(null, filename);
        },
      }),
      fileFilter: (_req, file, cb) => {
        if (!ALLOWED_AVATAR_MIME_TYPES.includes(file.mimetype)) {
          cb(
            new BadRequestException(
              `Invalid avatar type: ${file.mimetype}. Allowed: ${ALLOWED_AVATAR_MIME_TYPES.join(', ')}`,
            ),
            false,
          );
          return;
        }
        cb(null, true);
      },
      limits: { fileSize: MAX_AVATAR_FILE_SIZE },
    }),
  )
  async uploadMyAvatar(
    @CurrentUser('userId') userId: string,
    @UploadedFile() file: Express.Multer.File | undefined,
  ) {
    if (!file) {
      throw new BadRequestException('No avatar file provided');
    }

    if (file.size > MAX_AVATAR_FILE_SIZE) {
      throw new PayloadTooLargeException('Avatar exceeds 5MB limit');
    }

    return this.authService.updateProfile(userId, {
      avatar_url: `/uploads/avatars/${file.filename}`,
    });
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
