import { Test, TestingModule } from '@nestjs/testing';
import {
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { BotService } from './bot.service';
import { User } from '../auth/entities/user.entity';
import { ConversationMember } from '../chat/entities/conversation-member.entity';
import { Conversation } from '../chat/entities/conversation.entity';
import { Message } from '../chat/entities/message.entity';
import { ChatService } from '../chat/services/chat.service';

describe('BotService', () => {
  let service: BotService;
  let userRepo: jest.Mocked<Repository<User>>;
  let memberRepo: jest.Mocked<Repository<ConversationMember>>;
  let convRepo: jest.Mocked<Repository<Conversation>>;
  let messageRepo: jest.Mocked<Repository<Message>>;
  let chatService: jest.Mocked<ChatService>;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        BotService,
        {
          provide: ChatService,
          useValue: {
            sendMessage: jest.fn(),
          },
        },
        {
          provide: getRepositoryToken(User),
          useValue: {
            find: jest.fn(),
            findOne: jest.fn(),
            findOneByOrFail: jest.fn(),
            update: jest.fn(),
            create: jest.fn((value) => value),
            save: jest.fn(),
          },
        },
        {
          provide: getRepositoryToken(ConversationMember),
          useValue: {
            findOne: jest.fn(),
            create: jest.fn((value) => value),
            save: jest.fn(),
          },
        },
        {
          provide: getRepositoryToken(Conversation),
          useValue: {
            find: jest.fn(),
            findOne: jest.fn(),
            create: jest.fn((value) => value),
            save: jest.fn(),
            createQueryBuilder: jest.fn(),
          },
        },
        {
          provide: getRepositoryToken(Message),
          useValue: {
            findOne: jest.fn(),
            save: jest.fn(),
          },
        },
      ],
    }).compile();

    service = module.get(BotService);
    userRepo = module.get(getRepositoryToken(User));
    memberRepo = module.get(getRepositoryToken(ConversationMember));
    convRepo = module.get(getRepositoryToken(Conversation));
    messageRepo = module.get(getRepositoryToken(Message));
    chatService = module.get(ChatService);
  });

  it('lists active group conversations with only id and name', async () => {
    convRepo.find.mockResolvedValueOnce([
      {
        id: 'conv-1',
        name: 'Backend Team',
        type: 'GROUP',
      },
      {
        id: 'conv-2',
        name: null,
        type: 'GROUP',
      },
      {
        id: 'conv-3',
        name: '[Đã xóa]',
        type: 'GROUP',
      },
    ] as Conversation[]);

    await expect(service.listBotConversations()).resolves.toEqual([
      {
        id: 'conv-1',
        name: 'Backend Team',
      },
    ]);
  });

  it('lists active non-bot users with only id and name', async () => {
    userRepo.find.mockResolvedValueOnce([
      {
        id: 'user-1',
        name: 'Nguyen Van A',
      },
      {
        id: 'user-2',
        name: '   ',
      },
    ] as User[]);

    await expect(service.listBotUsers()).resolves.toEqual([
      {
        id: 'user-1',
        name: 'Nguyen Van A',
      },
    ]);
  });

  it('sends a bot message to a conversation with an active bot', async () => {
    userRepo.findOne.mockResolvedValueOnce({
      id: '12345678-1234-1234-1234-123456789012',
      email: 'bot-notifications@system.local',
      name: 'Notification Bot',
      is_active: true,
      is_bot: true,
    } as User);
    chatService.sendMessage.mockResolvedValueOnce({
      id: '550e8400-e29b-41d4-a716-446655440000',
      created_at: new Date('2026-06-04T12:00:00.000Z'),
    } as any);

    const result = await service.sendBotMessage({
      bot_id: '12345678-1234-1234-1234-123456789012',
      conversation_id: '6998761a-f0db-4dfd-8d95-ecc23cfae783',
      content: 'Thong bao tu web ngoai',
      external_message_id: '550e8400-e29b-41d4-a716-446655440000',
    });

    expect(chatService.sendMessage).toHaveBeenCalledWith(
      '12345678-1234-1234-1234-123456789012',
      expect.objectContaining({
        id: '550e8400-e29b-41d4-a716-446655440000',
        conv_id: '6998761a-f0db-4dfd-8d95-ecc23cfae783',
        type: 'text',
        content: 'Thong bao tu web ngoai',
      }),
      undefined,
      true,
    );
    expect(result).toEqual({
      success: true,
      conversation_id: '6998761a-f0db-4dfd-8d95-ecc23cfae783',
      message_id: '550e8400-e29b-41d4-a716-446655440000',
      created_at: new Date('2026-06-04T12:00:00.000Z'),
      sender: {
        id: '12345678-1234-1234-1234-123456789012',
        email: 'bot-notifications@system.local',
        name: 'Notification Bot',
      },
    });
  });

  it('rejects when bot does not exist', async () => {
    userRepo.findOne.mockResolvedValueOnce(null);
    await expect(
      service.sendBotMessage({
        bot_id: '12345678-1234-1234-1234-123456789012',
        conversation_id: '6998761a-f0db-4dfd-8d95-ecc23cfae783',
        content: 'Thong bao',
      }),
    ).rejects.toThrow(NotFoundException);
  });

  it('rejects when bot is inactive', async () => {
    userRepo.findOne.mockResolvedValueOnce({
      id: '12345678-1234-1234-1234-123456789012',
      email: 'bot-notifications@system.local',
      name: 'Notification Bot',
      is_active: false,
      is_bot: true,
    } as User);

    await expect(
      service.sendBotMessage({
        bot_id: '12345678-1234-1234-1234-123456789012',
        conversation_id: '6998761a-f0db-4dfd-8d95-ecc23cfae783',
        content: 'Thong bao',
      }),
    ).rejects.toThrow(ForbiddenException);
  });
});
