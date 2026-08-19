## Context

The 19T app has an empty `HrModule` shell and empty Flutter `features/hr/` directory. The database schema for `attendance` and `leave_requests` tables is defined in `database-schema.md`. The `OdooService` already handles JSON-RPC communication (used for user sync). BullMQ infrastructure exists (used for chat push notifications). The RBAC system has roles (employee, admin). Users have `department` and `odoo_uid` fields from Odoo sync.

The SRS API spec defines endpoints: POST checkin/checkout, GET attendance/summary, POST/GET/PATCH leaves, GET holidays. The Odoo integration spec shows how to write attendance via `hr.attendance.create` JSON-RPC.

## Goals / Non-Goals

**Goals:**
- Checkin/checkout with GPS, offline-first, OT auto-calculation
- Attendance history (calendar + list view)
- Leave request lifecycle (draft → submit → approve/reject)
- Payroll config (admin-configurable)
- Odoo attendance batch sync (every 15 min)
- Attendance reminders (checkin/checkout) + auto-checkout — all admin-configurable

**Non-Goals:**
- Geofencing (HR-FR-003, P2 COULD — future)
- Leave balance tracking (HR-FR-008, P1 SHOULD — future)
- Escalation when manager absent (HR-FR-009, P2 COULD — future)
- Payroll summary report / export (HR-FR-011, P1 SHOULD — future)
- Holiday calendar (HR-FR-012, P1 SHOULD — future)
- Anti-cheat GPS validation beyond basic checks (HR-FR-014, P1 SHOULD — future)
- Manager role — use existing "admin" role as manager for now

## Decisions

### D1: Offline-first checkin/checkout via Drift

**Decision**: Save checkin/checkout to Drift local DB immediately (status: pending_sync), then POST to server. If offline, queue and sync when connectivity returns.

**Why**: Spec requires offline support. Attendance is time-sensitive — user must be able to record exact checkin time even without network. Same pattern as chat offline queue.

### D2: OT calculation — server-side on checkout

**Decision**: Calculate `total_hours` and `ot_hours` server-side when checkout is processed. Formula: `total_hours = (checkout_at - checkin_at) in decimal hours`, `ot_hours = max(0, total_hours - standard_hours_per_day)`. Standard hours from `payroll_config`.

**Why**: Server is source of truth. Prevents client-side manipulation. Config changes apply immediately to new checkouts.

### D3: `payroll_config` as singleton table

**Decision**: Single row in `payroll_config` table (id=1, upsert pattern). Contains all configurable values: payroll_start_day, standard_hours_per_day, standard_days_per_month, checkin_reminder_time, checkout_reminder_time, auto_checkout_enabled, auto_checkout_time.

**Why**: Company <50 employees, single payroll policy. Per-department config is a future enhancement. Singleton is simplest to query and update.

**Alternative**: Per-department config. Rejected for now — adds complexity without clear need for <50 employees.

### D4: Leave approval — admin role as manager

**Decision**: Users with "admin" role can approve/reject leave requests. No separate "manager" role for now.

**Why**: Company <50 employees, flat hierarchy. The RBAC system already has "admin" and "employee" roles. Adding a "manager" role is a future enhancement when org structure is more complex.

### D5: Attendance reminder — BullMQ repeatable jobs

**Decision**: Two BullMQ repeatable jobs: (1) checkin reminder runs daily at configured time, (2) checkout reminder + auto-checkout runs daily at configured time. Jobs read config from `payroll_config` table each run.

**Why**: BullMQ repeatable jobs are already used for user sync (hourly). Same pattern. Reading config each run means admin changes take effect on next cycle without restart.

### D6: Odoo attendance sync — extend OdooService

**Decision**: Add `writeAttendance(employeeId, checkinAt, checkoutAt?)` method to existing `OdooService`. The sync processor queries unsynced records and calls this method.

**Why**: Reuses existing Odoo JSON-RPC infrastructure (auth, error handling, retry). Consistent with `fetchEmployees()` pattern.

### D7: Flutter navigation — HR tab in bottom nav

**Decision**: Add HR tab to the bottom navigation bar (alongside Chat). HR tab shows AttendanceScreen as default with sub-navigation to Leave and History.

**Why**: HR is a primary feature, not buried in settings. Bottom nav is the established pattern in the app.

## Risks / Trade-offs

- **[Risk] GPS accuracy on mobile** → GPS can be inaccurate indoors. Accept ±50m accuracy. Future: geofencing (HR-FR-003) will add office boundary validation.

- **[Risk] Timezone handling** → All timestamps stored as UTC in PostgreSQL. Display in Vietnam timezone (ICT, UTC+7) on client. OT calculation uses UTC timestamps — correct as long as standard_hours is based on actual worked duration, not clock time.

- **[Risk] Odoo sync failure** → Retry with exponential backoff (2s, 4s, 8s). Records stay `odoo_synced=false` until successful. No data loss. Admin can see sync status.

- **[Trade-off] No manager role** → Admin approves all leaves. Acceptable for <50 employees. Future: add manager role with department-based approval chain.

- **[Trade-off] Auto-checkout may be inaccurate** → If user forgets to checkout, auto-checkout at configured time (e.g., 23:59) gives inflated hours. Mitigated by checkout reminder notification first. Admin can manually adjust.

