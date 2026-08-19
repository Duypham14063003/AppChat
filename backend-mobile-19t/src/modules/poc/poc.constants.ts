export const POC_QUEUE = 'poc-coordination';
export const POC_SYSTEM_BOT_ID = '00000000-0000-0000-0000-000000000001';

export const POC_STATUSES = [
  'unassigned',
  'assigned',
  'in_progress',
  'ready',
  'demonstrated',
  'cancelled',
] as const;
export type PocStatus = (typeof POC_STATUSES)[number];

export const POC_OUTCOMES = [
  'completed',
  'revision_required',
  'not_proceeding',
] as const;
export type PocOutcome = (typeof POC_OUTCOMES)[number];

export const POC_PRODUCT_TYPES = ['website', 'web_app', 'validation'] as const;
export type PocProductType = (typeof POC_PRODUCT_TYPES)[number];

export const POC_PRIORITIES = ['low', 'normal', 'high', 'urgent'] as const;
export type PocPriority = (typeof POC_PRIORITIES)[number];

export type PocNotificationKind = 'demo_24h' | 'demo_30m' | 'deadline';
