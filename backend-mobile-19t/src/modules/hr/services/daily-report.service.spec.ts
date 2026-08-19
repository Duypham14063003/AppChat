import { DailyReportService } from './daily-report.service';

type DailyReportServiceTestHandle = DailyReportService & {
  logStageSyncOutcome: (
    outcome: 'advanced' | 'skipped',
    metadata: Record<string, unknown>,
  ) => void;
};

function createRepoMock() {
  return {
    findOne: jest.fn(),
    findOneOrFail: jest.fn(),
    find: jest.fn(),
    create: jest.fn((value: Record<string, unknown>) => ({ ...value })),
    save: jest.fn((value: unknown) => Promise.resolve(value)),
    delete: jest.fn(),
    createQueryBuilder: jest.fn(),
  };
}

describe('DailyReportService', () => {
  function createService() {
    const reportRepo = createRepoMock();
    const itemRepo = createRepoMock();
    const userRepo = createRepoMock();
    const leaveRepo = createRepoMock();
    const chatService = { sendMessage: jest.fn() };
    const rewardsService = {
      applyDailyReportPoints: jest.fn(),
      reconcileDailyReportPoints: jest.fn(),
      getOrCreateWallet: jest.fn(),
    };
    const odooService = {
      fetchTaskById: jest.fn(),
      inspectNextTaskStage: jest.fn(),
      resolveNextTaskStage: jest.fn(),
      advanceTaskStage: jest.fn(),
    };
    const auditLogService = {
      logDailyReportEvent: jest.fn(),
    };
    const txReportRepo = createRepoMock();
    const txItemRepo = createRepoMock();
    const dataSource = {
      transaction: jest.fn((callback: (manager: any) => unknown) =>
        Promise.resolve(
          callback({
            getRepository: jest.fn((entity: unknown) => {
              if (
                typeof entity === 'function' &&
                'name' in entity &&
                entity.name === 'DailyReport'
              ) {
                return txReportRepo;
              }
              return txItemRepo;
            }),
          }),
        ),
      ),
      getRepository: jest.fn(),
    };

    const service = new DailyReportService(
      reportRepo as never,
      itemRepo as never,
      userRepo as never,
      leaveRepo as never,
      chatService as never,
      rewardsService as never,
      odooService as never,
      auditLogService as never,
      dataSource as never,
    );

    jest
      .spyOn(service as any, 'ensureBotSetup')
      .mockResolvedValue(undefined as never);

    return {
      service,
      reportRepo,
      itemRepo,
      userRepo,
      leaveRepo,
      chatService,
      rewardsService,
      odooService,
      auditLogService,
      txReportRepo,
      txItemRepo,
      dataSource,
    };
  }

  it('includes both points and re-report reason in report message', () => {
    const { service } = createService();

    const message = service['formatReportMessage'](
      {
        name: 'Alice',
        job_title: 'Developer',
      } as never,
      {
        report_type: 'evening',
        report_role: 'dev',
        projects: [
          {
            project_id: 1,
            project_name: 'Project A',
            tasks: [
              {
                id: '101',
                name: 'Repeat task',
                status: 'done',
                stage_id: [1, 'Done'],
              },
            ],
          },
        ],
      },
      new Map([
        [
          '101',
          {
            points: 3,
            reason: 'Task đã ăn điểm trước đó, báo cáo lại',
          },
        ],
      ]),
      3,
    );

    expect(message).toContain('(+3p - Task đã ăn điểm trước đó, báo cáo lại)');
  });

  it('advances morning tasks when no prior report snapshot exists', async () => {
    const {
      service,
      reportRepo,
      userRepo,
      chatService,
      odooService,
      auditLogService,
      txReportRepo,
      txItemRepo,
    } = createService();

    reportRepo.findOne.mockResolvedValueOnce(null).mockResolvedValueOnce(null);
    userRepo.findOneOrFail.mockResolvedValue({ id: 'u1', name: 'Alice' });
    txReportRepo.create.mockImplementation((value) => value);
    txReportRepo.save.mockResolvedValue({
      id: 'report-1',
      total_points_earned: 0,
    });
    txItemRepo.create.mockImplementation((value) => value);
    txItemRepo.save.mockResolvedValue([]);
    odooService.fetchTaskById.mockResolvedValue({ stage_id: [10, 'Backlog'] });
    odooService.inspectNextTaskStage.mockResolvedValue({
      status: 'advance',
      nextStage: {
        id: 11,
        name: 'Coding',
        sequence: 2,
      },
    });
    odooService.advanceTaskStage.mockResolvedValue(true);
    chatService.sendMessage.mockResolvedValue({ id: 'chat-1' });
    reportRepo.save.mockImplementation((value: unknown) =>
      Promise.resolve(value),
    );

    await service.submitReport('u1', {
      report_type: 'morning',
      report_role: 'dev',
      projects: [
        {
          project_id: 99,
          project_name: 'Project A',
          tasks: [
            {
              id: '101',
              name: 'Task A',
              stage_id: [10, 'Backlog'],
            },
          ],
        },
      ],
    });

    expect(odooService.fetchTaskById).toHaveBeenCalledWith(101);
    expect(odooService.inspectNextTaskStage).toHaveBeenCalledWith(99, 10);
    expect(odooService.advanceTaskStage).toHaveBeenCalledWith(101, 11);
    expect(auditLogService.logDailyReportEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'daily_report.submitted',
        reportId: 'report-1',
        status: 'success',
      }),
    );
    expect(auditLogService.logDailyReportEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'daily_report.stage_sync.advanced',
        reportId: 'report-1',
        status: 'advanced',
      }),
    );
  });

  it('does not advance QC morning tasks in submit flow', async () => {
    const {
      service,
      reportRepo,
      userRepo,
      chatService,
      odooService,
      auditLogService,
      txReportRepo,
      txItemRepo,
    } = createService();

    reportRepo.findOne.mockResolvedValueOnce(null);
    userRepo.findOneOrFail.mockResolvedValue({ id: 'u1', name: 'Alice' });
    txReportRepo.create.mockImplementation((value) => value);
    txReportRepo.save.mockResolvedValue({
      id: 'report-qc-1',
      total_points_earned: 0,
    });
    txItemRepo.create.mockImplementation((value) => value);
    txItemRepo.save.mockResolvedValue([]);
    chatService.sendMessage.mockResolvedValue({ id: 'chat-1' });
    reportRepo.save.mockImplementation((value: unknown) =>
      Promise.resolve(value),
    );

    await service.submitReport('u1', {
      report_type: 'morning',
      report_role: 'qc',
      projects: [
        {
          project_id: 99,
          project_name: 'Project A',
          tasks: [
            {
              id: '101',
              name: 'Task A',
              stage_id: [10, 'Staging'],
            },
          ],
        },
      ],
    });

    expect(odooService.fetchTaskById).not.toHaveBeenCalled();
    expect(odooService.inspectNextTaskStage).not.toHaveBeenCalled();
    expect(odooService.advanceTaskStage).not.toHaveBeenCalled();
    expect(auditLogService.logDailyReportEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'daily_report.submitted',
        reportId: 'report-qc-1',
        status: 'success',
      }),
    );
    expect(auditLogService.logDailyReportEvent).not.toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'daily_report.stage_sync.advanced',
      }),
    );
  });

  it('skips carry-over morning tasks that already existed in the previous report', async () => {
    const {
      service,
      reportRepo,
      userRepo,
      chatService,
      odooService,
      auditLogService,
      txReportRepo,
      txItemRepo,
    } = createService();

    reportRepo.findOne
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce({
        id: 'report-prev',
        projects: [
          {
            project_id: 99,
            project_name: 'Project A',
            tasks: [
              {
                id: '101',
                name: 'Task A',
                stage_id: [10, 'Backlog'],
              },
            ],
          },
        ],
      });
    userRepo.findOneOrFail.mockResolvedValue({ id: 'u1', name: 'Alice' });
    txReportRepo.create.mockImplementation((value) => value);
    txReportRepo.save.mockResolvedValue({
      id: 'report-1',
      total_points_earned: 0,
    });
    txItemRepo.create.mockImplementation((value) => value);
    txItemRepo.save.mockResolvedValue([]);
    chatService.sendMessage.mockResolvedValue({ id: 'chat-1' });
    reportRepo.save.mockImplementation((value: unknown) =>
      Promise.resolve(value),
    );

    await service.submitReport('u1', {
      report_type: 'morning',
      report_role: 'dev',
      projects: [
        {
          project_id: 99,
          project_name: 'Project A',
          tasks: [
            {
              id: '101',
              name: 'Task A',
              stage_id: [10, 'Backlog'],
            },
          ],
        },
      ],
    });

    expect(odooService.fetchTaskById).not.toHaveBeenCalled();
    expect(odooService.inspectNextTaskStage).not.toHaveBeenCalled();
    expect(odooService.advanceTaskStage).not.toHaveBeenCalled();
    expect(auditLogService.logDailyReportEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'daily_report.stage_sync.skipped',
        reportId: 'report-1',
        status: 'skipped',
        reason: 'carry_over_previous_report',
      }),
    );
  });

  it('advances newly introduced morning tasks when a previous report exists', async () => {
    const {
      service,
      reportRepo,
      userRepo,
      chatService,
      odooService,
      txReportRepo,
      txItemRepo,
    } = createService();

    reportRepo.findOne
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce({
        id: 'report-prev',
        projects: [
          {
            project_id: 99,
            project_name: 'Project A',
            tasks: [
              {
                id: '100',
                name: 'Old Task',
                stage_id: [10, 'Backlog'],
              },
            ],
          },
        ],
      });
    userRepo.findOneOrFail.mockResolvedValue({ id: 'u1', name: 'Alice' });
    txReportRepo.create.mockImplementation((value) => value);
    txReportRepo.save.mockResolvedValue({
      id: 'report-1',
      total_points_earned: 0,
    });
    txItemRepo.create.mockImplementation((value) => value);
    txItemRepo.save.mockResolvedValue([]);
    odooService.fetchTaskById.mockResolvedValue({
      project_id: [99, 'Project A'],
      stage_id: [10, 'Backlog'],
    });
    odooService.inspectNextTaskStage.mockResolvedValue({
      status: 'advance',
      nextStage: {
        id: 11,
        name: 'Coding',
        sequence: 2,
      },
    });
    odooService.advanceTaskStage.mockResolvedValue(true);
    chatService.sendMessage.mockResolvedValue({ id: 'chat-1' });
    reportRepo.save.mockImplementation((value: unknown) =>
      Promise.resolve(value),
    );

    await service.submitReport('u1', {
      report_type: 'morning',
      report_role: 'dev',
      projects: [
        {
          project_id: 99,
          project_name: 'Project A',
          tasks: [
            {
              id: '101',
              name: 'Task A',
              stage_id: [10, 'Backlog'],
            },
          ],
        },
      ],
    });

    expect(odooService.fetchTaskById).toHaveBeenCalledWith(101);
    expect(odooService.inspectNextTaskStage).toHaveBeenCalledWith(99, 10);
    expect(odooService.advanceTaskStage).toHaveBeenCalledWith(101, 11);
  });

  it('advances only done tasks in evening reports', async () => {
    const {
      service,
      reportRepo,
      userRepo,
      chatService,
      rewardsService,
      odooService,
      txReportRepo,
      txItemRepo,
    } = createService();

    reportRepo.findOne.mockResolvedValueOnce(null).mockResolvedValueOnce({
      id: 'morning-1',
    });
    userRepo.findOneOrFail.mockResolvedValue({
      id: 'u1',
      name: 'Alice',
      job_title: 'Developer',
    });
    txReportRepo.create.mockImplementation((value) => value);
    txReportRepo.save.mockResolvedValue({
      id: 'report-1',
      total_points_earned: 0,
    });
    txItemRepo.create.mockImplementation((value) => value);
    txItemRepo.save.mockResolvedValue([]);
    odooService.fetchTaskById.mockResolvedValue({
      project_id: [77, 'Project A'],
      stage_id: [20, 'Coding'],
    });
    odooService.inspectNextTaskStage.mockResolvedValue({
      status: 'advance',
      nextStage: {
        id: 21,
        name: 'Review',
        sequence: 3,
      },
    });
    odooService.advanceTaskStage.mockResolvedValue(true);
    rewardsService.applyDailyReportPoints.mockResolvedValue({
      totalPoints: 5,
      taskPointsMap: new Map(),
    });
    rewardsService.getOrCreateWallet.mockResolvedValue({ balance: 50 });
    chatService.sendMessage.mockResolvedValue({ id: 'chat-1' });
    reportRepo.save.mockImplementation((value: unknown) =>
      Promise.resolve(value),
    );

    await service.submitReport('u1', {
      report_type: 'evening',
      report_role: 'dev',
      projects: [
        {
          project_id: 77,
          project_name: 'Project A',
          tasks: [
            {
              id: '101',
              name: 'Done task',
              status: 'done',
              stage_id: [20, 'Coding'],
            },
            {
              id: '102',
              name: 'Doing task',
              status: 'doing',
              stage_id: [20, 'Coding'],
              progress: 80,
            },
          ],
        },
      ],
    });

    expect(odooService.fetchTaskById).toHaveBeenCalledTimes(1);
    expect(odooService.fetchTaskById).toHaveBeenCalledWith(101);
    expect(odooService.inspectNextTaskStage).toHaveBeenCalledWith(77, 20);
    expect(odooService.advanceTaskStage).toHaveBeenCalledWith(101, 21);
  });

  it('advances done tasks in OT reports', async () => {
    const {
      service,
      reportRepo,
      userRepo,
      chatService,
      rewardsService,
      odooService,
      txReportRepo,
      txItemRepo,
    } = createService();

    reportRepo.findOne.mockResolvedValueOnce(null).mockResolvedValueOnce(null);
    userRepo.findOneOrFail.mockResolvedValue({
      id: 'u1',
      name: 'Alice',
      job_title: 'Developer',
    });
    txReportRepo.create.mockImplementation((value) => value);
    txReportRepo.save.mockResolvedValue({
      id: 'report-ot',
      total_points_earned: 0,
    });
    txItemRepo.create.mockImplementation((value) => value);
    txItemRepo.save.mockResolvedValue([]);
    odooService.fetchTaskById.mockResolvedValue({
      project_id: [55, 'Project OT'],
      stage_id: [30, 'Review'],
    });
    odooService.inspectNextTaskStage.mockResolvedValue({
      status: 'advance',
      nextStage: {
        id: 31,
        name: 'Done',
        sequence: 4,
      },
    });
    odooService.advanceTaskStage.mockResolvedValue(true);
    rewardsService.applyDailyReportPoints.mockResolvedValue({
      totalPoints: 2,
      taskPointsMap: new Map(),
    });
    rewardsService.getOrCreateWallet.mockResolvedValue({ balance: 10 });
    chatService.sendMessage.mockResolvedValue({ id: 'chat-ot' });
    reportRepo.save.mockImplementation((value: unknown) =>
      Promise.resolve(value),
    );

    await service.submitReport('u1', {
      report_type: 'ot',
      report_role: 'dev',
      projects: [
        {
          project_id: 55,
          project_name: 'Project OT',
          tasks: [
            {
              id: '201',
              name: 'Done OT task',
              status: 'done',
              stage_id: [30, 'Review'],
            },
          ],
        },
      ],
    });

    expect(odooService.fetchTaskById).toHaveBeenCalledWith(201);
    expect(odooService.inspectNextTaskStage).toHaveBeenCalledWith(55, 30);
    expect(odooService.advanceTaskStage).toHaveBeenCalledWith(201, 31);
  });

  it('skips advancement when the live Odoo stage no longer matches the submitted snapshot', async () => {
    const {
      service,
      reportRepo,
      userRepo,
      chatService,
      odooService,
      auditLogService,
      txReportRepo,
      txItemRepo,
    } = createService();

    reportRepo.findOne.mockResolvedValueOnce(null).mockResolvedValueOnce(null);
    userRepo.findOneOrFail.mockResolvedValue({ id: 'u1', name: 'Alice' });
    txReportRepo.create.mockImplementation((value) => value);
    txReportRepo.save.mockResolvedValue({
      id: 'report-1',
      total_points_earned: 0,
    });
    txItemRepo.create.mockImplementation((value) => value);
    txItemRepo.save.mockResolvedValue([]);
    odooService.fetchTaskById.mockResolvedValue({ stage_id: [12, 'Coding'] });
    chatService.sendMessage.mockResolvedValue({ id: 'chat-1' });
    reportRepo.save.mockImplementation((value: unknown) =>
      Promise.resolve(value),
    );

    await service.submitReport('u1', {
      report_type: 'morning',
      report_role: 'dev',
      projects: [
        {
          project_id: 99,
          project_name: 'Project A',
          tasks: [
            {
              id: '101',
              name: 'Task A',
              stage_id: [10, 'Backlog'],
            },
          ],
        },
      ],
    });

    expect(odooService.inspectNextTaskStage).not.toHaveBeenCalled();
    expect(odooService.advanceTaskStage).not.toHaveBeenCalled();
    expect(auditLogService.logDailyReportEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'daily_report.stage_sync.skipped',
        reportId: 'report-1',
        status: 'skipped',
        reason: 'stale_snapshot',
      }),
    );
  });

  it('uses the live Odoo project pipeline instead of the submitted project id', async () => {
    const {
      service,
      reportRepo,
      userRepo,
      chatService,
      odooService,
      txReportRepo,
      txItemRepo,
    } = createService();

    reportRepo.findOne.mockResolvedValueOnce(null).mockResolvedValueOnce(null);
    userRepo.findOneOrFail.mockResolvedValue({ id: 'u1', name: 'Alice' });
    txReportRepo.create.mockImplementation((value) => value);
    txReportRepo.save.mockResolvedValue({
      id: 'report-1',
      total_points_earned: 0,
    });
    txItemRepo.create.mockImplementation((value) => value);
    txItemRepo.save.mockResolvedValue([]);
    odooService.fetchTaskById.mockResolvedValue({
      project_id: [123, 'Moved Project'],
      stage_id: [10, 'Backlog'],
    });
    odooService.inspectNextTaskStage.mockResolvedValue({
      status: 'advance',
      nextStage: {
        id: 11,
        name: 'Coding',
        sequence: 2,
      },
    });
    odooService.advanceTaskStage.mockResolvedValue(true);
    chatService.sendMessage.mockResolvedValue({ id: 'chat-1' });
    reportRepo.save.mockImplementation((value: unknown) =>
      Promise.resolve(value),
    );

    await service.submitReport('u1', {
      report_type: 'morning',
      report_role: 'dev',
      projects: [
        {
          project_id: 99,
          project_name: 'Submitted Project',
          tasks: [
            {
              id: '101',
              name: 'Task A',
              stage_id: [10, 'Backlog'],
            },
          ],
        },
      ],
    });

    expect(odooService.inspectNextTaskStage).toHaveBeenCalledWith(123, 10);
  });

  it('logs terminal-stage skips distinctly from unresolved pipelines', async () => {
    const {
      service,
      reportRepo,
      userRepo,
      chatService,
      odooService,
      txReportRepo,
      txItemRepo,
    } = createService();

    reportRepo.findOne.mockResolvedValueOnce(null).mockResolvedValueOnce(null);
    userRepo.findOneOrFail.mockResolvedValue({ id: 'u1', name: 'Alice' });
    txReportRepo.create.mockImplementation((value) => value);
    txReportRepo.save.mockResolvedValue({
      id: 'report-1',
      total_points_earned: 0,
    });
    txItemRepo.create.mockImplementation((value) => value);
    txItemRepo.save.mockResolvedValue([]);
    odooService.fetchTaskById.mockResolvedValue({
      project_id: [99, 'Project A'],
      stage_id: [40, 'Done'],
    });
    odooService.inspectNextTaskStage.mockResolvedValue({
      status: 'terminal_stage',
    });
    chatService.sendMessage.mockResolvedValue({ id: 'chat-1' });
    reportRepo.save.mockImplementation((value: unknown) =>
      Promise.resolve(value),
    );
    const outcomeSpy = jest.spyOn(
      service as DailyReportServiceTestHandle,
      'logStageSyncOutcome',
    );

    await service.submitReport('u1', {
      report_type: 'morning',
      report_role: 'dev',
      projects: [
        {
          project_id: 99,
          project_name: 'Project A',
          tasks: [
            {
              id: '101',
              name: 'Task A',
              stage_id: [40, 'Done'],
            },
          ],
        },
      ],
    });

    expect(odooService.advanceTaskStage).not.toHaveBeenCalled();
    expect(outcomeSpy).toHaveBeenCalledWith(
      'skipped',
      'report-1',
      expect.objectContaining({ reason: 'terminal_stage' }),
    );
  });

  it('logs unresolved pipeline skips for custom pipeline resolution failures', async () => {
    const {
      service,
      reportRepo,
      userRepo,
      chatService,
      odooService,
      txReportRepo,
      txItemRepo,
    } = createService();

    reportRepo.findOne.mockResolvedValueOnce(null).mockResolvedValueOnce(null);
    userRepo.findOneOrFail.mockResolvedValue({ id: 'u1', name: 'Alice' });
    txReportRepo.create.mockImplementation((value) => value);
    txReportRepo.save.mockResolvedValue({
      id: 'report-1',
      total_points_earned: 0,
    });
    txItemRepo.create.mockImplementation((value) => value);
    txItemRepo.save.mockResolvedValue([]);
    odooService.fetchTaskById.mockResolvedValue({
      project_id: [99, 'Project A'],
      stage_id: [20, 'Custom'],
    });
    odooService.inspectNextTaskStage.mockResolvedValue({
      status: 'unresolved_pipeline',
    });
    chatService.sendMessage.mockResolvedValue({ id: 'chat-1' });
    reportRepo.save.mockImplementation((value: unknown) =>
      Promise.resolve(value),
    );
    const outcomeSpy = jest.spyOn(
      service as DailyReportServiceTestHandle,
      'logStageSyncOutcome',
    );

    await service.submitReport('u1', {
      report_type: 'morning',
      report_role: 'dev',
      projects: [
        {
          project_id: 99,
          project_name: 'Project A',
          tasks: [
            {
              id: '101',
              name: 'Task A',
              stage_id: [20, 'Custom'],
            },
          ],
        },
      ],
    });

    expect(odooService.advanceTaskStage).not.toHaveBeenCalled();
    expect(outcomeSpy).toHaveBeenCalledWith(
      'skipped',
      'report-1',
      expect.objectContaining({ reason: 'unresolved_pipeline' }),
    );
  });

  it('re-syncs eligible Odoo stages during morning report updates', async () => {
    const {
      service,
      reportRepo,
      itemRepo,
      userRepo,
      chatService,
      rewardsService,
      odooService,
      auditLogService,
      txReportRepo,
      txItemRepo,
    } = createService();

    reportRepo.findOne.mockResolvedValue({
      id: 'report-1',
      user_id: 'u1',
      report_type: 'morning',
      projects: [],
      note: null,
      report_role: 'dev',
      total_points_earned: 0,
    });
    itemRepo.find.mockResolvedValue([
      { report_id: 'report-1', task_id: '100', task_name: 'Old task' },
    ]);
    userRepo.findOneOrFail.mockResolvedValue({ id: 'u1', name: 'Alice' });
    txReportRepo.save.mockImplementation((value) => Promise.resolve(value));
    txItemRepo.create.mockImplementation((value) => value);
    txItemRepo.save.mockResolvedValue([]);
    odooService.fetchTaskById.mockResolvedValue({
      project_id: [77, 'Project A'],
      stage_id: [20, 'Coding'],
    });
    odooService.inspectNextTaskStage.mockResolvedValue({
      status: 'advance',
      nextStage: {
        id: 21,
        name: 'Review',
        sequence: 3,
      },
    });
    odooService.advanceTaskStage.mockResolvedValue(true);
    chatService.sendMessage.mockResolvedValue({ id: 'chat-2' });
    reportRepo.save.mockImplementation((value: any) => Promise.resolve(value));

    await service.updateReport('u1', 'report-1', {
      report_type: 'morning',
      report_role: 'dev',
      projects: [
        {
          project_id: 77,
          project_name: 'Project A',
          tasks: [
            {
              id: '101',
              name: 'Task A',
              stage_id: [20, 'Coding'],
            },
          ],
        },
      ],
    });

    expect(odooService.fetchTaskById).toHaveBeenCalledWith(101);
    expect(odooService.inspectNextTaskStage).toHaveBeenCalledWith(77, 20);
    expect(odooService.advanceTaskStage).toHaveBeenCalledWith(101, 21);
    expect(rewardsService.reconcileDailyReportPoints).not.toHaveBeenCalled();
    expect(auditLogService.logDailyReportEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'daily_report.updated',
        reportId: 'report-1',
        status: 'success',
      }),
    );
  });

  it('does not re-sync unchanged morning tasks on repeated edits', async () => {
    const {
      service,
      reportRepo,
      itemRepo,
      userRepo,
      chatService,
      rewardsService,
      odooService,
      txReportRepo,
      txItemRepo,
    } = createService();

    reportRepo.findOne.mockResolvedValue({
      id: 'report-1',
      user_id: 'u1',
      report_type: 'morning',
      projects: [
        {
          project_id: 77,
          project_name: 'Project A',
          tasks: [
            {
              id: '101',
              name: 'Task A',
              stage_id: [20, 'Coding'],
            },
          ],
        },
      ],
      note: null,
      report_role: 'dev',
      total_points_earned: 0,
    });
    itemRepo.find.mockResolvedValue([]);
    userRepo.findOneOrFail.mockResolvedValue({ id: 'u1', name: 'Alice' });
    txReportRepo.save.mockImplementation((value) => Promise.resolve(value));
    txItemRepo.create.mockImplementation((value) => value);
    txItemRepo.save.mockResolvedValue([]);
    chatService.sendMessage.mockResolvedValue({ id: 'chat-2' });
    reportRepo.save.mockImplementation((value: any) => Promise.resolve(value));

    await service.updateReport('u1', 'report-1', {
      report_type: 'morning',
      report_role: 'dev',
      projects: [
        {
          project_id: 77,
          project_name: 'Project A',
          tasks: [
            {
              id: '101',
              name: 'Task A',
              stage_id: [20, 'Coding'],
            },
          ],
        },
      ],
    });

    expect(odooService.fetchTaskById).not.toHaveBeenCalled();
    expect(odooService.inspectNextTaskStage).not.toHaveBeenCalled();
    expect(odooService.advanceTaskStage).not.toHaveBeenCalled();
    expect(rewardsService.reconcileDailyReportPoints).not.toHaveBeenCalled();
  });

  it('does not advance QC morning tasks on repeated edits', async () => {
    const {
      service,
      reportRepo,
      itemRepo,
      userRepo,
      chatService,
      rewardsService,
      odooService,
      txReportRepo,
      txItemRepo,
    } = createService();

    reportRepo.findOne.mockResolvedValue({
      id: 'report-1',
      user_id: 'u1',
      report_type: 'morning',
      projects: [
        {
          project_id: 77,
          project_name: 'Project A',
          tasks: [
            {
              id: '101',
              name: 'Task A',
              stage_id: [20, 'Staging'],
            },
          ],
        },
      ],
      note: null,
      report_role: 'qc',
      total_points_earned: 0,
    });
    itemRepo.find.mockResolvedValue([]);
    userRepo.findOneOrFail.mockResolvedValue({ id: 'u1', name: 'Alice' });
    txReportRepo.save.mockImplementation((value) => Promise.resolve(value));
    txItemRepo.create.mockImplementation((value) => value);
    txItemRepo.save.mockResolvedValue([]);
    chatService.sendMessage.mockResolvedValue({ id: 'chat-2' });
    reportRepo.save.mockImplementation((value: any) => Promise.resolve(value));

    await service.updateReport('u1', 'report-1', {
      report_type: 'morning',
      report_role: 'qc',
      projects: [
        {
          project_id: 77,
          project_name: 'Project A',
          tasks: [
            {
              id: '101',
              name: 'Task A',
              stage_id: [21, 'Production'],
            },
          ],
        },
      ],
    });

    expect(odooService.fetchTaskById).not.toHaveBeenCalled();
    expect(odooService.inspectNextTaskStage).not.toHaveBeenCalled();
    expect(odooService.advanceTaskStage).not.toHaveBeenCalled();
    expect(rewardsService.reconcileDailyReportPoints).not.toHaveBeenCalled();
  });

  it('rejects attempts to change report type during updates', async () => {
    const { service, reportRepo } = createService();

    reportRepo.findOne.mockResolvedValue({
      id: 'report-1',
      user_id: 'u1',
      report_type: 'evening',
    });

    await expect(
      service.updateReport('u1', 'report-1', {
        report_type: 'morning',
        report_role: 'dev',
        projects: [],
      }),
    ).rejects.toThrow('Report type cannot be changed');
  });

  it('re-syncs done tasks and reconciles rewards during evening report updates', async () => {
    const {
      service,
      reportRepo,
      itemRepo,
      userRepo,
      chatService,
      rewardsService,
      odooService,
      auditLogService,
      txReportRepo,
      txItemRepo,
    } = createService();

    reportRepo.findOne.mockResolvedValue({
      id: 'report-1',
      user_id: 'u1',
      report_type: 'evening',
      projects: [],
      note: null,
      report_role: 'dev',
      total_points_earned: 2,
    });
    itemRepo.find.mockResolvedValue([
      { report_id: 'report-1', task_id: '100', task_name: 'Old task' },
    ]);
    userRepo.findOneOrFail.mockResolvedValue({
      id: 'u1',
      name: 'Alice',
      job_title: 'Developer',
    });
    txReportRepo.save.mockImplementation((value) => Promise.resolve(value));
    txItemRepo.create.mockImplementation((value) => value);
    txItemRepo.save.mockResolvedValue([]);
    odooService.fetchTaskById.mockResolvedValue({
      project_id: [77, 'Project A'],
      stage_id: [20, 'Coding'],
    });
    odooService.inspectNextTaskStage.mockResolvedValue({
      status: 'advance',
      nextStage: {
        id: 21,
        name: 'Review',
        sequence: 3,
      },
    });
    odooService.advanceTaskStage.mockResolvedValue(true);
    rewardsService.reconcileDailyReportPoints.mockResolvedValue({
      totalPoints: 7,
      netDelta: 5,
      adjustedTaskCount: 1,
      taskPointsMap: new Map([
        ['101', { points: 7, reason: 'Reward updated' }],
        ['102', { points: 0, reason: 'Task chưa hoàn thành (Doing)' }],
      ]),
    });
    rewardsService.getOrCreateWallet.mockResolvedValue({ balance: 70 });
    chatService.sendMessage.mockResolvedValue({ id: 'chat-2' });
    reportRepo.save.mockImplementation((value: any) => Promise.resolve(value));

    const result = await service.updateReport('u1', 'report-1', {
      report_type: 'evening',
      report_role: 'dev',
      projects: [
        {
          project_id: 77,
          project_name: 'Project A',
          tasks: [
            {
              id: '101',
              name: 'Done task',
              status: 'done',
              stage_id: [20, 'Coding'],
            },
          ],
        },
      ],
    });

    expect(odooService.fetchTaskById).toHaveBeenCalledTimes(1);
    expect(odooService.fetchTaskById).toHaveBeenCalledWith(101);
    expect(odooService.inspectNextTaskStage).toHaveBeenCalledWith(77, 20);
    expect(odooService.advanceTaskStage).toHaveBeenCalledWith(101, 21);
    expect(rewardsService.reconcileDailyReportPoints).toHaveBeenCalledWith(
      'u1',
      'Developer',
      'report-1',
      [expect.objectContaining({ id: '101' })],
    );
    expect(auditLogService.logDailyReportEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'daily_report.reward_reconciliation.applied',
        reportId: 'report-1',
        status: 'adjusted',
      }),
    );
    expect(result).toEqual(
      expect.objectContaining({
        total_points_earned: 7,
        chat_message_id: 'chat-2',
      }),
    );
  });

  it('does not re-sync tasks that were already done in the previous evening snapshot', async () => {
    const {
      service,
      reportRepo,
      itemRepo,
      userRepo,
      chatService,
      rewardsService,
      odooService,
      txReportRepo,
      txItemRepo,
    } = createService();

    reportRepo.findOne.mockResolvedValue({
      id: 'report-1',
      user_id: 'u1',
      report_type: 'evening',
      projects: [
        {
          project_id: 77,
          project_name: 'Project A',
          tasks: [
            {
              id: '101',
              name: 'Done task',
              status: 'done',
              stage_id: [20, 'Coding'],
            },
            {
              id: '102',
              name: 'Doing task',
              status: 'doing',
              stage_id: [20, 'Coding'],
            },
          ],
        },
      ],
      note: null,
      report_role: 'dev',
      total_points_earned: 2,
    });
    itemRepo.find.mockResolvedValue([]);
    userRepo.findOneOrFail.mockResolvedValue({
      id: 'u1',
      name: 'Alice',
      job_title: 'Developer',
    });
    txReportRepo.save.mockImplementation((value) => Promise.resolve(value));
    txItemRepo.create.mockImplementation((value) => value);
    txItemRepo.save.mockResolvedValue([]);
    odooService.fetchTaskById.mockResolvedValue({
      project_id: [77, 'Project A'],
      stage_id: [20, 'Coding'],
    });
    odooService.inspectNextTaskStage.mockResolvedValue({
      status: 'advance',
      nextStage: {
        id: 21,
        name: 'Review',
        sequence: 3,
      },
    });
    odooService.advanceTaskStage.mockResolvedValue(true);
    rewardsService.reconcileDailyReportPoints.mockResolvedValue({
      totalPoints: 7,
      netDelta: 5,
      adjustedTaskCount: 1,
      taskPointsMap: new Map([
        ['101', { points: 7, reason: 'Reward updated' }],
        ['102', { points: 0, reason: 'Task chưa hoàn thành (Doing)' }],
      ]),
    });
    rewardsService.getOrCreateWallet.mockResolvedValue({ balance: 70 });
    chatService.sendMessage.mockResolvedValue({ id: 'chat-2' });
    reportRepo.save.mockImplementation((value: any) => Promise.resolve(value));

    await service.updateReport('u1', 'report-1', {
      report_type: 'evening',
      report_role: 'dev',
      projects: [
        {
          project_id: 77,
          project_name: 'Project A',
          tasks: [
            {
              id: '101',
              name: 'Done task',
              status: 'done',
              stage_id: [20, 'Coding'],
            },
            {
              id: '102',
              name: 'Doing task',
              status: 'done',
              stage_id: [20, 'Coding'],
            },
          ],
        },
      ],
    });

    expect(odooService.fetchTaskById).toHaveBeenCalledTimes(1);
    expect(odooService.fetchTaskById).toHaveBeenCalledWith(102);
    expect(odooService.inspectNextTaskStage).toHaveBeenCalledWith(77, 20);
    expect(odooService.advanceTaskStage).toHaveBeenCalledWith(102, 21);
    expect(rewardsService.reconcileDailyReportPoints).toHaveBeenCalledWith(
      'u1',
      'Developer',
      'report-1',
      expect.arrayContaining([
        expect.objectContaining({ id: '101' }),
        expect.objectContaining({ id: '102' }),
      ]),
    );
  });

  it('logs reward reconciliation failures during evening report updates', async () => {
    const {
      service,
      reportRepo,
      itemRepo,
      userRepo,
      chatService,
      rewardsService,
      odooService,
      auditLogService,
      txReportRepo,
      txItemRepo,
    } = createService();

    reportRepo.findOne.mockResolvedValue({
      id: 'report-1',
      user_id: 'u1',
      report_type: 'evening',
      projects: [],
      note: null,
      report_role: 'dev',
      total_points_earned: 2,
    });
    itemRepo.find.mockResolvedValue([]);
    userRepo.findOneOrFail.mockResolvedValue({
      id: 'u1',
      name: 'Alice',
      job_title: 'Developer',
    });
    txReportRepo.save.mockImplementation((value) => Promise.resolve(value));
    txItemRepo.create.mockImplementation((value) => value);
    txItemRepo.save.mockResolvedValue([]);
    odooService.fetchTaskById.mockResolvedValue({
      project_id: [77, 'Project A'],
      stage_id: [20, 'Coding'],
    });
    odooService.inspectNextTaskStage.mockResolvedValue({
      status: 'advance',
      nextStage: {
        id: 21,
        name: 'Review',
        sequence: 3,
      },
    });
    odooService.advanceTaskStage.mockResolvedValue(true);
    rewardsService.reconcileDailyReportPoints.mockRejectedValue(
      new Error('reward failure'),
    );
    chatService.sendMessage.mockResolvedValue({ id: 'chat-2' });

    await expect(
      service.updateReport('u1', 'report-1', {
        report_type: 'evening',
        report_role: 'dev',
        projects: [
          {
            project_id: 77,
            project_name: 'Project A',
            tasks: [
              {
                id: '101',
                name: 'Done task',
                status: 'done',
                stage_id: [20, 'Coding'],
              },
            ],
          },
        ],
      }),
    ).rejects.toThrow('reward failure');

    expect(auditLogService.logDailyReportEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'daily_report.reward_reconciliation.failed',
        reportId: 'report-1',
        status: 'failed',
        reason: 'exception',
      }),
    );
  });

  it('lists public reports with filters and pagination metadata', async () => {
    const { service, reportRepo } = createService();
    const qb = createQueryBuilderMock();

    reportRepo.createQueryBuilder.mockReturnValue(qb);
    qb.getCount.mockResolvedValue(3);
    qb.getRawMany.mockResolvedValue([
      {
        id: 'report-1',
        user_id: 'user-1',
        user_name: 'Alice',
        report_date: '2026-07-14',
        report_type: 'evening',
        report_role: 'dev',
        projects: [{ project_id: 1, tasks: [] }],
        note: 'done',
        chat_message_id: null,
        total_points_earned: 5,
        created_at: new Date('2026-07-14T10:00:00.000Z'),
        updated_at: new Date('2026-07-14T10:05:00.000Z'),
      },
      {
        id: 'report-2',
        user_id: 'user-2',
        user_name: 'Bob',
        report_date: '2026-07-13',
        report_type: 'morning',
        report_role: 'qc',
        projects: [],
        note: null,
        chat_message_id: null,
        total_points_earned: 0,
        created_at: new Date('2026-07-13T10:00:00.000Z'),
        updated_at: new Date('2026-07-13T10:00:00.000Z'),
      },
    ]);

    const result = await service.listPublicReports({
      report_type: 'evening',
      user_name: 'Ali',
      page: 2,
      limit: 2,
    });

    expect(reportRepo.createQueryBuilder).toHaveBeenCalledWith('report');
    expect(qb.andWhere).toHaveBeenCalledWith(
      'report.report_type = :reportType',
      {
        reportType: 'evening',
      },
    );
    expect(qb.andWhere).toHaveBeenCalledWith('user.name ILIKE :userName', {
      userName: '%Ali%',
    });
    expect(qb.offset).toHaveBeenCalledWith(2);
    expect(qb.limit).toHaveBeenCalledWith(2);
    expect(result).toEqual({
      items: [
        expect.objectContaining({
          id: 'report-1',
          user_name: 'Alice',
          report_type: 'evening',
        }),
        expect.objectContaining({
          id: 'report-2',
          user_name: 'Bob',
        }),
      ],
      total: 3,
      page: 2,
      limit: 2,
      has_more: false,
    });
  });

  it('returns a public report by id when present', async () => {
    const { service, reportRepo } = createService();
    const qb = createQueryBuilderMock();

    reportRepo.createQueryBuilder.mockReturnValue(qb);
    qb.getRawOne.mockResolvedValue({
      id: 'report-1',
      user_id: 'user-1',
      user_name: 'Alice',
      report_date: '2026-07-14',
      report_type: 'evening',
      report_role: 'dev',
      projects: [],
      note: 'done',
      chat_message_id: null,
      total_points_earned: 3,
      created_at: new Date('2026-07-14T10:00:00.000Z'),
      updated_at: new Date('2026-07-14T10:05:00.000Z'),
    });

    const result = await service.getPublicReportById('report-1');

    expect(qb.where).toHaveBeenCalledWith('report.id = :id', {
      id: 'report-1',
    });
    expect(result).toEqual(
      expect.objectContaining({
        id: 'report-1',
        user_name: 'Alice',
        total_points_earned: 3,
      }),
    );
  });

  it('returns null for an unknown public report id', async () => {
    const { service, reportRepo } = createService();
    const qb = createQueryBuilderMock();

    reportRepo.createQueryBuilder.mockReturnValue(qb);
    qb.getRawOne.mockResolvedValue(null);

    await expect(service.getPublicReportById('missing')).resolves.toBeNull();
  });
});

function createQueryBuilderMock() {
  return {
    leftJoin: jest.fn().mockReturnThis(),
    select: jest.fn().mockReturnThis(),
    andWhere: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    orderBy: jest.fn().mockReturnThis(),
    addOrderBy: jest.fn().mockReturnThis(),
    offset: jest.fn().mockReturnThis(),
    limit: jest.fn().mockReturnThis(),
    getCount: jest.fn(),
    getRawMany: jest.fn(),
    getRawOne: jest.fn(),
  };
}
