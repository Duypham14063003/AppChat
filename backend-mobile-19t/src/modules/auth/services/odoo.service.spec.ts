import axios from 'axios';
import { ConfigService } from '@nestjs/config';
import { OdooService } from './odoo.service';

jest.mock('axios');

describe('OdooService', () => {
  let service: OdooService;
  const mockedAxios = jest.mocked(axios);

  beforeEach(() => {
    mockedAxios.post.mockReset();

    const config = {
      get: jest.fn((key: string, defaultValue?: string) => {
        switch (key) {
          case 'ODOO_URL':
            return 'https://erp.19t.vn';
          case 'ODOO_DB':
            return 'erp_oddo';
          case 'ODOO_SERVICE_USERNAME':
            return 'service-account';
          case 'ODOO_SERVICE_PASSWORD':
            return 'service-password';
          default:
            return defaultValue ?? '';
        }
      }),
    } as unknown as ConfigService;

    service = new OdooService(config);
  });

  it('scopes auto-checkout lookup to the Asia/Ho_Chi_Minh workday', async () => {
    const fetchAttendanceHistory = jest
      .spyOn(service, 'fetchAttendanceHistory')
      .mockResolvedValue([]);
    const scheduledAt = new Date('2026-04-23T11:05:00.000Z');

    await service.findAutoCheckoutAttendance(200, scheduledAt);

    expect(fetchAttendanceHistory).toHaveBeenCalledWith(
      200,
      new Date('2026-04-22T17:00:00.000Z'),
      new Date('2026-04-23T17:00:00.000Z'),
    );
  });

  it('uses the same Vietnam local day for today and open-session reads across 07:00 UTC', async () => {
    const fetchAttendanceHistory = jest
      .spyOn(service, 'fetchAttendanceHistory')
      .mockResolvedValue([]);

    await service.fetchTodayAttendance(
      200,
      new Date('2026-04-22T23:30:00.000Z'),
    );
    await service.findOpenAttendance(200, new Date('2026-04-23T00:30:00.000Z'));

    expect(fetchAttendanceHistory).toHaveBeenNthCalledWith(
      1,
      200,
      new Date('2026-04-22T17:00:00.000Z'),
      new Date('2026-04-23T17:00:00.000Z'),
    );
    expect(fetchAttendanceHistory).toHaveBeenNthCalledWith(
      2,
      200,
      new Date('2026-04-22T17:00:00.000Z'),
      new Date('2026-04-23T17:00:00.000Z'),
    );
  });

  it('returns only an open attendance whose check-in is not later than the scheduled cutoff', async () => {
    jest.spyOn(service, 'fetchAttendanceHistory').mockResolvedValue([
      {
        id: 999,
        employee_id: [200, 'Employee'],
        check_in: '2026-04-23 11:10:00',
        check_out: false,
      },
      {
        id: 777,
        employee_id: [200, 'Employee'],
        check_in: '2026-04-23 10:30:00',
        check_out: false,
      },
    ]);

    const result = await service.findAutoCheckoutAttendance(
      200,
      new Date('2026-04-23T11:05:00.000Z'),
    );

    expect(result?.id).toBe(777);
  });

  it('returns null when the only open attendance starts after the scheduled cutoff', async () => {
    jest.spyOn(service, 'fetchAttendanceHistory').mockResolvedValue([
      {
        id: 999,
        employee_id: [200, 'Employee'],
        check_in: '2026-04-23 11:10:00',
        check_out: false,
      },
    ]);

    const result = await service.findAutoCheckoutAttendance(
      200,
      new Date('2026-04-23T11:05:00.000Z'),
    );

    expect(result).toBeNull();
  });

  it('fetches task stages with project pipeline metadata', async () => {
    mockedAxios.post
      .mockResolvedValueOnce({ data: { result: { uid: 55 } } } as never)
      .mockResolvedValueOnce({
        data: {
          result: [
            {
              id: 10,
              name: 'Backlog',
              sequence: 1,
              project_ids: [99],
            },
          ],
        },
      } as never);

    const result = await service.fetchTaskStages();

    expect(result).toEqual([
      { id: 10, name: 'Backlog', sequence: 1, project_ids: [99] },
    ]);
    const secondCall = mockedAxios.post.mock.calls[1] as [
      string,
      {
        params: {
          args: [
            string,
            number,
            string,
            string,
            string,
            unknown[],
            { fields: string[] },
          ];
        };
      },
      { timeout: number },
    ];

    expect(secondCall[0]).toBe('https://erp.19t.vn/jsonrpc');
    expect(secondCall[1].params.args[3]).toBe('project.task.type');
    expect(secondCall[1].params.args[4]).toBe('search_read');
    expect(secondCall[1].params.args[6].fields).toEqual([
      'name',
      'sequence',
      'project_ids',
    ]);
    expect(secondCall[2]).toEqual({ timeout: 30000 });
  });

  it('resolves the next task stage from the matching project pipeline', async () => {
    jest.spyOn(service, 'fetchTaskStages').mockResolvedValue([
      { id: 1, name: 'Backlog', sequence: 1, project_ids: [42] },
      { id: 2, name: 'Coding', sequence: 2, project_ids: [42] },
      { id: 3, name: 'Review', sequence: 3, project_ids: [42] },
      { id: 9, name: 'Other', sequence: 2, project_ids: [100] },
    ]);

    const result = await service.resolveNextTaskStage(42, 1);

    expect(result).toEqual({
      id: 2,
      name: 'Coding',
      sequence: 2,
      project_ids: [42],
    });
  });

  it('returns null when the next stage is ambiguous within the project pipeline', async () => {
    jest.spyOn(service, 'fetchTaskStages').mockResolvedValue([
      { id: 1, name: 'Backlog', sequence: 1, project_ids: [42] },
      { id: 2, name: 'Coding A', sequence: 2, project_ids: [42] },
      { id: 3, name: 'Coding B', sequence: 2, project_ids: [42] },
    ]);

    const result = await service.resolveNextTaskStage(42, 1);

    expect(result).toBeNull();
  });

  it('prefers explicit project stages over global stages when resolving the next stage', async () => {
    jest.spyOn(service, 'fetchTaskStages').mockResolvedValue([
      { id: 143, name: 'Backlog', sequence: 0, project_ids: [16] },
      { id: 144, name: 'Coding', sequence: 1, project_ids: [16] },
      { id: 19, name: 'Internal', sequence: 1, project_ids: [] },
      { id: 99, name: 'Dev In Progress', sequence: 1, project_ids: [] },
      { id: 166, name: 'Coding', sequence: 1, project_ids: [] },
    ]);

    const result = await service.inspectNextTaskStage(16, 143);

    expect(result).toEqual({
      status: 'advance',
      nextStage: {
        id: 144,
        name: 'Coding',
        sequence: 1,
        project_ids: [16],
      },
    });
  });

  it('falls back to global stages when the project has no explicit pipeline', async () => {
    jest.spyOn(service, 'fetchTaskStages').mockResolvedValue([
      { id: 98, name: 'Prioritized', sequence: 0, project_ids: [] },
      { id: 99, name: 'Dev In Progress', sequence: 1, project_ids: [] },
      { id: 100, name: 'Ready for Testing', sequence: 2, project_ids: [] },
    ]);

    const result = await service.resolveNextTaskStage(999, 98);

    expect(result).toEqual({
      id: 99,
      name: 'Dev In Progress',
      sequence: 1,
      project_ids: [],
    });
  });

  it('keeps unresolved_pipeline when the explicit project pipeline itself is ambiguous', async () => {
    jest.spyOn(service, 'fetchTaskStages').mockResolvedValue([
      { id: 174, name: 'Backlog', sequence: 0, project_ids: [21] },
      { id: 175, name: 'Working', sequence: 1, project_ids: [21] },
      { id: 197, name: 'Working', sequence: 1, project_ids: [21] },
      { id: 19, name: 'Internal', sequence: 1, project_ids: [] },
    ]);

    const result = await service.inspectNextTaskStage(21, 174);

    expect(result).toEqual({ status: 'unresolved_pipeline' });
  });

  it('writes the resolved next task stage back to Odoo', async () => {
    mockedAxios.post
      .mockResolvedValueOnce({ data: { result: { uid: 55 } } } as never)
      .mockResolvedValueOnce({ data: { result: true } } as never);

    const result = await service.advanceTaskStage(321, 654);

    expect(result).toBe(true);
    const secondCall = mockedAxios.post.mock.calls[1] as [
      string,
      {
        params: {
          args: [
            string,
            number,
            string,
            string,
            string,
            [number[], { stage_id: number }],
          ];
        };
      },
      { timeout: number },
    ];

    expect(secondCall[0]).toBe('https://erp.19t.vn/jsonrpc');
    expect(secondCall[1].params.args).toEqual([
      'erp_oddo',
      55,
      'service-password',
      'project.task',
      'write',
      [[321], { stage_id: 654 }],
    ]);
    expect(secondCall[2]).toEqual({ timeout: 30000 });
  });
});
