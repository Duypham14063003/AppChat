# Link Preview Fetch

## Overview

Backend endpoint that fetches Open Graph metadata for URLs. Validates URL security, scrapes HTML for metadata, caches results in Redis, and returns preview data. Includes rate limiting and error handling.

## Requirements

### Functional

- **LPF-001**: Endpoint `POST /chat/link-preview` accepts URL in request body
- **LPF-002**: System validates URL format (must be http:// or https://)
- **LPF-003**: System blocks private IP addresses (127.0.0.1, 192.168.*, 10.*, 172.16-31.*)
- **LPF-004**: System blocks localhost
- **LPF-005**: System checks Redis cache for existing preview (key: `link-preview:{url}`)
- **LPF-006**: If cached, return cached data immediately
- **LPF-007**: If not cached, fetch URL with 5-second timeout
- **LPF-008**: System parses HTML for Open Graph tags (og:title, og:description, og:image, og:url, og:site_name)
- **LPF-009**: System falls back to Twitter Card tags if Open Graph missing
- **LPF-010**: System falls back to HTML meta tags if Twitter Card missing
- **LPF-011**: System falls back to page title if meta tags missing
- **LPF-012**: System caches preview data in Redis with 24h TTL
- **LPF-013**: System returns preview object with title, description, image, siteName, url
- **LPF-014**: System rate limits to 10 requests per minute per user
- **LPF-015**: If rate limit exceeded, return 429 Too Many Requests

### Non-Functional

- **LPF-NFR-001**: URL fetch timeout is 5 seconds
- **LPF-NFR-002**: Max response size is 5MB
- **LPF-NFR-003**: Follow max 3 redirects
- **LPF-NFR-004**: Cache hit returns within 10ms
- **LPF-NFR-005**: Cache miss returns within 6 seconds (5s fetch + 1s processing)

## User Flow

```
Client sends POST /chat/link-preview { url }
    ↓
Validate URL format
    ↓
[Invalid] → Return 400 Bad Request
[Valid] → Continue
    ↓
Check if private IP or localhost
    ↓
[Private] → Return 400 Bad Request
[Public] → Continue
    ↓
Check rate limit (Redis: rate-limit:link-preview:{userId})
    ↓
[Exceeded] → Return 429 Too Many Requests
[OK] → Continue
    ↓
Check cache (Redis: link-preview:{url})
    ↓
[Cache hit] → Return cached data
[Cache miss] → Fetch URL
    ↓
Fetch URL with timeout (5s)
    ↓
[Timeout/Error] → Return 500 or null
[Success] → Parse HTML
    ↓
Extract Open Graph tags
    ↓
[Found] → Build preview object
[Not found] → Try Twitter Card tags
    ↓
[Found] → Build preview object
[Not found] → Try HTML meta tags
    ↓
[Found] → Build preview object
[Not found] → Return null
    ↓
Cache preview in Redis (24h TTL)
    ↓
Return preview object
```

## Technical Details

### Backend Implementation

**Location**: `apps/api/src/modules/chat/link-preview.controller.ts` (new file)

**Dependencies**:
```typescript
import { Controller, Post, Body, UseGuards, Req } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { LinkPreviewService } from './services/link-preview.service.js';
```

**Controller**:
```typescript
@Controller('chat')
@UseGuards(JwtAuthGuard)
export class LinkPreviewController {
  constructor(private readonly linkPreviewService: LinkPreviewService) {}

  @Post('link-preview')
  async fetchLinkPreview(
    @Body('url') url: string,
    @Req() req: any,
  ) {
    const userId = req.user.id;
    return this.linkPreviewService.fetchPreview(url, userId);
  }
}
```

**Service**: `apps/api/src/modules/chat/services/link-preview.service.ts` (new file)

```typescript
import { Injectable, BadRequestException, HttpException } from '@nestjs/common';
import { InjectRedis } from '@nestjs-modules/ioredis';
import Redis from 'ioredis';
import ogs from 'open-graph-scraper';

@Injectable()
export class LinkPreviewService {
  constructor(@InjectRedis() private readonly redis: Redis) {}

  async fetchPreview(url: string, userId: string) {
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
        title: result.ogTitle || result.twitterTitle || result.dcTitle,
        description: result.ogDescription || result.twitterDescription || result.dcDescription,
        image: result.ogImage?.[0]?.url || result.twitterImage?.[0]?.url,
        siteName: result.ogSiteName || new URL(url).hostname,
      };

      // Cache for 24h
      await this.redis.setex(cacheKey, 86400, JSON.stringify(preview));

      return preview;
    } catch (error) {
      // Return null on error (silent failure)
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
      if (parsed.hostname === 'localhost' || parsed.hostname === '127.0.0.1') {
        return false;
      }

      // Block private IPs
      const ip = parsed.hostname;
      if (
        ip.startsWith('192.168.') ||
        ip.startsWith('10.') ||
        ip.match(/^172\.(1[6-9]|2[0-9]|3[0-1])\./)
      ) {
        return false;
      }

      return true;
    } catch {
      return false;
    }
  }
}
```

**Module update**: `apps/api/src/modules/chat/chat.module.ts`

```typescript
import { LinkPreviewController } from './link-preview.controller.js';
import { LinkPreviewService } from './services/link-preview.service.js';

@Module({
  controllers: [
    // ... existing controllers
    LinkPreviewController,
  ],
  providers: [
    // ... existing providers
    LinkPreviewService,
  ],
})
export class ChatModule {}
```

**Package**: Add to `apps/api/package.json`
```json
{
  "dependencies": {
    "open-graph-scraper": "^6.5.0"
  }
}
```

### Flutter Implementation

**Location**: `apps/mobile/lib/features/chat/data/chat_repository.dart`

**Method**:
```dart
Future<LinkPreview?> fetchLinkPreview(String url) async {
  try {
    final res = await _dio.post(
      '/chat/link-preview',
      data: {'url': url},
    );
    
    if (res.data == null) return null;
    
    return LinkPreview.fromJson(res.data as Map<String, dynamic>);
  } catch (e) {
    debugPrint('[ChatRepository] Failed to fetch link preview: $e');
    return null;
  }
}
```

**Model**: `apps/mobile/lib/features/chat/models/link_preview.dart` (new file)

```dart
class LinkPreview {
  final String url;
  final String? title;
  final String? description;
  final String? image;
  final String? siteName;

  LinkPreview({
    required this.url,
    this.title,
    this.description,
    this.image,
    this.siteName,
  });

  factory LinkPreview.fromJson(Map<String, dynamic> json) {
    return LinkPreview(
      url: json['url'] as String,
      title: json['title'] as String?,
      description: json['description'] as String?,
      image: json['image'] as String?,
      siteName: json['siteName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'title': title,
      'description': description,
      'image': image,
      'siteName': siteName,
    };
  }
}
```

## Testing

### Backend Unit Tests

- Test URL validation (valid, invalid, private IP, localhost)
- Test rate limiting (10 requests/min)
- Test cache hit returns cached data
- Test cache miss fetches and caches
- Test Open Graph parsing
- Test fallback to Twitter Card
- Test fallback to HTML meta
- Test timeout handling
- Test error handling

### Backend Integration Tests

- Test POST /chat/link-preview with valid URL → returns preview
- Test POST /chat/link-preview with invalid URL → returns 400
- Test POST /chat/link-preview with private IP → returns 400
- Test POST /chat/link-preview exceeding rate limit → returns 429
- Test POST /chat/link-preview with cached URL → returns quickly

### Flutter Unit Tests

- Test fetchLinkPreview() with valid response → returns LinkPreview
- Test fetchLinkPreview() with null response → returns null
- Test fetchLinkPreview() with error → returns null
- Test LinkPreview.fromJson() parsing

## Acceptance Criteria

- [ ] POST /chat/link-preview endpoint accepts URL
- [ ] URL validation blocks invalid formats, private IPs, localhost
- [ ] Rate limiting enforces 10 requests/min per user
- [ ] Redis cache stores previews with 24h TTL
- [ ] Cache hit returns data within 10ms
- [ ] Open Graph tags extracted correctly
- [ ] Fallback to Twitter Card and HTML meta works
- [ ] Timeout set to 5 seconds
- [ ] Max response size 5MB
- [ ] Errors return null (silent failure)
- [ ] Flutter fetchLinkPreview() calls endpoint and parses response

