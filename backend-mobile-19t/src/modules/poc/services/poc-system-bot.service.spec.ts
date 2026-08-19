import { PocSystemBotService } from './poc-system-bot.service';

describe('PocSystemBotService', () => {
  it('reuses an existing bot email with a non-fixed UUID', async () => {
    const repo = {
      findOne: jest.fn().mockResolvedValueOnce(null).mockResolvedValueOnce({
        id: 'legacy-bot-id',
        email: 'bot@system.local',
        is_active: true,
        is_bot: true,
      }),
      create: jest.fn(),
      save: jest.fn(),
      update: jest.fn(),
    };
    const service = new PocSystemBotService(repo as any);

    await expect(service.ensure()).resolves.toBe('legacy-bot-id');
    expect(repo.save).not.toHaveBeenCalled();
  });

  it('activates an existing disabled bot', async () => {
    const repo = {
      findOne: jest.fn().mockResolvedValue({
        id: 'fixed-bot-id',
        is_active: false,
        is_bot: false,
      }),
      update: jest.fn(),
    };
    const service = new PocSystemBotService(repo as any);

    await service.ensure();
    expect(repo.update).toHaveBeenCalledWith('fixed-bot-id', {
      is_active: true,
      is_bot: true,
    });
  });
});
