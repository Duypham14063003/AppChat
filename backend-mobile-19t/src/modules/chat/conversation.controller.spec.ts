import { Test, TestingModule } from '@nestjs/testing';
import {
  BadRequestException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { ConversationController } from './conversation.controller';
import { ChatService } from './services/chat.service';

describe('ConversationController bookmarks', () => {
  let controller: ConversationController;
  let chatService: jest.Mocked<ChatService>;

  beforeEach(async () => {
    const mockChatService = {
      bookmarkMessage: jest.fn(),
      getBookmarks: jest.fn(),
      deleteBookmark: jest.fn(),
      getMessageSeenBy: jest.fn(),
      getConversationEncryptionKey: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [ConversationController],
      providers: [{ provide: ChatService, useValue: mockChatService }],
    }).compile();

    controller = module.get<ConversationController>(ConversationController);
    chatService = module.get(ChatService);
  });

  it('maps duplicate bookmark errors to 400', async () => {
    chatService.bookmarkMessage.mockRejectedValue(
      Object.assign(new Error('Message is already bookmarked'), {
        code: 'ALREADY_BOOKMARKED',
      }),
    );

    await expect(
      controller.bookmarkMessage('user-1', 'conv-1', {
        message_id: 'message-1',
      }),
    ).rejects.toThrow(BadRequestException);
  });

  it('maps non-member bookmark listing errors to 403', async () => {
    chatService.getBookmarks.mockRejectedValue(
      Object.assign(new Error('Not a member of this conversation'), {
        code: 'FORBIDDEN',
      }),
    );

    await expect(controller.getBookmarks('user-1', 'conv-1')).rejects.toThrow(
      ForbiddenException,
    );
  });

  it('maps missing bookmark delete errors to 404', async () => {
    chatService.deleteBookmark.mockRejectedValue(
      Object.assign(new Error('Bookmark not found'), {
        code: 'NOT_FOUND',
      }),
    );

    await expect(
      controller.deleteBookmark('user-1', 'conv-1', 'message-1'),
    ).rejects.toThrow(NotFoundException);
  });

  it('returns seen-by payloads from the chat service', async () => {
    const seenBy = {
      conv_id: 'conv-1',
      message_id: 'message-1',
      seen_by: [
        {
          user_id: 'user-2',
          name: 'User 2',
          avatar_url: null,
          seen_at: '2026-05-05T04:30:00.000Z',
        },
      ],
    };
    chatService.getMessageSeenBy.mockResolvedValue(seenBy);

    await expect(
      controller.getMessageSeenBy('user-1', 'conv-1', 'message-1'),
    ).resolves.toEqual(seenBy);
  });

  it('maps recalled message seen-by errors to 400', async () => {
    chatService.getMessageSeenBy.mockRejectedValue(
      Object.assign(
        new Error('Cannot inspect seen-by state for recalled messages'),
        {
          code: 'INVALID_MESSAGE_STATE',
        },
      ),
    );

    await expect(
      controller.getMessageSeenBy('user-1', 'conv-1', 'message-1'),
    ).rejects.toThrow(BadRequestException);
  });

  it('returns the active conversation encryption key for members', async () => {
    const keyPayload = {
      conv_id: 'conv-1',
      key_id: 'key-1',
      alg: 'AES-256-GCM',
      version: 1,
      material: Buffer.alloc(32, 7).toString('base64'),
    };
    chatService.getConversationEncryptionKey.mockResolvedValue(keyPayload);

    await expect(
      controller.getEncryptionKey('user-1', 'conv-1'),
    ).resolves.toEqual(keyPayload);
  });

  it('maps non-member encryption key access errors to 403', async () => {
    chatService.getConversationEncryptionKey.mockRejectedValue(
      Object.assign(new Error('Not a member of this conversation'), {
        code: 'FORBIDDEN',
      }),
    );

    await expect(controller.getEncryptionKey('user-1', 'conv-1')).rejects.toThrow(
      ForbiddenException,
    );
  });
});
