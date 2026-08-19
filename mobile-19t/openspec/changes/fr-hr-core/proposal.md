## Why

The HR module is a core pillar of the 19T internal app alongside chat. The `HrModule` exists as an empty shell — no entities, services, controllers, or Flutter screens. The SRS defines 14 HR FRs; this change implements the 8 P0 MUST requirements covering attendance (checkin/checkout with GPS, OT calculation, history), leave management (create/approve/reject), payroll config, Odoo attendance sync, and attendance reminders with auto-checkout. Company has <50 employees, attendance is source of truth in the app (synced to Odoo).

## What Changes

Backend (NestJS — build from empty HrModule):
- New `attendance` table migration + `Attendance` TypeORM entity
- New `leave_requests` table migration + `LeaveRequest` TypeORM entity
- New `payroll_config` table migration + `PayrollConfig` TypeORM entity (singleton config: payroll start day, standard hours, reminder times, auto-checkout time)
- `AttendanceService`: checkin (validate GPS/timestamp/no-duplicate), checkout (calculate total_hours + ot_hours), get history (date range filter, user or team), get summary (per payroll period)
- `LeaveService`: create draft, submit (notify manager), approve (notify employee, sync Odoo), reject (notify employee with reason)
- `PayrollConfigService`: get/update config (admin only)
- `AttendanceController`: POST checkin, POST checkout, GET history, GET summary
- `LeaveController`: POST create, GET list, PATCH submit, PATCH approve, PATCH reject
- `PayrollConfigController`: GET config, PATCH config
- `OdooAttendanceSyncProcessor`: BullMQ cron job every 15 minutes — push unsynced attendance to Odoo `hr.attendance` via JSON-RPC
- `AttendanceReminderProcessor`: BullMQ cron job — checkin reminder, checkout reminder, auto-checkout at admin-configured times

Frontend (Flutter — build from empty hr/ directory):
- `geolocator` package for GPS capture on checkin/checkout
- `table_calendar` package for attendance history calendar view
- Drift local `LocalAttendance` table for offline-first checkin/checkout
- HR feature screens: AttendanceScreen (checkin/checkout buttons + today status), AttendanceHistoryScreen (calendar + list), LeaveListScreen, LeaveCreateScreen, LeaveDetailScreen
- HR providers: attendanceProvider, leaveListProvider, payrollConfigProvider
- HR repository: REST calls to /hr/* endpoints
- Offline queue: save checkin/checkout to Drift when offline, sync when online
- Navigation: HR tab in bottom navigation bar

## Capabilities

### New Capabilities
- `attendance-checkin-checkout`: Checkin/checkout with GPS coordinates, timestamp, device_id — server validation (no duplicate, timestamp freshness), OT auto-calculation, offline-first with Drift local storage
- `attendance-history`: Attendance history view — calendar + list format, date range filter, employee sees own data, manager sees team data, status indicators (on-time/late/OT/absent)
- `leave-management`: Leave request lifecycle — create draft, submit (notify manager), approve/reject (notify employee), leave types (annual/sick/personal), Odoo sync on approval
- `payroll-config`: Admin-configurable payroll settings — payroll period start day, standard hours per day, standard days per month, checkin/checkout reminder times, auto-checkout time
- `odoo-attendance-sync`: BullMQ batch job every 15 minutes — push unsynced attendance records to Odoo hr.attendance via JSON-RPC, retry with exponential backoff
- `attendance-reminder`: Automated push notifications for forgotten checkin/checkout + auto-checkout at configurable time — BullMQ cron jobs with admin-configurable schedule

### Modified Capabilities
<!-- No existing spec-level requirements are changing. -->

## Impact

- **Database**: 3 new tables: `attendance`, `leave_requests`, `payroll_config`. Schema already defined in `database-schema.md`.
- **API**: New endpoints under `/hr/attendance/*`, `/hr/leaves/*`, `/hr/config`. Defined in `api-specification.md`.
- **Backend modules**: `HrModule` populated with entities, services, controllers, BullMQ processors. Depends on `AuthModule` (User entity, roles), `NotificationModule` (push for reminders/leave actions).
- **Flutter**: New `features/hr/` directory with screens, providers, repository, widgets. New Drift table + schema version bump. New packages: `geolocator`, `table_calendar`.
- **Odoo integration**: New write operation to `hr.attendance` model via existing `OdooService` JSON-RPC infrastructure.
- **Navigation**: New HR tab in bottom navigation bar alongside Chat.

