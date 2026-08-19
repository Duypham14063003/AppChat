import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  Query,
  PayloadTooLargeException,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiConsumes,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import { FileInterceptor } from '@nestjs/platform-express';
import { mkdirSync } from 'fs';
import { diskStorage } from 'multer';
import { extname, join } from 'path';
import { v4 as uuidv4 } from 'uuid';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import { Roles } from '../auth/decorators/roles.decorator.js';
import { Public } from '../auth/decorators/public.decorator.js';
import { RewardsService } from './rewards.service.js';
import {
  AdminAdjustPointsDto,
  AdminGrantPointsDto,
  CreatePointRuleDto,
  CreateRewardItemDto,
  RedemptionListQueryDto,
  RewardCatalogQueryDto,
  UpdatePointRuleDto,
  UpdateRedemptionStatusDto,
  UpdateRewardItemDto,
  CreateTaskTagConfigDto,
  UpdateTaskTagConfigDto,
  CreateJobTitleMultiplierDto,
  UpdateJobTitleMultiplierDto,
  CreateInternalRoleDto,
  UpdateInternalRoleDto,
  CreateJobTitleMappingDto,
  UpdateJobTitleMappingDto,
} from './dto/rewards.dto.js';

const REWARD_UPLOAD_DIR = join(process.cwd(), 'uploads', 'rewards');
const ALLOWED_REWARD_IMAGE_MIME_TYPES = [
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/gif',
];
const MAX_REWARD_IMAGE_FILE_SIZE = 5 * 1024 * 1024; // 5MB

mkdirSync(REWARD_UPLOAD_DIR, { recursive: true });

@ApiTags('Rewards - Admin')
@ApiBearerAuth()
@Roles('admin')
@Controller('rewards/admin')
export class RewardsAdminController {
  constructor(private readonly rewardsService: RewardsService) {}

  @Post('adjustments')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Manually grant or deduct points for a user' })
  async adjustPoints(
    @CurrentUser('userId') adminUserId: string,
    @Body() dto: AdminAdjustPointsDto,
  ) {
    return this.rewardsService.adjustPoints(adminUserId, dto);
  }

  @Post('points/grant')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Grant points to a user' })
  async grantPoints(
    @CurrentUser('userId') adminUserId: string,
    @Body() dto: AdminGrantPointsDto,
  ) {
    return this.rewardsService.grantPoints(adminUserId, dto);
  }

  @Post('points/reset')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary:
      'Reset reward points and point-related records for all non-admin users',
  })
  async resetPoints(@CurrentUser('userId') adminUserId: string) {
    return this.rewardsService.resetPoints(adminUserId);
  }

  @Get('employees')
  @ApiOperation({ summary: 'List employees with id and name only' })
  async listEmployees() {
    return this.rewardsService.listEmployees();
  }

  @Get('rules')
  @ApiOperation({ summary: 'List point rules' })
  async listRules() {
    return this.rewardsService.listPointRules();
  }

  @Post('rules')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create a point rule' })
  async createRule(
    @CurrentUser('userId') adminUserId: string,
    @Body() dto: CreatePointRuleDto,
  ) {
    return this.rewardsService.createPointRule(adminUserId, dto);
  }

  @Patch('rules/:id')
  @ApiOperation({ summary: 'Update a point rule' })
  async updateRule(@Param('id') id: string, @Body() dto: UpdatePointRuleDto) {
    return this.rewardsService.updatePointRule(id, dto);
  }

  @Get('items')
  @ApiOperation({ summary: 'List reward items for admin management' })
  async listItems(@Query() query: RewardCatalogQueryDto) {
    return this.rewardsService.listRewardItems(query, true);
  }

  @Post('items')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create a reward item' })
  async createItem(
    @CurrentUser('userId') adminUserId: string,
    @Body() dto: CreateRewardItemDto,
  ) {
    return this.rewardsService.createRewardItem(adminUserId, dto);
  }

  @Post('items/upload')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Upload reward item image' })
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(
    FileInterceptor('file', {
      storage: diskStorage({
        destination: REWARD_UPLOAD_DIR,
        filename: (_req, file, cb) => {
          const ext = extname(file.originalname).toLowerCase() || '.jpg';
          const filename = `${uuidv4()}-${Date.now()}${ext}`;
          cb(null, filename);
        },
      }),
      fileFilter: (_req, file, cb) => {
        if (!ALLOWED_REWARD_IMAGE_MIME_TYPES.includes(file.mimetype)) {
          cb(
            new BadRequestException(
              `Invalid reward image type: ${file.mimetype}. Allowed: ${ALLOWED_REWARD_IMAGE_MIME_TYPES.join(', ')}`,
            ),
            false,
          );
          return;
        }

        cb(null, true);
      },
      limits: { fileSize: MAX_REWARD_IMAGE_FILE_SIZE },
    }),
  )
  async uploadRewardItemImage(
    @UploadedFile() file: Express.Multer.File | undefined,
  ) {
    if (!file) {
      throw new BadRequestException('No reward image file provided');
    }

    if (file.size > MAX_REWARD_IMAGE_FILE_SIZE) {
      throw new PayloadTooLargeException('Reward image exceeds 5MB limit');
    }

    return {
      url: `/uploads/rewards/${file.filename}`,
      originalName: file.originalname,
      size: file.size,
      mimeType: file.mimetype,
    };
  }

  @Patch('items/:id')
  @ApiOperation({ summary: 'Update a reward item' })
  async updateItem(@Param('id') id: string, @Body() dto: UpdateRewardItemDto) {
    return this.rewardsService.updateRewardItem(id, dto);
  }

  @Delete('items/:id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Delete a reward item' })
  async deleteItem(
    @CurrentUser('userId') adminUserId: string,
    @Param('id') id: string,
  ) {
    await this.rewardsService.deleteRewardItem(adminUserId, id);
  }

  @Get('redemptions')
  @ApiOperation({ summary: 'List reward redemptions for admins' })
  async listRedemptions(@Query() query: RedemptionListQueryDto) {
    return this.rewardsService.listAdminRedemptions(query);
  }

  @Patch('redemptions/:id')
  @ApiOperation({ summary: 'Update a reward redemption status' })
  async updateRedemptionStatus(
    @CurrentUser('userId') adminUserId: string,
    @Param('id') id: string,
    @Body() dto: UpdateRedemptionStatusDto,
  ) {
    return this.rewardsService.updateRedemptionStatus(adminUserId, id, dto);
  }

  // --- Odoo Task Reward Configs ---

  @Get('odoo-tasks/tag-configs')
  @ApiOperation({ summary: 'List Odoo task tag point configs' })
  async listTagConfigs() {
    return this.rewardsService.listTaskTagConfigs();
  }

  @Post('odoo-tasks/tag-configs')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create Odoo task tag point config' })
  async createTagConfig(@Body() dto: CreateTaskTagConfigDto) {
    return this.rewardsService.createTaskTagConfig(dto);
  }

  @Patch('odoo-tasks/tag-configs/:id')
  @ApiOperation({ summary: 'Update Odoo task tag point config' })
  async updateTagConfig(
    @Param('id') id: number,
    @Body() dto: UpdateTaskTagConfigDto,
  ) {
    return this.rewardsService.updateTaskTagConfig(id, dto);
  }

  @Delete('odoo-tasks/tag-configs/:id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Delete Odoo task tag point config' })
  async deleteTagConfig(@Param('id') id: number) {
    await this.rewardsService.deleteTaskTagConfig(id);
  }

  @Get('odoo-tasks/multipliers')
  @ApiOperation({ summary: 'List job title multipliers' })
  async listMultipliers() {
    return this.rewardsService.listJobTitleMultipliers();
  }

  @Post('odoo-tasks/multipliers')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create job title multiplier' })
  async createMultiplier(@Body() dto: CreateJobTitleMultiplierDto) {
    return this.rewardsService.createJobTitleMultiplier(dto);
  }

  @Patch('odoo-tasks/multipliers/:id')
  @ApiOperation({ summary: 'Update job title multiplier' })
  async updateMultiplier(
    @Param('id') id: string,
    @Body() dto: UpdateJobTitleMultiplierDto,
  ) {
    return this.rewardsService.updateJobTitleMultiplier(id, dto);
  }

  @Delete('odoo-tasks/multipliers/:id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Delete job title multiplier' })
  async deleteMultiplier(@Param('id') id: string) {
    await this.rewardsService.deleteJobTitleMultiplier(id);
  }

  // --- Internal Role & Job Title Mapping ---

  @Get('internal-roles')
  @ApiOperation({ summary: 'List internal roles' })
  async listInternalRoles() {
    return this.rewardsService.listInternalRoles();
  }

  @Post('internal-roles')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create internal role' })
  async createInternalRole(@Body() dto: CreateInternalRoleDto) {
    return this.rewardsService.createInternalRole(dto);
  }

  @Patch('internal-roles/:id')
  @ApiOperation({ summary: 'Update internal role' })
  async updateInternalRole(
    @Param('id') id: string,
    @Body() dto: UpdateInternalRoleDto,
  ) {
    return this.rewardsService.updateInternalRole(id, dto);
  }

  @Delete('internal-roles/:id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Delete internal role' })
  async deleteInternalRole(@Param('id') id: string) {
    await this.rewardsService.deleteInternalRole(id);
  }

  @Get('job-title-mappings')
  @ApiOperation({ summary: 'List job title mappings' })
  async listJobTitleMappings() {
    return this.rewardsService.listJobTitleMappings();
  }

  @Post('job-title-mappings')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create job title mapping' })
  async createJobTitleMapping(@Body() dto: CreateJobTitleMappingDto) {
    return this.rewardsService.createJobTitleMapping(dto);
  }

  @Patch('job-title-mappings/:id')
  @ApiOperation({ summary: 'Update job title mapping' })
  async updateJobTitleMapping(
    @Param('id') id: string,
    @Body() dto: UpdateJobTitleMappingDto,
  ) {
    return this.rewardsService.updateJobTitleMapping(id, dto);
  }

  @Delete('job-title-mappings/:id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Delete job title mapping' })
  async deleteJobTitleMapping(@Param('id') id: string) {
    await this.rewardsService.deleteJobTitleMapping(id);
  }

  @Get('odoo-tasks/unmapped-titles')
  @ApiOperation({ summary: 'Discover job titles from Odoo not yet mapped' })
  async discoverUnmapped() {
    return this.rewardsService.discoverUnmappedJobTitles();
  }

  @Public()
  @Get('odoo-tasks/job-titles-overview')
  @ApiOperation({
    summary: 'Get overview of all job titles, user counts and reward mappings',
  })
  async getJobTitleOverview() {
    return this.rewardsService.getJobTitleOverview();
  }

  @Post('odoo-tasks/sync-job-titles')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Sync job titles (users) from Odoo to local DB' })
  async syncJobTitles() {
    return this.rewardsService.syncOdooJobTitles();
  }

  @Public()
  @Post('odoo-tasks/sync-tags')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Sync task tags from Odoo to local config (Public)' })
  async syncOdooTags() {
    return this.rewardsService.syncOdooTaskTags();
  }
}
