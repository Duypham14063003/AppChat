import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException } from '@nestjs/common';
import { LinkPreviewController } from './link-preview.controller';
import { LinkPreviewService } from './services/link-preview.service';

describe('LinkPreviewController', () => {
  let controller: LinkPreviewController;
  let service: jest.Mocked<LinkPreviewService>;

  beforeEach(async () => {
    const mockService = {
      fetchPreview: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [LinkPreviewController],
      providers: [{ provide: LinkPreviewService, useValue: mockService }],
    }).compile();

    controller = module.get<LinkPreviewController>(LinkPreviewController);
    service = module.get(LinkPreviewService);
  });

  it('should call service.fetchPreview with trimmed URL and userId', async () => {
    const preview = {
      url: 'https://example.com',
      title: 'Test',
      description: null,
      image: null,
      siteName: 'example.com',
    };
    service.fetchPreview.mockResolvedValue(preview);

    const result = await controller.fetchLinkPreview(
      '  https://example.com  ',
      'user-123',
    );
    expect(service.fetchPreview).toHaveBeenCalledWith(
      'https://example.com',
      'user-123',
    );
    expect(result).toEqual(preview);
  });

  it('should return null when service returns null', async () => {
    service.fetchPreview.mockResolvedValue(null);
    const result = await controller.fetchLinkPreview(
      'https://example.com',
      'user-123',
    );
    expect(result).toBeNull();
  });

  it('should throw BadRequestException when url is empty', async () => {
    await expect(controller.fetchLinkPreview('', 'user-123')).rejects.toThrow(
      BadRequestException,
    );
  });

  it('should throw BadRequestException when url is undefined', async () => {
    await expect(
      controller.fetchLinkPreview(undefined as any, 'user-123'),
    ).rejects.toThrow(BadRequestException);
  });

  it('should throw BadRequestException when url is not a string', async () => {
    await expect(
      controller.fetchLinkPreview(123 as any, 'user-123'),
    ).rejects.toThrow(BadRequestException);
  });

  it('should propagate service errors', async () => {
    service.fetchPreview.mockRejectedValue(
      new BadRequestException('Invalid URL format'),
    );
    await expect(
      controller.fetchLinkPreview('http://localhost', 'user-123'),
    ).rejects.toThrow(BadRequestException);
  });
});
