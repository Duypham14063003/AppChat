import Redis from 'ioredis';
import { TaskService } from './task.service';
import { OdooService, OdooTask } from '../../auth/services/odoo.service';

jest.mock('ioredis', () => jest.fn());

const RedisMock = Redis as unknown as jest.Mock;

function task(
  overrides: Partial<OdooTask> & { id: number; name: string },
): OdooTask {
  return {
    id: overrides.id,
    name: overrides.name,
    project_id: overrides.project_id ?? [18, 'Project'],
    user_ids: overrides.user_ids ?? [],
    stage_id: overrides.stage_id ?? [1, 'BACKLOG'],
    tag_ids: overrides.tag_ids ?? [],
    date_deadline: overrides.date_deadline ?? false,
    priority: overrides.priority ?? '0',
    description: overrides.description ?? false,
    parent_id: overrides.parent_id ?? false,
    child_ids: overrides.child_ids ?? [],
    subtask_count: overrides.subtask_count ?? 0,
  } as OdooTask;
}

describe('TaskService.getTasks', () => {
  let redis: { get: jest.Mock; set: jest.Mock; del: jest.Mock };
  let odoo: { fetchTasks: jest.Mock };
  let userRepo: { find: jest.Mock };
  let service: TaskService;

  beforeEach(() => {
    redis = {
      get: jest.fn().mockResolvedValue(null),
      set: jest.fn().mockResolvedValue('OK'),
      del: jest.fn().mockResolvedValue(1),
    };
    RedisMock.mockReturnValue(redis);
    odoo = { fetchTasks: jest.fn() };
    userRepo = {
      find: jest.fn().mockResolvedValue([{ odoo_uid: 7, name: 'Duy' }]),
    };
    service = new TaskService(
      odoo as unknown as OdooService,
      { get: jest.fn((_: string, fallback?: unknown) => fallback) } as any,
      userRepo as any,
    );
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('keeps project task listing parent-only by default', async () => {
    const parent = task({ id: 1, name: 'Parent task', user_ids: [7] });
    odoo.fetchTasks.mockResolvedValue([parent]);

    const result = await service.getTasks(18);

    expect(odoo.fetchTasks).toHaveBeenCalledWith(18, false);
    expect(redis.get).toHaveBeenCalledWith('tasks:project:18');
    expect(redis.set).toHaveBeenCalledWith(
      'tasks:project:18',
      JSON.stringify(result),
      'EX',
      300,
    );
    expect(result).toEqual([
      expect.objectContaining({
        id: 1,
        parent_id: false,
        user_ids: [[7, 'Duy']],
      }),
    ]);
  });

  it('uses a separate cache and returns matching subtasks when requested', async () => {
    const parent = task({
      id: 1,
      name: 'Parent task',
      stage_id: [2, 'CODING'],
      priority: '1',
      child_ids: [2],
      subtask_count: 1,
    });
    const subtask = task({
      id: 2,
      name: 'Subtask',
      stage_id: [2, 'CODING'],
      priority: '3',
      parent_id: [1, 'Parent task'],
      date_deadline: '2026-08-01',
      description: 'Subtask body',
    });
    const backlog = task({
      id: 3,
      name: 'Backlog child',
      stage_id: [1, 'BACKLOG'],
      parent_id: [1, 'Parent task'],
    });
    odoo.fetchTasks.mockResolvedValue([parent, subtask, backlog]);

    const result = await service.getTasks(
      18,
      'CODING',
      undefined,
      'priority',
      true,
      true,
    );

    expect(redis.del).toHaveBeenCalledWith('tasks:project:18:with-subtasks');
    expect(redis.get).toHaveBeenCalledWith('tasks:project:18:with-subtasks');
    expect(odoo.fetchTasks).toHaveBeenCalledWith(18, true);
    expect(result.map((item) => item.id)).toEqual([2, 1]);
    expect(result[0]).toEqual(
      expect.objectContaining({
        id: 2,
        parent_id: [1, 'Parent task'],
        child_ids: [],
        subtask_count: 0,
        stage_id: [2, 'CODING'],
        tag_ids: [],
        date_deadline: '2026-08-01',
        priority: '3',
        description: 'Subtask body',
      }),
    );
  });

  it('does not reuse parent-only cache for include-subtasks requests', async () => {
    redis.get.mockImplementation(async (key: string) => {
      if (key === 'tasks:project:18') {
        return JSON.stringify([task({ id: 1, name: 'Cached parent' })]);
      }
      return null;
    });
    odoo.fetchTasks.mockResolvedValue([
      task({ id: 2, name: 'Fetched subtask', parent_id: [1, 'Parent task'] }),
    ]);

    const result = await service.getTasks(
      18,
      undefined,
      undefined,
      undefined,
      false,
      true,
    );

    expect(redis.get).toHaveBeenCalledWith('tasks:project:18:with-subtasks');
    expect(odoo.fetchTasks).toHaveBeenCalledWith(18, true);
    expect(result).toEqual([expect.objectContaining({ id: 2 })]);
  });
});
