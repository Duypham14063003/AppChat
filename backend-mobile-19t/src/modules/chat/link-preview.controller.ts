import { Controller, Post, Body, BadRequestException } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import { LinkPreviewService } from './services/link-preview.service.js';

@ApiTags('chat')
@ApiBearerAuth()
@Controller('chat')
export class LinkPreviewController {
  constructor(private readonly linkPreviewService: LinkPreviewService) {}

  @Post('link-preview')
  @ApiOperation({ summary: 'Fetch Open Graph link preview for a URL' })
  async fetchLinkPreview(
    @Body('url') url: string,
    @CurrentUser('userId') userId: string,
  ) {
    if (!url || typeof url !== 'string') {
      throw new BadRequestException('URL is required');
    }
    return this.linkPreviewService.fetchPreview(url.trim(), userId);
  }
}
