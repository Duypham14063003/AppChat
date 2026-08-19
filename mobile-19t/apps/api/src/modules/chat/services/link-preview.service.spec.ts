import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { BadRequestException, HttpException } from '@nestjs/common';
import { LinkPreviewService } from './link-preview.service';
import ogs from 'open-graph-scraper';

jest.mock('open-graph-scraper');
const mockedOgs = ogs as jest.MockedFunction<typeof ogs>;

const mockRedis = {
  incr: jest.fn(),
  expire: jest.fn(),
  get: jest.fn(),
  setex: jest.fn(),
};
jest.mock('ioredis', () => jest.fn().mockImplementation(() => mockRedis));

describe('LinkPreviewService', () => {
  let service: LinkPreviewService;

  beforeEach(async () => {
    jest.clearAllMocks();
    mockRedis.incr.mockResolvedValue(1);
    mockRedis.expire.mockResolvedValue('OK');
    mockRedis.get.mockResolvedValue(null);

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        LinkPreviewService,
        {
          provide: ConfigService,
          useValue: { get: jest.fn((_k: string, d: any) => d) },
        },
      ],
    }).compile();
    service = module.get<LinkPreviewService>(LinkPreviewService);
  });

  describe('URL validation', () => {
    it('should accept valid https URL', async () => {
      mockedOgs.mockResolvedValue({
        result: { ogTitle: 'Test', ogUrl: 'https://example.com' },
      } as any);
      const result = await service.fetchPreview('https://example.com', 'u1');
      expect(result).toBeDefined();
      expect(result?.title).toBe('Test');
    });

    it('should accept valid http URL', async () => {
      mockedOgs.mockResolvedValue({ result: { ogTitle: 'Test' } } as any);
      const result = await service.fetchPreview('http://example.com', 'u1');
      expect(result).toBeDefined();
    });

    it('should reject invalid URL format', async () => {
      await expect(service.fetchPreview('not-a-url', 'u1')).rejects.toThrow(
        BadRequestException,
      );
    });

    it('should reject ftp:// scheme', async () => {
      await expect(
        service.fetchPreview('ftp://example.com', 'u1'),
      ).rejects.toThrow(BadRequestException);
    });

    it('should block localhost', async () => {
      await expect(
        service.fetchPreview('http://localhost:3000', 'u1'),
      ).rejects.toThrow(BadRequestException);
    });

    it('should block 127.0.0.1', async () => {
      await expect(
        service.fetchPreview('http://127.0.0.1:3000', 'u1'),
      ).rejects.toThrow(BadRequestException);
    });

    it('should block ::1 (IPv6 localhost)', async () => {
      await expect(
        service.fetchPreview('http://[::1]:3000', 'u1'),
      ).rejects.toThrow(BadRequestException);
    });

    it('should block 192.168.x.x private IP', async () => {
      await expect(
        service.fetchPreview('http://192.168.1.1', 'u1'),
      ).rejects.toThrow(BadRequestException);
    });

    it('should block 10.x.x.x private IP', async () => {
      await expect(
        service.fetchPreview('http://10.0.0.1', 'u1'),
      ).rejects.toThrow(BadRequestException);
    });

    it('should block 172.16-31.x.x private IP', async () => {
      await expect(
        service.fetchPreview('http://172.16.0.1', 'u1'),
      ).rejects.toThrow(BadRequestException);
      await expect(
        service.fetchPreview('http://172.31.255.255', 'u1'),
      ).rejects.toThrow(BadRequestException);
    });

    it('should block 169.254.x.x link-local IP', async () => {
      await expect(
        service.fetchPreview('http://169.254.1.1', 'u1'),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('rate limiting', () => {
    it('should allow up to 10 requests per minute', async () => {
      mockRedis.incr.mockResolvedValue(10);
      mockedOgs.mockResolvedValue({ result: { ogTitle: 'Test' } } as any);
      const result = await service.fetchPreview('https://example.com', 'u1');
      expect(result).toBeDefined();
    });

    it('should reject 11th request (rate limit exceeded)', async () => {
      mockRedis.incr.mockResolvedValue(11);
      await expect(
        service.fetchPreview('https://example.com', 'u1'),
      ).rejects.toThrow(HttpException);
    });

    it('should set expire on first request', async () => {
      mockRedis.incr.mockResolvedValue(1);
      mockedOgs.mockResolvedValue({ result: { ogTitle: 'T' } } as any);
      await service.fetchPreview('https://example.com', 'u1');
      expect(mockRedis.expire).toHaveBeenCalledWith(
        'rate-limit:link-preview:u1',
        60,
      );
    });
  });

  describe('Redis caching', () => {
    it('should return cached data on cache hit', async () => {
      const cached = {
        url: 'https://example.com',
        title: 'Cached',
        description: null,
        image: null,
        siteName: 'example.com',
      };
      mockRedis.get.mockResolvedValue(JSON.stringify(cached));
      const result = await service.fetchPreview('https://example.com', 'u1');
      expect(result).toEqual(cached);
      expect(mockedOgs).not.toHaveBeenCalled();
    });

    it('should cache result on cache miss with title', async () => {
      mockedOgs.mockResolvedValue({
        result: {
          ogTitle: 'New',
          ogUrl: 'https://example.com',
          ogSiteName: 'Ex',
        },
      } as any);
      await service.fetchPreview('https://example.com', 'u1');
      expect(mockRedis.setex).toHaveBeenCalledWith(
        'link-preview:https://example.com',
        86400,
        expect.any(String),
      );
    });

    it('should not cache result without title', async () => {
      mockedOgs.mockResolvedValue({
        result: { ogUrl: 'https://example.com' },
      } as any);
      await service.fetchPreview('https://example.com', 'u1');
      expect(mockRedis.setex).not.toHaveBeenCalled();
    });
  });

  describe('Open Graph parsing', () => {
    it('should extract Open Graph metadata', async () => {
      mockedOgs.mockResolvedValue({
        result: {
          ogTitle: 'OG Title',
          ogDescription: 'OG Desc',
          ogImage: [{ url: 'https://example.com/img.jpg' }],
          ogUrl: 'https://example.com',
          ogSiteName: 'Example Site',
        },
      } as any);
      const result = await service.fetchPreview('https://example.com', 'u1');
      expect(result).toEqual({
        url: 'https://example.com',
        title: 'OG Title',
        description: 'OG Desc',
        image: 'https://example.com/img.jpg',
        siteName: 'Example Site',
      });
    });

    it('should fallback to Twitter Card tags', async () => {
      mockedOgs.mockResolvedValue({
        result: {
          twitterTitle: 'TW Title',
          twitterDescription: 'TW Desc',
          twitterImage: [{ url: 'https://example.com/tw.jpg' }],
        },
      } as any);
      const result = await service.fetchPreview('https://example.com', 'u1');
      expect(result?.title).toBe('TW Title');
      expect(result?.description).toBe('TW Desc');
      expect(result?.image).toBe('https://example.com/tw.jpg');
    });

    it('should fallback to DC tags', async () => {
      mockedOgs.mockResolvedValue({
        result: { dcTitle: 'DC Title', dcDescription: 'DC Desc' },
      } as any);
      const result = await service.fetchPreview('https://example.com', 'u1');
      expect(result?.title).toBe('DC Title');
      expect(result?.description).toBe('DC Desc');
    });

    it('should use hostname as siteName fallback', async () => {
      mockedOgs.mockResolvedValue({ result: { ogTitle: 'Title' } } as any);
      const result = await service.fetchPreview(
        'https://example.com/page',
        'u1',
      );
      expect(result?.siteName).toBe('example.com');
    });
  });

  describe('timeout and error handling', () => {
    it('should pass 5s timeout to ogs', async () => {
      mockedOgs.mockResolvedValue({ result: { ogTitle: 'Test' } } as any);
      await service.fetchPreview('https://example.com', 'u1');
      expect(mockedOgs).toHaveBeenCalledWith(
        expect.objectContaining({ timeout: 5000 }),
      );
    });

    it('should return null on ogs error', async () => {
      mockedOgs.mockRejectedValue(new Error('Timeout'));
      const result = await service.fetchPreview('https://example.com', 'u1');
      expect(result).toBeNull();
    });

    it('should return null on network error', async () => {
      mockedOgs.mockRejectedValue(new Error('ECONNREFUSED'));
      const result = await service.fetchPreview('https://example.com', 'u1');
      expect(result).toBeNull();
    });
  });
});
