import { PocWeeklyReportService } from './poc-weekly-report.service';

describe('PocWeeklyReportService', () => {
  const snapshot = {
    iso_year: 2026,
    iso_week: 33,
    week_start: '2026-08-10',
    week_end: '2026-08-16',
    total: 1,
    counts: { ready: 1 },
    overdue: [],
    demos: [],
    capacity: [],
  };
  const reportRepo = {
    findOne: jest.fn(),
    create: jest.fn((value) => ({ id: 'report-1', ...value })),
    save: jest.fn(async (value) => value),
  };
  const chat = {
    createBusinessSystemMessage: jest.fn(),
    updateBusinessSystemMessage: jest.fn(),
  };
  const config = {
    get: jest.fn((_key: string, fallback: unknown) => fallback),
  };
  const systemBot = {
    ensure: jest.fn().mockResolvedValue('existing-bot-id'),
  };
  let service: PocWeeklyReportService;

  beforeEach(() => {
    jest.clearAllMocks();
    service = new PocWeeklyReportService(
      {} as any,
      reportRepo as any,
      {} as any,
      {
        weekWindow: jest.fn(() => ({
          isoYear: 2026,
          isoWeek: 33,
          start: new Date('2026-08-10T00:00:00+07:00'),
        })),
      } as any,
      chat as any,
      config as any,
      {} as any,
      systemBot as any,
    );
    jest.spyOn(service, 'buildSnapshot').mockResolvedValue(snapshot as any);
    jest
      .spyOn(service as any, 'ensureConversation')
      .mockResolvedValue(undefined);
  });

  it('creates the first weekly message in the configured conversation', async () => {
    reportRepo.findOne.mockResolvedValue(null);
    chat.createBusinessSystemMessage.mockResolvedValue({ id: 'message-1' });

    const report = await service.publish('2026-08-12');
    expect(config.get).toHaveBeenCalledWith(
      'POC_REPORT_CONVERSATION_ID',
      '35353995-517b-4fcb-b4d7-e0f23c5f4042',
    );
    expect(chat.createBusinessSystemMessage).toHaveBeenCalledWith(
      '35353995-517b-4fcb-b4d7-e0f23c5f4042',
      'existing-bot-id',
      'poc_weekly_summary',
      expect.objectContaining({
        deep_link: '/pocs/week?week=2026-08-10',
      }),
    );
    expect(report.chat_message_id).toBe('message-1');
    expect(report.status).toBe('published');
  });

  it('edits the stable message when the report already exists', async () => {
    reportRepo.findOne.mockResolvedValue({
      id: 'report-1',
      chat_message_id: 'message-1',
      status: 'published',
      published_at: new Date('2026-08-14T05:00:00.000Z'),
    });

    await service.publish('2026-08-12');
    expect(chat.updateBusinessSystemMessage).toHaveBeenCalledWith(
      'message-1',
      'poc_weekly_summary',
      expect.objectContaining({ iso_week: 33 }),
    );
    expect(chat.createBusinessSystemMessage).not.toHaveBeenCalled();
  });

  it('marks a publisher failure for operational recovery', async () => {
    reportRepo.findOne.mockResolvedValue({
      id: 'report-1',
      chat_message_id: 'message-1',
      status: 'published',
      published_at: new Date(),
    });
    chat.updateBusinessSystemMessage.mockRejectedValue(
      new Error('message update failed'),
    );

    await expect(service.publish('2026-08-12')).rejects.toThrow(
      'message update failed',
    );
    expect(reportRepo.save).toHaveBeenLastCalledWith(
      expect.objectContaining({ status: 'failed' }),
    );
  });

  it('orders demo summary rows and includes people and overload content', async () => {
    const qb: any = {
      leftJoinAndSelect: jest.fn(() => qb),
      where: jest.fn(() => qb),
      orderBy: jest.fn(() => qb),
      getMany: jest.fn().mockResolvedValue([
        {
          id: 'poc-early',
          code: 'POC-EARLY',
          title: 'Early demo',
          customer_name: 'Acme',
          sale_user: { name: 'Sale Owner' },
          developer_user: { name: 'Dev Owner' },
          demo_at: new Date('2026-08-11T03:00:00.000Z'),
          status: 'ready',
        },
      ]),
    };
    const capacity = {
      getWeek: jest.fn().mockResolvedValue({
        developers: [
          {
            user_id: 'dev-1',
            name: 'Dev Owner',
            allocated_hours: 48,
            capacity_hours: 40,
            over_capacity: true,
            excess_hours: 8,
          },
        ],
      }),
    };
    service = new PocWeeklyReportService(
      { createQueryBuilder: jest.fn(() => qb) } as any,
      reportRepo as any,
      capacity as any,
      {
        weekWindow: jest.fn(() => ({
          isoYear: 2026,
          isoWeek: 33,
          start: new Date('2026-08-09T17:00:00.000Z'),
          end: new Date('2026-08-16T17:00:00.000Z'),
          dates: [
            '2026-08-10',
            '2026-08-11',
            '2026-08-12',
            '2026-08-13',
            '2026-08-14',
            '2026-08-15',
            '2026-08-16',
          ],
        })),
      } as any,
      chat as any,
      config as any,
      {} as any,
      systemBot as any,
    );

    const result = await service.buildSnapshot('2026-08-12');
    expect(qb.orderBy).toHaveBeenCalledWith('poc.demo_at', 'ASC');
    expect(result.demos[0]).toEqual(
      expect.objectContaining({
        sale_name: 'Sale Owner',
        developer_name: 'Dev Owner',
        deep_link: '/pocs/poc-early',
      }),
    );
    expect(result.capacity[0]).toEqual(
      expect.objectContaining({ over_capacity: true, excess_hours: 8 }),
    );
  });
});
