import { PocProcessor } from './poc.processor';

describe('PocProcessor', () => {
  const pocs = { getForNotification: jest.fn() };
  const chat = { project: jest.fn() };
  const push = { send: jest.fn() };
  const systemBot = { ensure: jest.fn().mockResolvedValue('existing-bot-id') };
  const weekly = {
    refreshCurrentPublished: jest.fn(),
    publish: jest.fn(),
  };
  const eventRepo = {
    findOne: jest.fn(),
    create: jest.fn((value) => ({ id: 'event-1', ...value })),
    save: jest.fn(async (value) => value),
  };
  let processor: PocProcessor;

  beforeEach(() => {
    jest.clearAllMocks();
    processor = new PocProcessor(
      pocs as any,
      chat as any,
      push as any,
      systemBot as any,
      weekly as any,
      eventRepo as any,
    );
  });

  it('does not redeliver a notification already delivered', async () => {
    eventRepo.findOne.mockResolvedValue({ status: 'delivered' });
    await processor.process({
      name: 'poc-notification',
      data: {
        pocId: 'poc-1',
        kind: 'deadline',
        scheduledAt: '2026-08-14T03:00:00.000Z',
      },
    } as any);
    expect(pocs.getForNotification).not.toHaveBeenCalled();
    expect(push.send).not.toHaveBeenCalled();
  });

  it('suppresses overdue delivery after the PoC is ready', async () => {
    eventRepo.findOne.mockResolvedValue(null);
    pocs.getForNotification.mockResolvedValue({
      id: 'poc-1',
      status: 'ready',
    });
    await processor.process({
      name: 'poc-notification',
      data: {
        pocId: 'poc-1',
        kind: 'deadline',
        scheduledAt: '2026-08-14T03:00:00.000Z',
      },
    } as any);
    expect(eventRepo.save).toHaveBeenLastCalledWith(
      expect.objectContaining({ status: 'skipped' }),
    );
    expect(chat.project).not.toHaveBeenCalled();
  });

  it('routes overdue push to the developer and sale owner once', async () => {
    eventRepo.findOne.mockResolvedValue(null);
    pocs.getForNotification.mockResolvedValue({
      id: 'poc-1',
      code: 'SALE.DEV-WA-P0001-1000-14.08.26',
      title: 'Demo',
      status: 'in_progress',
      developer_user_id: 'dev-1',
      sale_user_id: 'sale-1',
      working_conversation_id: 'conv-1',
    });
    await processor.process({
      name: 'poc-notification',
      data: {
        pocId: 'poc-1',
        kind: 'deadline',
        scheduledAt: '2026-08-14T03:00:00.000Z',
      },
    } as any);
    expect(chat.project).toHaveBeenCalledWith(
      expect.objectContaining({ id: 'poc-1' }),
      'existing-bot-id',
      'poc_overdue',
      undefined,
      true,
    );
    expect(push.send).toHaveBeenCalledWith(
      ['dev-1', 'sale-1'],
      expect.any(String),
      expect.any(String),
      expect.objectContaining({ poc_id: 'poc-1' }),
    );
    expect(eventRepo.save).toHaveBeenLastCalledWith(
      expect.objectContaining({ status: 'delivered' }),
    );
  });

  it('persists a retryable failure when downstream delivery fails', async () => {
    eventRepo.findOne.mockResolvedValue(null);
    pocs.getForNotification.mockResolvedValue({
      id: 'poc-1',
      title: 'Demo',
      status: 'assigned',
      developer_user_id: 'dev-1',
      sale_user_id: 'sale-1',
      working_conversation_id: 'conv-1',
    });
    chat.project.mockRejectedValue(new Error('chat unavailable'));

    await expect(
      processor.process({
        name: 'poc-notification',
        data: {
          pocId: 'poc-1',
          kind: 'demo_30m',
          scheduledAt: '2026-08-14T03:00:00.000Z',
        },
      } as any),
    ).rejects.toThrow('chat unavailable');
    expect(eventRepo.save).toHaveBeenLastCalledWith(
      expect.objectContaining({
        status: 'failed',
        last_error: 'chat unavailable',
      }),
    );
  });
});
