import { Test, TestingModule } from '@nestjs/testing';
import { BotController } from './bot.controller';
import { BotService } from './bot.service';

describe('BotController', () => {
  let controller: BotController;
  let botService: jest.Mocked<BotService>;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [BotController],
      providers: [
        {
          provide: BotService,
          useValue: {
            listBotConversations: jest.fn(),
            listBotUsers: jest.fn(),
            sendBotMessage: jest.fn(),
          },
        },
      ],
    }).compile();

    controller = module.get(BotController);
    botService = module.get(BotService);
  });

  it('lists public bot conversations', async () => {
    botService.listBotConversations.mockResolvedValueOnce([
      {
        id: '6998761a-f0db-4dfd-8d95-ecc23cfae783',
        name: 'Backend Team',
      },
    ]);

    await expect(controller.listConversations()).resolves.toEqual([
      {
        id: '6998761a-f0db-4dfd-8d95-ecc23cfae783',
        name: 'Backend Team',
      },
    ]);
    expect(botService.listBotConversations).toHaveBeenCalled();
  });

  it('lists public bot users', async () => {
    botService.listBotUsers.mockResolvedValueOnce([
      {
        id: 'user-1',
        name: 'Nguyen Van A',
      },
    ]);

    await expect(controller.listUsers()).resolves.toEqual([
      {
        id: 'user-1',
        name: 'Nguyen Van A',
      },
    ]);
    expect(botService.listBotUsers).toHaveBeenCalled();
  });

  it('delegates sending a message to the bot service', async () => {
    botService.sendBotMessage.mockResolvedValueOnce({
      success: true,
      conversation_id: '6998761a-f0db-4dfd-8d95-ecc23cfae783',
      message_id: '550e8400-e29b-41d4-a716-446655440000',
    } as any);

    const dto = {
      bot_id: '12345678-1234-1234-1234-123456789012',
      conversation_id: '6998761a-f0db-4dfd-8d95-ecc23cfae783',
      content: 'Thong bao tu doi tac',
    };

    await expect(controller.sendMessage(dto as any)).resolves.toEqual(
      expect.objectContaining({
        success: true,
        conversation_id: dto.conversation_id,
      }),
    );
    expect(botService.sendBotMessage).toHaveBeenCalledWith(dto);
  });
});
