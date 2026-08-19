import { ConflictException } from '@nestjs/common';
import { PocService } from './poc.service';

describe('PocService coordination behavior', () => {
  const actor = {
    id: 'actor-1',
    name: 'Ordinary User',
    is_active: true,
    is_bot: false,
  };
  const developer = {
    id: 'dev-1',
    name: 'Developer One',
    is_active: true,
    is_bot: false,
  };
  const basePoc = {
    id: 'poc-1',
    sequence_number: null,
    code: null,
    customer_name: 'Acme',
    title: 'Demo',
    requirement: 'Validate the workflow',
    product_type: 'web_app',
    priority: 'normal',
    sale_user_id: 'sale-1',
    developer_user_id: null,
    assigned_by_user_id: null,
    working_conversation_id: null,
    source_message_id: null,
    planned_start_at: null,
    estimated_hours: null,
    demo_at: new Date(Date.now() + 4 * 86400000),
    status: 'unassigned',
    outcome: null,
    poc_url: null,
    reference_links: [],
    cancel_reason: null,
    ready_at: null,
    demonstrated_at: null,
    version: 1,
    sale_user: { id: 'sale-1', name: 'Sale Owner' },
    developer_user: null,
    assigned_by_user: null,
  };

  function harness(affected = 1) {
    let current = { ...basePoc } as any;
    const historySave = jest.fn();
    const updateQb: any = {
      update: jest.fn(() => updateQb),
      set: jest.fn((next: any) => {
        if (affected) current = { ...current, ...next };
        return updateQb;
      }),
      where: jest.fn(() => updateQb),
      execute: jest.fn().mockResolvedValue({ affected }),
    };
    const manager = {
      getRepository: jest.fn((entity: any) => {
        if (entity.name === 'PocHistory') return { save: historySave };
        return { createQueryBuilder: () => updateQb };
      }),
    };
    const pocRepo = {
      findOne: jest.fn(async () => current),
      query: jest.fn().mockResolvedValue([{ value: '18' }]),
    };
    const historyRepo = {
      find: jest.fn().mockResolvedValue([]),
    };
    const userRepo = {
      findOne: jest.fn(async ({ where }: any) =>
        where.id === developer.id ? developer : actor,
      ),
    };
    const jobs = { reconcile: jest.fn(), enqueueWeeklyRefresh: jest.fn() };
    const chat = { project: jest.fn() };
    const push = { send: jest.fn() };
    const audit = { logEvent: jest.fn() };
    const service = new PocService(
      pocRepo as any,
      historyRepo as any,
      userRepo as any,
      { findOne: jest.fn() } as any,
      { findOne: jest.fn() } as any,
      { transaction: (callback: any) => callback(manager) } as any,
      audit as any,
      chat as any,
      jobs as any,
      push as any,
    );
    return {
      service,
      pocRepo,
      historySave,
      jobs,
      chat,
      push,
      getCurrent: () => current,
    };
  }

  it('lets an ordinary active user assign exactly one primary developer', async () => {
    const h = harness();
    const demoAt = new Date(Date.now() + 3 * 86400000);
    const result = await h.service.assign('actor-1', 'poc-1', {
      version: 1,
      developer_user_id: 'dev-1',
      planned_start_at: new Date(Date.now() + 3600000).toISOString(),
      estimated_hours: 12,
      demo_at: demoAt.toISOString(),
    });

    expect(result.developer_user_id).toBe('dev-1');
    expect(result.assigned_by_user_id).toBe('actor-1');
    expect(result.code).toMatch(/^SO\.DO-WA-P0018-/);
    expect(result.version).toBe(2);
    expect(h.historySave).toHaveBeenCalledWith(
      expect.objectContaining({ event_type: 'assigned' }),
    );
    expect(h.jobs.reconcile).toHaveBeenCalled();
    expect(h.chat.project).toHaveBeenCalledWith(
      expect.anything(),
      'actor-1',
      'poc_assigned',
      expect.anything(),
    );
    expect(h.push.send).toHaveBeenCalledWith(
      ['dev-1'],
      expect.any(String),
      expect.any(String),
      expect.objectContaining({ poc_id: 'poc-1' }),
    );
  });

  it('returns the latest representation when simultaneous assignment loses', async () => {
    const h = harness(0);
    await expect(
      h.service.assign('actor-1', 'poc-1', {
        version: 1,
        developer_user_id: 'dev-1',
        planned_start_at: new Date(Date.now() + 3600000).toISOString(),
        estimated_hours: 8,
      }),
    ).rejects.toMatchObject({
      constructor: ConflictException,
      response: expect.objectContaining({
        code: 'POC_VERSION_CONFLICT',
        latest: expect.objectContaining({ id: 'poc-1', version: 1 }),
      }),
    });
    expect(h.historySave).not.toHaveBeenCalled();
    expect(h.chat.project).not.toHaveBeenCalled();
  });

  it('applies filters, derived ordering and pagination in list queries', async () => {
    const qb: any = {
      leftJoinAndSelect: jest.fn(() => qb),
      andWhere: jest.fn(() => qb),
      orderBy: jest.fn(() => qb),
      addOrderBy: jest.fn(() => qb),
      skip: jest.fn(() => qb),
      take: jest.fn(() => qb),
      getManyAndCount: jest.fn().mockResolvedValue([[], 0]),
    };
    const service = new PocService(
      { createQueryBuilder: jest.fn(() => qb) } as any,
      {} as any,
      {} as any,
      {} as any,
      {} as any,
      {} as any,
      {} as any,
      {} as any,
      {} as any,
      {} as any,
    );
    const result = await service.list('user-1', {
      mode: 'my_requests',
      status: 'ready',
      developer_user_id: 'dev-1',
      sale_user_id: 'sale-1',
      priority: 'urgent',
      search: 'Acme',
      page: 2,
      limit: 20,
    });

    expect(qb.andWhere).toHaveBeenCalledWith('poc.sale_user_id = :userId', {
      userId: 'user-1',
    });
    expect(qb.andWhere).toHaveBeenCalledWith(
      'poc.developer_user_id = :developer',
      { developer: 'dev-1' },
    );
    expect(qb.orderBy).toHaveBeenCalledWith(
      expect.stringContaining('CASE'),
      'ASC',
    );
    expect(qb.skip).toHaveBeenCalledWith(20);
    expect(result).toEqual({ items: [], total: 0, page: 2, limit: 20 });
  });
});
