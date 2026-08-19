import type { OdooAttendanceRecord } from '../../auth/services/odoo.service.js';

const HO_CHI_MINH_OFFSET_MS = 7 * 60 * 60 * 1000;

export type CompletedAttendanceDaysResult = {
  dateKeys: ReadonlySet<string>;
  dayValues: ReadonlyMap<string, number>;
  totalDays: number;
};

export type AttendanceSessionExclusionReason =
  | 'invalid_checkin'
  | 'missing_checkout'
  | 'invalid_checkout'
  | 'checkout_before_checkin'
  | 'overnight';

export type AttendanceSessionEvaluation = {
  checkin: Date | null;
  checkout: Date | null;
  dateKey: string | null;
  counted: boolean;
  exclusionReason: AttendanceSessionExclusionReason | null;
};

export function calculateCompletedAttendanceDays(
  records: readonly OdooAttendanceRecord[],
): CompletedAttendanceDaysResult {
  const dateKeys = new Set<string>();
  const dayValues = new Map<string, number>();

  for (const record of records) {
    const evaluation = evaluateAttendanceSession(record);
    if (evaluation.counted && evaluation.dateKey) {
      dateKeys.add(evaluation.dateKey);
      dayValues.set(
        evaluation.dateKey,
        getCompletedAttendanceDayValue(evaluation.dateKey),
      );
    }
  }

  return {
    dateKeys,
    dayValues,
    totalDays: [...dayValues.values()].reduce(
      (total, dayValue) => total + dayValue,
      0,
    ),
  };
}

export function getCompletedAttendanceDayValue(dateKey: string): number {
  const date = new Date(`${dateKey}T00:00:00.000Z`);
  return date.getUTCDay() === 6 ? 0.5 : 1;
}

export function evaluateAttendanceSession(
  record: OdooAttendanceRecord,
): AttendanceSessionEvaluation {
  const checkin = parseOdooUtcDateTime(record.check_in);
  if (!checkin) {
    return {
      checkin: null,
      checkout: null,
      dateKey: null,
      counted: false,
      exclusionReason: 'invalid_checkin',
    };
  }

  const dateKey = toHoChiMinhDateKey(checkin);
  if (!record.check_out) {
    return {
      checkin,
      checkout: null,
      dateKey,
      counted: false,
      exclusionReason: 'missing_checkout',
    };
  }

  const checkout = parseOdooUtcDateTime(record.check_out);
  if (!checkout) {
    return {
      checkin,
      checkout: null,
      dateKey,
      counted: false,
      exclusionReason: 'invalid_checkout',
    };
  }

  if (checkout < checkin) {
    return {
      checkin,
      checkout,
      dateKey,
      counted: false,
      exclusionReason: 'checkout_before_checkin',
    };
  }

  if (dateKey !== toHoChiMinhDateKey(checkout)) {
    return {
      checkin,
      checkout,
      dateKey,
      counted: false,
      exclusionReason: 'overnight',
    };
  }

  return {
    checkin,
    checkout,
    dateKey,
    counted: true,
    exclusionReason: null,
  };
}

export function parseOdooUtcDateTime(
  value: string | false | null | undefined,
): Date | null {
  if (typeof value !== 'string' || value.trim().length === 0) return null;

  const trimmed = value.trim();
  const isoLike = trimmed.replace(' ', 'T');
  const hasTimezone = /(?:Z|[+-]\d{2}:?\d{2})$/i.test(isoLike);
  const parsed = new Date(hasTimezone ? isoLike : `${isoLike}Z`);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

export function toHoChiMinhDateKey(date: Date): string {
  return new Date(date.getTime() + HO_CHI_MINH_OFFSET_MS)
    .toISOString()
    .substring(0, 10);
}
