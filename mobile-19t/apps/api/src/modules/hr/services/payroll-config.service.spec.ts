import { PayrollConfigService } from './payroll-config.service';
import { PayrollConfig } from '../entities/payroll-config.entity';

describe('PayrollConfigService', () => {
  const buildConfig = (overrides: Partial<PayrollConfig> = {}): PayrollConfig =>
    ({
      id: 1,
      payroll_start_day: 1,
      standard_hours_per_day: 8,
      standard_days_per_month: 22,
      work_start_time: '08:00:00',
      checkin_reminder_time: '09:30:00',
      checkout_reminder_time: '18:00:00',
      auto_checkout_enabled: false,
      auto_checkout_time: '23:59:00',
      updated_at: new Date('2026-04-21T00:00:00.000Z'),
      ...overrides,
    }) as PayrollConfig;

  it('normalizes payroll config time values on read', async () => {
    const repo = {
      findOne: jest.fn().mockResolvedValue(buildConfig()),
      create: jest.fn(),
      save: jest.fn(),
    } as any;

    const service = new PayrollConfigService(repo);
    const result = await service.getConfig();

    expect(result).toMatchObject({
      work_start_time: '08:00',
      checkin_reminder_time: '09:30',
      checkout_reminder_time: '18:00',
      auto_checkout_time: '23:59',
    });
  });

  it('preserves nullable reminder values and normalizes update responses', async () => {
    const existing = buildConfig();
    const saved = buildConfig({
      checkin_reminder_time: null,
      checkout_reminder_time: '17:45:00',
      auto_checkout_enabled: true,
      auto_checkout_time: '22:15:00',
    });
    const repo = {
      findOne: jest.fn().mockResolvedValue(existing),
      create: jest.fn(),
      save: jest.fn().mockResolvedValue(saved),
    } as any;

    const service = new PayrollConfigService(repo);
    const result = await service.updateConfig({
      checkin_reminder_time: null,
      checkout_reminder_time: '17:45',
      auto_checkout_enabled: true,
      auto_checkout_time: '22:15',
    });

    expect(repo.save).toHaveBeenCalledWith(
      expect.objectContaining({
        checkin_reminder_time: null,
        checkout_reminder_time: '17:45',
        auto_checkout_enabled: true,
        auto_checkout_time: '22:15',
      }),
    );
    expect(result).toMatchObject({
      checkin_reminder_time: null,
      checkout_reminder_time: '17:45',
      auto_checkout_time: '22:15',
    });
  });
});
