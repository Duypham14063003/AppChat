import { PocScheduler } from './poc.scheduler';

describe('PocScheduler', () => {
  it('publishes every Friday at 12:00 in Ho Chi Minh City', async () => {
    const queue = { upsertJobScheduler: jest.fn() };
    const config = {
      get: (key: string, fallback: unknown) =>
        ({
          POC_REPORT_TIME: '12:00',
          POC_TIMEZONE: 'Asia/Ho_Chi_Minh',
        })[key] ?? fallback,
    };
    const scheduler = new PocScheduler(queue as any, config as any);

    await scheduler.onModuleInit();
    expect(queue.upsertJobScheduler).toHaveBeenCalledWith(
      'poc:weekly-report',
      { pattern: '0 12 * * 5', tz: 'Asia/Ho_Chi_Minh' },
      expect.objectContaining({ name: 'publish-weekly-report' }),
    );
  });
});
