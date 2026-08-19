import { PocController } from './poc.controller';

describe('PocController', () => {
  const pocs = {
    create: jest.fn(),
    list: jest.fn(),
    detail: jest.fn(),
    assign: jest.fn(),
    updatePlan: jest.fn(),
    transition: jest.fn(),
  };
  const capacity = { getWeek: jest.fn(), preview: jest.fn() };
  const calendar = {};
  const weekly = { view: jest.fn(), publish: jest.fn() };
  const controller = new PocController(
    pocs as any,
    capacity as any,
    calendar as any,
    weekly as any,
  );

  beforeEach(() => jest.clearAllMocks());

  it('passes the authenticated actor to open coordination mutations', async () => {
    const dto = {
      version: 1,
      developer_user_id: '0be69a13-8fd5-4ad9-8d02-01f6de59dbcf',
      planned_start_at: '2026-08-13T01:00:00.000Z',
      estimated_hours: 8,
    };
    pocs.assign.mockResolvedValue({ id: 'poc-1' });

    await controller.assign('ordinary-user', 'poc-1', dto);
    expect(pocs.assign).toHaveBeenCalledWith('ordinary-user', 'poc-1', dto);
  });

  it('delegates list filters and weekly recovery endpoints', async () => {
    const query = {
      mode: 'week' as const,
      page: 1,
      limit: 20,
      priority: 'urgent' as const,
    };
    await controller.list('user-1', query);
    await controller.publishWeeklyReport({ week: '2026-08-12T00:00:00Z' });
    expect(pocs.list).toHaveBeenCalledWith('user-1', query);
    expect(weekly.publish).toHaveBeenCalledWith('2026-08-12T00:00:00Z');
  });
});
