import { EmployeeBankQr1716800000000 } from './1716800000000-EmployeeBankQr';

describe('EmployeeBankQr migration', () => {
  it('adds nullable payment fields and a reversible source constraint', async () => {
    const query = jest.fn().mockResolvedValue(undefined);
    const runner = { query } as any;
    const migration = new EmployeeBankQr1716800000000();

    await migration.up(runner);
    expect(query.mock.calls.map(([sql]) => sql)).toEqual(
      expect.arrayContaining([
        expect.stringContaining('ADD COLUMN "bank_code"'),
        expect.stringContaining('ADD COLUMN "bank_qr_image_url"'),
        expect.stringContaining('CHK_employee_profiles_bank_qr_source'),
      ]),
    );

    query.mockClear();
    await migration.down(runner);
    expect(query).toHaveBeenCalledWith(
      expect.stringContaining('DROP COLUMN "bank_code"'),
    );
  });
});
