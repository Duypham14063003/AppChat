import { PocDemoCoordination1716810000000 } from './1716810000000-PocDemoCoordination';

describe('PocDemoCoordination migration', () => {
  it('creates constrained and reversible PoC coordination storage', async () => {
    const query = jest.fn().mockResolvedValue(undefined);
    const migration = new PocDemoCoordination1716810000000();

    await migration.up({ query } as any);
    const statements = query.mock.calls.map(([sql]) => String(sql));

    expect(statements).toEqual(
      expect.arrayContaining([
        expect.stringContaining('CREATE SEQUENCE "poc_code_sequence"'),
        expect.stringContaining('CREATE TABLE "pocs"'),
        expect.stringContaining('"developer_user_id" uuid'),
        expect.stringContaining('CHK_pocs_assignment_plan'),
        expect.stringContaining('UQ_poc_notification_delivery'),
        expect.stringContaining('UQ_poc_weekly_report_week'),
      ]),
    );

    query.mockClear();
    await migration.down({ query } as any);
    expect(query.mock.calls.map(([sql]) => String(sql))).toEqual([
      'DROP TABLE "poc_weekly_reports"',
      'DROP TABLE "poc_notification_events"',
      'DROP TABLE "poc_history"',
      'DROP TABLE "pocs"',
      'DROP SEQUENCE "poc_code_sequence"',
    ]);
  });
});
