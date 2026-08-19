import {
  Injectable,
  Logger,
  BadRequestException,
  HttpException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';
import ogs from 'open-graph-scraper';

@Injectable()
export class LinkPreviewService {
  private readonly logger = new Logger(LinkPreviewService.name);
  private readonly redis: Redis;

  constructor(private readonly config: ConfigService) {
    this.redis = new Redis({
      host: this.config.get('REDIS_HOST', 'localhost'),
      port: this.config.get<number>('REDIS_PORT', 6379),
    });
  }

  async fetchPreview(
    url: string,
    userId: string,
  ): Promise<Record<string, unknown> | null> {
    // Validate URL
    if (!this.isValidUrl(url)) {
      throw new BadRequestException('Invalid URL format');
    }

    // Check rate limit
    const rateLimitKey = `rate-limit:link-preview:${userId}`;
    const count = await this.redis.incr(rateLimitKey);
    if (count === 1) {
      await this.redis.expire(rateLimitKey, 60);
    }
    if (count > 10) {
      throw new HttpException('Rate limit exceeded', 429);
    }

    // Check cache
    const cacheKey = `link-preview:${url}`;
    const cached = await this.redis.get(cacheKey);
    if (cached) {
      return JSON.parse(cached);
    }

    // Fetch and parse
    try {
      const { result } = await ogs({
        url,
        timeout: 5000,
        fetchOptions: {
          headers: {
            'User-Agent': 'NineteenTechBot/1.0',
          },
        },
      });

      const preview = {
        url: result.ogUrl || url,
        title: result.ogTitle || result.twitterTitle || result.dcTitle || null,
        description:
          result.ogDescription ||
          result.twitterDescription ||
          result.dcDescription ||
          null,
        image:
          (result.ogImage as any)?.[0]?.url ||
          (result.twitterImage as any)?.[0]?.url ||
          null,
        siteName: result.ogSiteName || new URL(url).hostname,
      };

      // Only cache if we got at least a title
      if (preview.title) {
        await this.redis.setex(cacheKey, 86400, JSON.stringify(preview));
      }

      return preview;
    } catch (error: any) {
      this.logger.warn(
        `Failed to fetch link preview for ${url}: ${error.message}`,
      );
      return null;
    }
  }

  private isValidUrl(url: string): boolean {
    try {
      const parsed = new URL(url);

      // Must be http or https
      if (!['http:', 'https:'].includes(parsed.protocol)) {
        return false;
      }

      // Block localhost
      if (
        parsed.hostname === 'localhost' ||
        parsed.hostname === '127.0.0.1' ||
        parsed.hostname === '::1' ||
        parsed.hostname === '[::1]'
      ) {
        return false;
      }

      // Block private IPs
      const ip = parsed.hostname;
      if (
        ip.startsWith('192.168.') ||
        ip.startsWith('10.') ||
        /^172\.(1[6-9]|2[0-9]|3[0-1])\./.test(ip) ||
        ip.startsWith('169.254.')
      ) {
        return false;
      }

      return true;
    } catch {
      return false;
    }
  }
}
