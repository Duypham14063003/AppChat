import { DailyReportStatisticsService } from './daily-report-statistics.service';

describe('DailyReportStatisticsService', () => {
  const users = [
    { id: 'admin', name: 'Admin', is_active: true, is_bot: false },
    { id: 'normal', name: 'Normal', is_active: true, is_bot: false },
    { id: 'morning-off', name: 'Morning Off', is_active: true, is_bot: false },
    {
      id: 'afternoon-off',
      name: 'Afternoon Off',
      is_active: true,
      is_bot: false,
    },
    { id: 'full-off', name: 'Full Off', is_active: true, is_bot: false },
    { id: 'wfh', name: 'WFH', is_active: true, is_bot: false },
  ];

  const makeService = (
    overrides: {
      reports?: any[];
      leaveDays?: any[];
      done?: string | null;
    } = {},
  ) => {
    const adminQb = {
      innerJoin: jest.fn().mockReturnThis(),
      select: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      getRawMany: jest.fn().mockResolvedValue([{ user_id: 'admin' }]),
    };
    const leaveQb = {
      innerJoinAndSelect: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      getMany: jest.fn().mockResolvedValue(overrides.leaveDays ?? []),
    };
    const userRepo = { find: jest.fn().mockResolvedValue(users) };
    const userRoleRepo = {
      createQueryBuilder: jest.fn().mockReturnValue(adminQb),
    };
    const reportRepo = {
      find: jest.fn().mockResolvedValue(overrides.reports ?? []),
    };
    const chatService = {
      sendMessage: jest.fn().mockResolvedValue({ id: 'message' }),
    };
    const redis = {
      getCache: jest.fn().mockResolvedValue(overrides.done ?? null),
      setCacheIfAbsent: jest.fn().mockResolvedValue(true),
      setCache: jest.fn().mockResolvedValue(undefined),
      deleteCache: jest.fn().mockResolvedValue(undefined),
    };
    const entityRepo = {
      findOne: jest.fn().mockResolvedValue({}),
      save: jest.fn(),
      create: jest.fn(),
      insert: jest.fn(),
    };
    const dataSource = { getRepository: jest.fn().mockReturnValue(entityRepo) };
    const service = new DailyReportStatisticsService(
      userRepo as any,
      userRoleRepo as any,
      reportRepo as any,
      {} as any,
      { createQueryBuilder: jest.fn().mockReturnValue(leaveQb) } as any,
      chatService as any,
      redis as any,
      dataSource as any,
    );
    return { service, chatService, redis };
  };

  const leave = (
    userId: string,
    duration: number,
    part: string | null,
    type = 'annual',
  ) => ({
    duration_days: duration,
    half_day_part: part,
    leave_request: { user_id: userId, type, status: 'approved' },
  });

  it('defers morning leave, requires morning for afternoon leave, and excludes admins', async () => {
    const { service, chatService } = makeService({
      leaveDays: [
        leave('morning-off', 0.5, 'morning'),
        leave('afternoon-off', 0.5, 'afternoon'),
        leave('full-off', 1, null),
        leave('wfh', 1, null, 'wfh'),
      ],
      reports: [{ user_id: 'normal', report_type: 'morning' }],
    });

    await service.publish('morning', '2026-07-20');

    const content = chatService.sendMessage.mock.calls[0][1].content as string;
    expect(content).not.toContain('Admin');
    expect(content).toContain('Morning Off - OFF buổi sáng');
    expect(content).toContain('Afternoon Off');
    expect(content).toContain('Full Off - OFF cả ngày');
    expect(content).toContain('WFH');
  });

  it('checks deferred morning and evening reports for half-day employees', async () => {
    const { service, chatService } = makeService({
      leaveDays: [
        leave('morning-off', 0.5, 'morning'),
        leave('afternoon-off', 0.5, 'afternoon'),
      ],
      reports: [
        { user_id: 'afternoon-off', report_type: 'morning' },
        { user_id: 'morning-off', report_type: 'evening' },
      ],
    });

    await service.publish('evening', '2026-07-20');

    const content = chatService.sendMessage.mock.calls[0][1].content as string;
    expect(content).toContain('Morning Off - chưa bổ sung báo cáo sáng');
    expect(content).toContain('Afternoon Off');
  });

  it('combines two half-day rows into a full-day exemption', async () => {
    const { service, chatService } = makeService({
      leaveDays: [
        leave('full-off', 0.5, 'morning'),
        leave('full-off', 0.5, 'afternoon'),
      ],
    });
    await service.publish('evening', '2026-07-20');
    expect(chatService.sendMessage.mock.calls[0][1].content).toContain(
      'Full Off - OFF cả ngày',
    );
  });

  it('uses a stable message id and skips a completed window', async () => {
    const first = makeService();
    await first.service.publish('morning', '2026-07-20');
    await first.service.publish('morning', '2026-07-20');
    const ids = first.chatService.sendMessage.mock.calls.map(
      (call: any[]) => call[1].id,
    );
    expect(new Set(ids).size).toBe(1);

    const completed = makeService({ done: '1' });
    await completed.service.publish('morning', '2026-07-20');
    expect(completed.chatService.sendMessage).not.toHaveBeenCalled();
  });

  it('does not mark failed publication as complete', async () => {
    const fixture = makeService();
    fixture.chatService.sendMessage.mockRejectedValue(
      new Error('chat unavailable'),
    );
    await expect(
      fixture.service.publish('morning', '2026-07-20'),
    ).rejects.toThrow('chat unavailable');
    expect(fixture.redis.setCache).not.toHaveBeenCalled();
  });
});
