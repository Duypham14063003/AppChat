import 'reflect-metadata';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { LeaveBalanceQueryDto } from './hr.dto';

describe('LeaveBalanceQueryDto', () => {
  it('accepts a valid year and month pair', async () => {
    const dto = plainToInstance(LeaveBalanceQueryDto, {
      year: 2026,
      month: 4,
    });

    const errors = await validate(dto);

    expect(errors).toHaveLength(0);
  });

  it('rejects an invalid month', async () => {
    const dto = plainToInstance(LeaveBalanceQueryDto, {
      year: 2026,
      month: 13,
    });

    const errors = await validate(dto);

    expect(errors.length).toBeGreaterThan(0);
  });

  it('rejects a partial period query', async () => {
    const dto = plainToInstance(LeaveBalanceQueryDto, {
      month: 4,
    });

    const errors = await validate(dto);

    expect(errors.length).toBeGreaterThan(0);
  });
});
