## Why

The attendance history screen already surfaces approved leave entries, but those rows are currently dead ends. Users can see that a leave request exists on a day, yet they cannot tap through to inspect the leave details from the same screen.

## What Changes

- Add navigation from leave-derived rows in attendance history to the existing leave detail screen.
- Reuse the existing leave detail route and pass the selected `LeaveRequest` so the detail page can render immediately.
- Keep attendance check-in/out rows unchanged so this change stays scoped to leave-derived entries only.

## Capabilities

### New Capabilities
- `attendance-history-leave-detail-navigation`: Allows users to open leave request details directly from leave entries in the attendance history screen.

### Modified Capabilities
- None.

## Impact

- Affected attendance-history row rendering in `apps/mobile/lib/features/hr/screens/attendance_history_screen.dart`
- Reuses existing HR leave routing in `apps/mobile/lib/core/router/app_router.dart`
- Reuses the existing leave detail UI in `apps/mobile/lib/features/hr/screens/leave_detail_screen.dart`
- No backend or API contract changes are expected
