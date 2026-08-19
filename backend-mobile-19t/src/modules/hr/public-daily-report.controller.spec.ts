import { NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { PublicDailyReportController } from './public-daily-report.controller.js';
import { DailyReportService } from './services/daily-report.service.js';

describe('PublicDailyReportController', () => {
  let controller: PublicDailyReportController;
  let dailyReportService: jest.Mocked<DailyReportService>;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [PublicDailyReportController],
      providers: [
        {
          provide: DailyReportService,
          useValue: {
            listPublicReports: jest.fn(),
            getPublicReportById: jest.fn(),
          },
        },
      ],
    }).compile();

    controller = module.get(PublicDailyReportController);
    dailyReportService = module.get(DailyReportService);
  });

  it('delegates public list queries to the daily report service', async () => {
    const expected = {
      items: [],
      total: 0,
      page: 1,
      limit: 100,
      has_more: false,
    };
    dailyReportService.listPublicReports.mockResolvedValue(expected as never);

    await expect(
      controller.listReports({ report_type: 'evening', page: 1, limit: 100 }),
    ).resolves.toEqual(expected);
    expect(dailyReportService.listPublicReports.mock.calls[0]).toEqual([
      {
        report_type: 'evening',
        page: 1,
        limit: 100,
      },
    ]);
  });

  it('returns a single public report when found', async () => {
    dailyReportService.getPublicReportById.mockResolvedValue({
      id: 'report-1',
      user_id: 'user-1',
      user_name: 'Alice',
      report_date: '2026-07-14',
      report_type: 'evening',
      report_role: 'dev',
      projects: [],
      note: null,
      chat_message_id: null,
      total_points_earned: 0,
      created_at: new Date('2026-07-14T10:00:00.000Z'),
      updated_at: new Date('2026-07-14T10:00:00.000Z'),
    } as never);

    await expect(controller.getReport('report-1')).resolves.toEqual(
      expect.objectContaining({
        id: 'report-1',
        user_name: 'Alice',
      }),
    );
  });

  it('throws not found when the requested report does not exist', async () => {
    dailyReportService.getPublicReportById.mockResolvedValue(null as never);

    await expect(controller.getReport('missing')).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });
});
