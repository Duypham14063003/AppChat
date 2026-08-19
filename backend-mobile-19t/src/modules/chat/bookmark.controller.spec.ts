import { BadRequestException, ForbiddenException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { BookmarkController } from './bookmark.controller';
import { ChatService } from './services/chat.service';

describe('BookmarkController', () => {
  let controller: BookmarkController;
  let chatService: jest.Mocked<ChatService>;

  beforeEach(async () => {
    const mockChatService = {
      getGlobalBookmarks: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [BookmarkController],
      providers: [{ provide: ChatService, useValue: mockChatService }],
    }).compile();

    controller = module.get<BookmarkController>(BookmarkController);
    chatService = module.get(ChatService);
  });

  it('maps invalid bookmark cursor errors to 400', async () => {
    chatService.getGlobalBookmarks.mockRejectedValue(
      Object.assign(new Error('Invalid bookmark cursor'), {
        code: 'INVALID_CURSOR',
      }),
    );

    await expect(
      controller.getMyBookmarks('user-1', { cursor: 'bad-cursor' }),
    ).rejects.toThrow(BadRequestException);
  });

  it('maps inaccessible conversation filter errors to 403', async () => {
    chatService.getGlobalBookmarks.mockRejectedValue(
      Object.assign(new Error('Not a member of this conversation'), {
        code: 'FORBIDDEN',
      }),
    );

    await expect(
      controller.getMyBookmarks('user-1', { conv_id: 'conv-1' }),
    ).rejects.toThrow(ForbiddenException);
  });
});
