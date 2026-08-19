import { PocChatService } from './poc-chat.service';

describe('PocChatService', () => {
  const chat = { createBusinessSystemMessage: jest.fn() };
  let service: PocChatService;

  beforeEach(() => {
    jest.clearAllMocks();
    service = new PocChatService(chat as any);
  });

  it('does not emit a projection without a working conversation', async () => {
    await service.project(
      {
        id: 'poc-1',
        working_conversation_id: null,
      } as any,
      'actor-1',
      'poc_assigned',
    );
    expect(chat.createBusinessSystemMessage).not.toHaveBeenCalled();
  });

  it('emits versioned structured metadata with old and new values', async () => {
    const poc = {
      id: 'poc-1',
      code: 'SALE.DEV-WA-P0001-1000-14.08.26',
      title: 'Demo',
      customer_name: 'Acme',
      sale_user_id: 'sale-1',
      developer_user_id: 'dev-1',
      working_conversation_id: 'conv-1',
      planned_start_at: new Date('2026-08-12T01:00:00.000Z'),
      estimated_hours: '16.00',
      demo_at: new Date('2026-08-14T03:00:00.000Z'),
      status: 'assigned',
      outcome: null,
    };
    const changes = {
      demo_at: {
        previous: '2026-08-13T03:00:00.000Z',
        current: '2026-08-14T03:00:00.000Z',
      },
    };

    await service.project(poc as any, 'actor-1', 'poc_plan_updated', changes);
    expect(chat.createBusinessSystemMessage).toHaveBeenCalledWith(
      'conv-1',
      'actor-1',
      'poc_plan_updated',
      expect.objectContaining({
        schema_version: 1,
        poc_id: 'poc-1',
        developer_user_id: 'dev-1',
        estimated_hours: 16,
        changes,
        deep_link: '/pocs/poc-1',
      }),
    );
  });

  it('swallows user mutation projection errors but can rethrow for workers', async () => {
    const poc = {
      id: 'poc-1',
      working_conversation_id: 'conv-1',
      demo_at: new Date(),
    };
    chat.createBusinessSystemMessage.mockRejectedValue(
      new Error('chat unavailable'),
    );

    await expect(
      service.project(poc as any, 'actor-1', 'poc_assigned'),
    ).resolves.toBeUndefined();
    await expect(
      service.project(poc as any, 'actor-1', 'poc_assigned', undefined, true),
    ).rejects.toThrow('chat unavailable');
  });
});
