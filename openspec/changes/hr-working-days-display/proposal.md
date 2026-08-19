## Why

The attendance history screen currently displays total OT hours, leave days, and WFH days, but lacks a critical metric: the actual number of working days an employee attended. This makes it difficult for both employees and administrators to quickly assess attendance compliance against the expected monthly working days (typically 24 days). Without this visibility, manual calculations are required to determine if an employee met their attendance obligations.

## What Changes

- Add "working days" calculation to attendance summary that counts unique dates with check-in records
- Display working days count prominently in the attendance history screen alongside existing metrics (OT hours, leave days, WFH days)
- Apply business rule: Saturday attendance counts as 1.0 full working day even if only half-day work (4 hours)
- Sunday attendance is excluded from working days count
- Backend API returns `working_days` field in attendance summary response
- Frontend shows "Ngày công thực tế" (Actual Working Days) card in the summary section

## Capabilities

### New Capabilities
- `working-days-calculation`: Calculate and display actual working days from attendance records, applying weekday-based counting rules (Monday-Saturday = 1 day, Sunday = 0 days)

### Modified Capabilities
<!-- No existing capability requirements are changing - this is a pure addition -->

## Impact

**Backend:**
- `apps/api/src/modules/hr/services/attendance.service.ts` - Add working days calculation logic to `getSummary()` method
- `apps/api/src/modules/hr/attendance.controller.ts` - API response schema includes new field

**Frontend:**
- `apps/mobile/lib/features/hr/data/hr_models.dart` - Add `workingDays` field to `AttendanceCalendarData` model
- `apps/mobile/lib/features/hr/providers/hr_providers.dart` - Update provider to parse and expose working days data
- `apps/mobile/lib/features/hr/screens/attendance_history_screen.dart` - Add summary cards section displaying working days metric

**Database:** No schema changes required - uses existing `attendance` table data
