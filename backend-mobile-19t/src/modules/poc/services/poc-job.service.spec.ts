import { PocJobService } from './poc-job.service';

describe('PocJobService', () => {
  const remove = jest.fn();
  const queue = { add: jest.fn(), getJob: jest.fn() };
  const config = {
    get: (_key: string, fallback: unknown) => fallback,
  };
  let service: PocJobService;

  beforeEach(() => {
    jest.clearAllMocks();
    queue.getJob.mockResolvedValue(null);
    service = new PocJobService(queue as any, config as any);
  });

  it('schedules deterministic reminder and deadline jobs', async () => {
    const demoAt = new Date(Date.now() + 2 * 86400000);
    await service.reconcile({
      id: 'poc-1',
      status: 'assigned',
      demo_at: demoAt,
    } as any);

    expect(queue.add).toHaveBeenCalledWith(
      'poc-notification',
      expect.objectContaining({ pocId: 'poc-1', kind: 'demo_24h' }),
      expect.objectContaining({ jobId: 'poc:poc-1:demo_24h' }),
    );
    expect(queue.add).toHaveBeenCalledWith(
      'poc-notification',
      expect.objectContaining({ pocId: 'poc-1', kind: 'deadline' }),
      expect.objectContaining({ jobId: 'poc:poc-1:deadline' }),
    );
  });

  it('skips elapsed reminders and terminal PoCs', async () => {
    await service.reconcile({
      id: 'poc-1',
      status: 'assigned',
      demo_at: new Date(Date.now() + 45 * 60000),
    } as any);
    expect(queue.add).toHaveBeenCalledTimes(2);
    expect(queue.add).not.toHaveBeenCalledWith(
      'poc-notification',
      expect.objectContaining({ kind: 'demo_24h' }),
      expect.anything(),
    );

    queue.add.mockClear();
    await service.reconcile({
      id: 'poc-1',
      status: 'cancelled',
      demo_at: new Date(Date.now() + 86400000),
    } as any);
    expect(queue.add).not.toHaveBeenCalled();
  });

  it('removes deterministic stale jobs before rescheduling', async () => {
    queue.getJob.mockResolvedValue({ id: 'old-job', remove });
    await service.reconcile({
      id: 'poc-1',
      status: 'assigned',
      demo_at: new Date(Date.now() + 2 * 86400000),
    } as any);

    expect(queue.getJob).toHaveBeenCalledWith('poc:poc-1:demo_24h');
    expect(queue.getJob).toHaveBeenCalledWith('poc:poc-1:demo_30m');
    expect(queue.getJob).toHaveBeenCalledWith('poc:poc-1:deadline');
    expect(remove).toHaveBeenCalledTimes(3);
  });
});
