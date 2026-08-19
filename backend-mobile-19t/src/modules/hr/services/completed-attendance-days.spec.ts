import type { OdooAttendanceRecord } from '../../auth/services/odoo.service.js';
import {
  calculateCompletedAttendanceDays,
  parseOdooUtcDateTime,
  toHoChiMinhDateKey,
} from './completed-attendance-days.js';

function attendance(
  id: number,
  checkIn: string,
  checkOut: string | false,
): OdooAttendanceRecord {
  return {
    id,
    employee_id: [200, 'Employee'],
    check_in: checkIn,
    check_out: checkOut,
  };
}

describe('calculateCompletedAttendanceDays', () => {
  it('counts one completed same-day attendance session', () => {
    const result = calculateCompletedAttendanceDays([
      attendance(1, '2026-08-07 01:00:00', '2026-08-07 10:00:00'),
    ]);

    expect(result.totalDays).toBe(1);
    expect([...result.dateKeys]).toEqual(['2026-08-07']);
  });

  it('counts multiple completed sessions on one ICT date only once', () => {
    const result = calculateCompletedAttendanceDays([
      attendance(1, '2026-08-07 01:00:00', '2026-08-07 04:00:00'),
      attendance(2, '2026-08-07 06:00:00', '2026-08-07 10:00:00'),
    ]);

    expect(result.totalDays).toBe(1);
  });

  it('excludes open, invalid, reversed, and overnight sessions', () => {
    const result = calculateCompletedAttendanceDays([
      attendance(1, '2026-08-08 01:00:00', false),
      attendance(2, 'invalid', '2026-08-08 10:00:00'),
      attendance(3, '2026-08-08 10:00:00', '2026-08-08 01:00:00'),
      attendance(4, '2026-08-08 15:00:00', '2026-08-08 18:00:00'),
    ]);

    expect(result.totalDays).toBe(0);
  });

  it('uses ICT dates for early-morning sessions', () => {
    const result = calculateCompletedAttendanceDays([
      attendance(1, '2026-08-07 18:30:00', '2026-08-07 20:00:00'),
    ]);

    expect([...result.dateKeys]).toEqual(['2026-08-08']);
  });

  it('counts Saturday as half a day and Sunday as one day', () => {
    const result = calculateCompletedAttendanceDays([
      attendance(1, '2026-08-08T01:00:00.000Z', '2026-08-08T10:00:00.000Z'),
      attendance(2, '2026-08-09T01:00:00.000Z', '2026-08-09T10:00:00.000Z'),
    ]);

    expect(result.totalDays).toBe(1.5);
    expect([...result.dateKeys]).toEqual(['2026-08-08', '2026-08-09']);
    expect([...result.dayValues.entries()]).toEqual([
      ['2026-08-08', 0.5],
      ['2026-08-09', 1],
    ]);
  });

  it('parses Odoo timestamps as UTC and preserves explicit offsets', () => {
    expect(parseOdooUtcDateTime('2026-08-08 01:00:00')?.toISOString()).toBe(
      '2026-08-08T01:00:00.000Z',
    );
    expect(
      parseOdooUtcDateTime('2026-08-08T08:00:00+07:00')?.toISOString(),
    ).toBe('2026-08-08T01:00:00.000Z');
    expect(parseOdooUtcDateTime('not-a-date')).toBeNull();
  });

  it('creates ICT date keys around the UTC day boundary', () => {
    expect(toHoChiMinhDateKey(new Date('2026-08-07T17:00:00.000Z'))).toBe(
      '2026-08-08',
    );
    expect(toHoChiMinhDateKey(new Date('2026-08-07T16:59:59.999Z'))).toBe(
      '2026-08-07',
    );
  });
});
