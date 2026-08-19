import { PocCalendarService } from './poc-calendar.service';

describe('PocCalendarService', () => {
  const service = new PocCalendarService({
    get: (key: string, fallback: unknown) =>
      ({
        POC_TIMEZONE: 'Asia/Ho_Chi_Minh',
        POC_DAILY_CAPACITY_HOURS: 8,
        POC_WEEKLY_CAPACITY_HOURS: 40,
      })[key] ?? fallback,
  } as any);

  it('resolves a Ho Chi Minh City ISO week', () => {
    const week = service.weekWindow('2026-08-12');
    expect(week.dates).toEqual([
      '2026-08-10',
      '2026-08-11',
      '2026-08-12',
      '2026-08-13',
      '2026-08-14',
      '2026-08-15',
      '2026-08-16',
    ]);
    expect(week.isoWeek).toBe(33);
  });

  it('excludes weekends and proportionally allocates estimates', () => {
    const allocation = service.allocate(
      new Date('2026-08-14T08:00:00+07:00'),
      new Date('2026-08-17T17:00:00+07:00'),
      16,
    );
    expect(allocation).toEqual({
      '2026-08-14': 8,
      '2026-08-17': 8,
    });
  });

  it('allocates partial working days by intersecting duration', () => {
    expect(
      service.allocate(
        new Date('2026-08-12T13:00:00+07:00'),
        new Date('2026-08-13T17:00:00+07:00'),
        12,
      ),
    ).toEqual({
      '2026-08-12': 4,
      '2026-08-13': 8,
    });
  });

  it('preserves the exact estimate after per-day rounding', () => {
    const allocation = service.allocate(
      new Date('2026-08-12T08:00:00+07:00'),
      new Date('2026-08-14T17:00:00+07:00'),
      16,
    );
    expect(
      Object.values(allocation).reduce((sum, value) => sum + value, 0),
    ).toBe(16);
  });
});
