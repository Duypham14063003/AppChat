## Why

The attendance history screen currently shows leave and OT entries regardless of approval status. This makes the history view misleading because pending, draft, or rejected requests appear as if they were accepted calendar events.

## What Changes

- Restrict attendance history leave-derived calendar markers to approved leave and OT requests only.
- Restrict attendance history leave-derived list entries to approved leave and OT requests only.
- Keep attendance session records and OT-hours badges from attendance records unchanged.

## Capabilities

### New Capabilities
- `attendance-history-approved-leaves`: Ensures attendance history only surfaces approved leave and approved OT requests from leave records.

### Modified Capabilities
- None.

## Impact

- Affected monthly attendance-history data preparation in `apps/mobile/lib/features/hr/providers/hr_providers.dart`
- Affected calendar marker and day-entry rendering in `apps/mobile/lib/features/hr/screens/attendance_history_screen.dart`
- No API contract changes expected; client-side filtering should use the existing leave `status` field returned by `/hr/leaves`
