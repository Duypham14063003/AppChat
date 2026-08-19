import { Test, TestingModule } from '@nestjs/testing';
import { SearchController } from './search.controller';
import { ChatService } from './services/chat.service';

describe('SearchController', () => {
  let controller: SearchController;
  let chatService: jest.Mocked<ChatService>;

  beforeEach(async () => {
    const mockChatService = {
      searchMessages: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [SearchController],
      providers: [{ provide: ChatService, useValue: mockChatService }],
    }).compile();

    controller = module.get<SearchController>(SearchController);
    chatService = module.get(ChatService);
  });

  it('uses the authenticated userId convention when delegating search', async () => {
    chatService.searchMessages.mockResolvedValue({
      results: [],
      next_cursor: null,
      has_more: false,
    });

    await controller.searchMessages('user-1', {
      q: 'hi',
      conv_id: 'conv-1',
      cursor: 'cursor-1',
      limit: 10,
    });

    expect(chatService.searchMessages).toHaveBeenCalledWith(
      'user-1',
      'hi',
      'conv-1',
      'cursor-1',
      10,
      undefined,
    );
  });

  it('passes q_hashes through for blind-index room search', async () => {
    chatService.searchMessages.mockResolvedValue({
      results: [],
      next_cursor: null,
      has_more: false,
    });

    await controller.searchMessages('user-1', {
      conv_id: 'conv-1',
      q_hashes: ['a'.repeat(64), 'b'.repeat(64)],
      limit: 5,
    });

    expect(chatService.searchMessages).toHaveBeenCalledWith(
      'user-1',
      undefined,
      'conv-1',
      undefined,
      5,
      ['a'.repeat(64), 'b'.repeat(64)],
    );
  });
});
