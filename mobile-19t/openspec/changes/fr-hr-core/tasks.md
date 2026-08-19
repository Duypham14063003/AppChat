## 1. Backend: Database Migrations & Entities

- [x] 1.1 Create migration `apps/api/src/migrations/1710700000001-Attendance.ts`: `attendance` table per schema spec — id (uuid PK), user_id (FK→users CASCADE), checkin_at (timestamptz NOT NULL), checkout_at (timestamptz nullable), checkin_lat/lng (decimal(10,7)), checkout_lat/lng (decimal(10,7)), device_id (varchar), total_hours (decimal(4,2)), ot_hours (decimal(4,2)), odoo_synced (boolean DEFAULT false), odoo_synced_at (timestamptz), created_at (timestamptz DEFAULT now()). Index on (user_id, checkin_at DESC)
- [x] 1.2 Create migration `apps/api/src/migrations/1710700000002-LeaveRequests.ts`: `leave_requests` table — id (uuid PK), user_id (FK→users CASCADE), type (varchar(30) NOT NULL), start_date (date NOT NULL), end_date (date NOT NULL), reason (text), status (varchar(20) DEFAULT 'draft'), approved_by (uuid FK→users nullable), approved_at (timestamptz), reject_reason (text), odoo_synced (boolean DEFAULT false), created_at (timestamptz DEFAULT now()). Index on (user_id, created_at DESC)
- [x] 1.3 Create migration `apps/api/src/migrations/1710700000003-PayrollConfig.ts`: `payroll_config` table — id (integer PK DEFAULT 1, CHECK id=1), payroll_start_day (integer DEFAULT 1), standard_hours_per_day (decimal(4,2) DEFAULT 8.0), standard_days_per_month (integer DEFAULT 22), work_start_time (time DEFAULT '08:00'), checkin_reminder_time (time nullable), checkout_reminder_time (time nullable), auto_checkout_enabled (boolean DEFAULT false), auto_checkout_time (time DEFAULT '23:59'), updated_at (timestamptz DEFAULT now()). INSERT default row
- [x] 1.4 Create `Attendance` TypeORM entity at `apps/api/src/modules/hr/entities/attendance.entity.ts` with ManyToOne relation to User
- [x] 1.5 Create `LeaveRequest` TypeORM entity at `apps/api/src/modules/hr/entities/leave-request.entity.ts` with ManyToOne relations to User (requester + approver)
- [x] 1.6 Create `PayrollConfig` TypeORM entity at `apps/api/src/modules/hr/entities/payroll-config.entity.ts`
- [x] 1.7 Register all 3 entities in `HrModule`'s `TypeOrmModule.forFeature()`

## 2. Backend: Attendance Service & Controller

- [x] 2.1 Create `AttendanceService` at `apps/api/src/modules/hr/services/attendance.service.ts`: inject Attendance repo, User repo, PayrollConfig repo
- [x] 2.2 Implement `checkin(userId, dto)`: validate no duplicate today (query by user_id + date), validate timestamp not > 24h old, INSERT attendance record, return created record
- [x] 2.3 Implement `checkout(userId, dto)`: find today's checkin (no checkout yet), validate exists, read standard_hours from PayrollConfig, calculate total_hours and ot_hours, UPDATE record, return updated
- [x] 2.4 Implement `getHistory(userId, from, to, targetUserId?)`: query attendance by date range, if targetUserId provided check admin role, return ordered by checkin_at DESC
- [x] 2.5 Implement `getSummary(userId, from, to)`: aggregate total_days, total_hours, total_ot, days_late (checkin after work_start_time), days_absent (workdays without attendance)
- [x] 2.6 Implement `getTodayStatus(userId)`: return today's attendance record or null
- [x] 2.7 Create DTOs: `CheckinDto` (timestamp, lat, lng, device_id), `CheckoutDto` (same), `AttendanceQueryDto` (from, to, user_id optional)
- [x] 2.8 Create `AttendanceController` at `apps/api/src/modules/hr/attendance.controller.ts`: POST /hr/attendance/checkin, POST /hr/attendance/checkout, GET /hr/attendance, GET /hr/attendance/summary, GET /hr/attendance/today

## 3. Backend: Leave Service & Controller

- [x] 3.1 Create `LeaveService` at `apps/api/src/modules/hr/services/leave.service.ts`: inject LeaveRequest repo, User repo
- [x] 3.2 Implement `create(userId, dto)`: validate dates (end >= start), validate type enum, INSERT with status 'draft', return created
- [x] 3.3 Implement `submit(userId, leaveId)`: validate ownership + status='draft', UPDATE status='submitted', push notification to all admin users
- [x] 3.4 Implement `approve(adminUserId, leaveId)`: validate admin role + status='submitted', UPDATE status='approved', set approved_by/approved_at, push notification to employee, mark odoo_synced=false
- [x] 3.5 Implement `reject(adminUserId, leaveId, rejectReason)`: validate admin role + status='submitted', UPDATE status='rejected', set reject_reason, push notification to employee
- [x] 3.6 Implement `getLeaves(userId, status?, targetUserId?)`: query with filters, employees see own only, admins see all
- [x] 3.7 Create DTOs: `CreateLeaveDto` (type, start_date, end_date, reason), `RejectLeaveDto` (reject_reason)
- [x] 3.8 Create `LeaveController` at `apps/api/src/modules/hr/leave.controller.ts`: POST /hr/leaves, GET /hr/leaves, PATCH /hr/leaves/:id/submit, PATCH /hr/leaves/:id/approve, PATCH /hr/leaves/:id/reject

## 4. Backend: Payroll Config Service & Controller

- [x] 4.1 Create `PayrollConfigService` at `apps/api/src/modules/hr/services/payroll-config.service.ts`: `getConfig()` (upsert default if not exists), `updateConfig(dto)` (partial update)
- [x] 4.2 Create `UpdatePayrollConfigDto` with optional fields, validation (payroll_start_day 1-28, standard_hours 1-24, time format HH:mm)
- [x] 4.3 Create `PayrollConfigController` at `apps/api/src/modules/hr/payroll-config.controller.ts`: GET /hr/config (any user), PATCH /hr/config (admin only via @Roles guard)

## 5. Backend: Odoo Attendance Sync

- [x] 5.1 Add `writeAttendance(odooEmployeeId, checkinAt, checkoutAt)` method to `OdooService`: call Odoo JSON-RPC `hr.attendance.create` with `{ employee_id, check_in, check_out }` using service account auth
- [x] 5.2 Create `OdooAttendanceSyncProcessor` at `apps/api/src/modules/hr/jobs/odoo-attendance-sync.processor.ts`: BullMQ processor, query attendance WHERE odoo_synced=false AND checkout_at IS NOT NULL, for each: lookup user.odoo_uid, call writeAttendance, on success mark synced
- [x] 5.3 Register BullMQ queue 'hr-odoo-sync' in HrModule, add repeatable job every 15 minutes (900000ms)
- [x] 5.4 Handle sync failures: log error, skip record (retry next cycle), handle missing odoo_uid gracefully

## 6. Backend: Attendance Reminders & Auto-Checkout

- [x] 6.1 Create `AttendanceReminderProcessor` at `apps/api/src/modules/hr/jobs/attendance-reminder.processor.ts`: BullMQ processor with 3 named jobs
- [x] 6.2 Implement `checkin-reminder` job: read checkin_reminder_time from PayrollConfig, query active users with no attendance today, send push notification to each via NotificationJobService or direct FirebaseService
- [x] 6.3 Implement `checkout-reminder` job: read checkout_reminder_time from PayrollConfig, query users with checkin today but no checkout, send push notification
- [x] 6.4 Implement `auto-checkout` job: read auto_checkout_enabled + auto_checkout_time from PayrollConfig, if enabled find attendance records today with no checkout, UPDATE checkout_at + calculate hours, send notification to each user
- [x] 6.5 Register BullMQ queue 'hr-reminders' in HrModule, schedule 3 repeatable jobs: checkin-reminder (daily at config time), checkout-reminder (daily at config time), auto-checkout (daily at config time). Jobs re-read config each run for dynamic schedule.

## 7. Backend: Wire HrModule

- [x] 7.1 Update `HrModule` imports: TypeOrmModule.forFeature (3 entities), BullModule.registerQueue (hr-odoo-sync, hr-reminders), AuthModule, NotificationModule
- [x] 7.2 Register all providers: AttendanceService, LeaveService, PayrollConfigService, OdooAttendanceSyncProcessor, AttendanceReminderProcessor
- [x] 7.3 Register all controllers: AttendanceController, LeaveController, PayrollConfigController
- [x] 7.4 Import HrModule in AppModule

## 8. Flutter: Dependencies & Drift

- [x] 8.1 Add `geolocator` package to apps/mobile/pubspec.yaml
- [x] 8.2 Add `table_calendar` package to apps/mobile/pubspec.yaml
- [x] 8.3 Add `LocalAttendance` Drift table to tables.dart: id (text PK), userId (text), checkinAt (dateTime), checkoutAt (dateTime nullable), checkinLat (real nullable), checkinLng (real nullable), totalHours (real nullable), otHours (real nullable), syncStatus (text DEFAULT 'pending_sync')
- [x] 8.4 Register LocalAttendance in @DriftDatabase, bump schema version, add migration block
- [x] 8.5 Add attendance DAO methods: insertAttendance, updateCheckout, getPendingSync, markSynced, getTodayAttendance, getAttendanceByDateRange
- [x] 8.6 Run `dart run build_runner build --delete-conflicting-outputs`

## 9. Flutter: HR Repository

- [x] 9.1 Create `HrRepository` at `apps/mobile/lib/features/hr/data/hr_repository.dart` with Dio
- [x] 9.2 Add attendance methods: `checkin(dto)` → POST /hr/attendance/checkin, `checkout(dto)` → POST /hr/attendance/checkout, `getHistory(from, to)` → GET /hr/attendance, `getSummary(from, to)` → GET /hr/attendance/summary, `getTodayStatus()` → GET /hr/attendance/today
- [x] 9.3 Add leave methods: `createLeave(dto)` → POST /hr/leaves, `getLeaves(status?)` → GET /hr/leaves, `submitLeave(id)` → PATCH, `approveLeave(id)` → PATCH, `rejectLeave(id, reason)` → PATCH
- [x] 9.4 Add config methods: `getConfig()` → GET /hr/config, `updateConfig(dto)` → PATCH /hr/config
- [x] 9.5 Create hrRepositoryProvider

## 10. Flutter: HR Providers

- [x] 10.1 Create `attendanceProvider` AsyncNotifier at `apps/mobile/lib/features/hr/providers/hr_providers.dart`: load today's status, checkin/checkout methods with GPS capture + offline-first Drift save + API call
- [x] 10.2 Create `attendanceHistoryProvider(month)` family AsyncNotifier: fetch history for given month from API
- [x] 10.3 Create `leaveListProvider` AsyncNotifier: fetch leaves from API with status filter
- [x] 10.4 Create `payrollConfigProvider` AsyncNotifier: fetch config from API
- [x] 10.5 Implement GPS capture helper: use geolocator to get current position, handle permission request, return (lat, lng) or null

## 11. Flutter: HR Screens

- [x] 11.1 Create `AttendanceScreen` at `apps/mobile/lib/features/hr/screens/attendance_screen.dart`: today's status card (checkin time, checkout time, total hours), large Checkin/Checkout buttons, quick stats (this month: days worked, OT hours)
- [x] 11.2 Create `AttendanceHistoryScreen` at `apps/mobile/lib/features/hr/screens/attendance_history_screen.dart`: table_calendar with colored markers, list view below calendar, date range selector
- [x] 11.3 Create `LeaveListScreen` at `apps/mobile/lib/features/hr/screens/leave_list_screen.dart`: filter tabs (All/Pending/Approved/Rejected), list of leave cards with status badge, FAB to create new
- [x] 11.4 Create `LeaveCreateScreen` at `apps/mobile/lib/features/hr/screens/leave_create_screen.dart`: form with type dropdown, date range picker, reason text field, Save Draft / Submit buttons
- [x] 11.5 Create `LeaveDetailScreen` at `apps/mobile/lib/features/hr/screens/leave_detail_screen.dart`: full details, approve/reject buttons for admin
- [x] 11.6 Create `PayrollConfigScreen` at `apps/mobile/lib/features/hr/screens/payroll_config_screen.dart`: form fields for all config values, admin only

## 12. Flutter: Navigation

- [x] 12.1 Add HR tab to bottom navigation bar in the app shell (alongside Chat tab)
- [x] 12.2 Create HR sub-navigation: default AttendanceScreen, tabs/buttons to History, Leaves, Config (admin)
- [x] 12.3 Add GoRouter routes: /hr (attendance), /hr/history, /hr/leaves, /hr/leaves/create, /hr/leaves/:id, /hr/config
- [x] 12.4 Wire notification tap for hr_checkin_reminder / hr_checkout_reminder → navigate to /hr

## 13. Flutter: Offline Sync

- [x] 13.1 In attendanceProvider checkin method: capture GPS → save to Drift (pending_sync) → POST to API → on success mark synced → on failure keep pending
- [x] 13.2 Create offline sync mechanism: on app start + on connectivity change, query Drift for pending_sync records, POST each to API using original timestamp
- [x] 13.3 Handle conflict: if server returns 409 (already checked in), mark local record as synced

## 14. Verification

- [x] 14.1 Run `npm run lint` in apps/api — fix issues
- [x] 14.2 Run `npm run build` in apps/api — fix TypeScript errors
- [x] 14.3 Run `npm test` in apps/api — fix broken tests
- [x] 14.4 Run `flutter analyze` in apps/mobile — fix issues
- [x] 14.5 Run `dart run build_runner build --delete-conflicting-outputs` — verify codegen
- [ ] 14.6 Test checkin/checkout flow: checkin → verify GPS captured → checkout → verify hours calculated → verify Odoo sync job picks it up
- [ ] 14.7 Test leave flow: create draft → submit → verify admin notification → approve → verify employee notification
- [ ] 14.8 Test offline: disable network → checkin → re-enable → verify sync
- [ ] 14.9 Test reminders: set reminder time to near-future → verify push notification received
- [ ] 14.10 Test auto-checkout: set auto_checkout_time to near-future → verify records updated

