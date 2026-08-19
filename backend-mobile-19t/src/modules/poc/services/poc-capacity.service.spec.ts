import { PocCalendarService } from './poc-calendar.service';
import { PocCapacityService } from './poc-capacity.service';

describe('PocCapacityService', () => {
  const calendar = new PocCalendarService({
    get: (key: string, fallback: unknown) =>
      ({
        POC_TIMEZONE: 'Asia/Ho_Chi_Minh',
        POC_DAILY_CAPACITY_HOURS: 8,
        POC_WEEKLY_CAPACITY_HOURS: 40,
      })[key] ?? fallback,
  } as any);

  const users = [
    {
      id: 'dev-1',
      name: 'Developer One',
      is_active: true,
      is_bot: false,
    },
    {
      id: 'dev-2',
      name: 'Developer Two',
      is_active: true,
      is_bot: false,
    },
  ];

  function repository(pocs: any[]) {
    const qb: any = {
      leftJoinAndSelect: jest.fn(() => qb),
      where: jest.fn(() => qb),
      andWhere: jest.fn(() => qb),
      getMany: jest.fn().mockResolvedValue(pocs),
    };
    return { createQueryBuilder: jest.fn(() => qb), qb };
  }

  it('aggregates cross-week load, overlaps and overloads', async () => {
    const pocRepo = repository([
      {
        id: 'poc-1',
        code: 'POC-1',
        title: 'First',
        developer_user_id: 'dev-1',
        status: 'in_progress',
        planned_start_at: new Date('2026-08-10T08:00:00+07:00'),
        demo_at: new Date('2026-08-14T17:00:00+07:00'),
        estimated_hours: '40',
      },
      {
        id: 'poc-2',
        code: 'POC-2',
        title: 'Revision',
        developer_user_id: 'dev-1',
        status: 'in_progress',
        outcome: 'revision_required',
        planned_start_at: new Date('2026-08-13T08:00:00+07:00'),
        demo_at: new Date('2026-08-17T17:00:00+07:00'),
        estimated_hours: '24',
      },
    ]);
    const service = new PocCapacityService(
      pocRepo as any,
      { find: jest.fn().mockResolvedValue(users) } as any,
      calendar,
      { get: (_key: string, fallback: unknown) => fallback } as any,
    );

    const week = await service.getWeek('2026-08-12');
    const developer = week.developers[0];
    expect(developer.allocated_hours).toBe(56);
    expect(developer.excess_hours).toBe(16);
    expect(developer.over_capacity).toBe(true);
    expect(developer.has_overlap).toBe(true);
    expect(developer.daily_load['2026-08-15']).toBeUndefined();
    expect(week.developers[1].allocated_hours).toBe(0);
  });

  it('queries only active lifecycle states and excludes terminal PoCs', async () => {
    const pocRepo = repository([]);
    const service = new PocCapacityService(
      pocRepo as any,
      { find: jest.fn().mockResolvedValue(users) } as any,
      calendar,
      { get: (_key: string, fallback: unknown) => fallback } as any,
    );

    await service.getWeek('2026-08-12');
    expect(pocRepo.qb.andWhere).toHaveBeenCalledWith(
      'poc.status IN (:...statuses)',
      { statuses: ['assigned', 'in_progress', 'ready'] },
    );
  });

  it('previews overload and proposed range overlap per candidate', async () => {
    const pocRepo = repository([
      {
        id: 'poc-existing',
        code: 'POC-X',
        title: 'Existing',
        developer_user_id: 'dev-1',
        status: 'assigned',
        planned_start_at: new Date('2026-08-10T08:00:00+07:00'),
        demo_at: new Date('2026-08-14T17:00:00+07:00'),
        estimated_hours: '32',
      },
    ]);
    const service = new PocCapacityService(
      pocRepo as any,
      { find: jest.fn().mockResolvedValue(users) } as any,
      calendar,
      { get: (_key: string, fallback: unknown) => fallback } as any,
    );

    const preview = await service.preview({
      week: '2026-08-12',
      plannedStartAt: new Date('2026-08-12T08:00:00+07:00'),
      demoAt: new Date('2026-08-14T17:00:00+07:00'),
      estimatedHours: 16,
    });

    expect(preview.developers[0]).toEqual(
      expect.objectContaining({
        projected_hours: 48,
        projected_over_capacity: true,
        projected_has_overlap: true,
      }),
    );
    expect(preview.developers[1]).toEqual(
      expect.objectContaining({
        projected_hours: 16,
        projected_over_capacity: false,
        projected_has_overlap: false,
      }),
    );
  });
});
