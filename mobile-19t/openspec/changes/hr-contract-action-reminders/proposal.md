## Why

HR needs contract reminders to drive the next contract action, not just warn that a contract is expiring. Internship and probation contracts should prompt HR to propose an official contract one week before the end date, while official contracts should prompt HR to propose renewal ten days before expiry.

## What Changes

- Add explicit HR contract action reminder behavior for internship, probation, and official contracts.
- Send internship and probation contract reminders 7 days before `end_date` with action-oriented copy for proposing an official contract.
- Send official contract reminders 10 days before `end_date` with action-oriented copy for proposing contract renewal.
- Restrict contract action reminder recipients to active users whose role name is `admin` or `manager`, case-insensitive.
- Preserve duplicate prevention so each contract/date/threshold reminder is delivered at most once.
- Preserve the existing daily organization-level contract reminder scheduler.

## Capabilities

### New Capabilities
- `hr-contract-action-reminders`: Defines contract reminder timing, recipients, notification payload semantics, and duplicate prevention for HR contract actions.

### Modified Capabilities

None.

## Impact

- Backend HR reminder service recipient filtering and notification copy/payload.
- Backend contract reminder unit tests for threshold timing, role-name-only recipients, and duplicate prevention.
- Mobile notification routing may need to recognize contract action reminder payloads and route admins/managers to the related employee contract context.
