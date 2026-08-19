## Why

The HR reminder and payroll configuration flows are only partially wired today: the mobile screen exposes time fields as raw strings, the backend reminder worker exists without evidence of repeatable scheduling, and HR push notifications do not navigate users back into the attendance screen. This leaves reminder, auto-checkout, and time-format behavior inconsistent with the intended HR experience and blocks reliable verification of the feature set.

## What Changes

- Normalize payroll config time values to `HH:mm` across API responses consumed by Flutter and across all save paths from the payroll config screen.
- Update the Flutter payroll config screen to use time-safe input behavior for reminder and auto-checkout fields, including display normalization, picker-driven editing, and empty-state handling for disabled reminders.
- Add actual BullMQ scheduler wiring for checkin reminder, checkout reminder, and auto-checkout jobs so the HR reminder queue runs automatically in production.
- Align auto-checkout execution with the configured checkout time instead of the worker's wall-clock execution time, and ensure affected attendance rows are prepared for downstream sync.
- Route HR reminder notification taps to the HR attendance screen instead of ignoring non-chat notification payloads.
- Add verification coverage for the scheduling and time-format paths that were previously specified but not fully enforced.

## Capabilities

### New Capabilities
- `attendance-reminder`: Reliable scheduling and delivery behavior for checkin reminders, checkout reminders, auto-checkout execution, and HR notification deep links.
- `payroll-config`: Consistent payroll configuration time formatting and editing behavior between backend validation and the Flutter admin UI.

### Modified Capabilities

## Impact

- Mobile HR UI in `apps/mobile/lib/features/hr/screens/payroll_config_screen.dart` and app-level notification handling in `apps/mobile/lib/app.dart`.
- Mobile HR data flow in `apps/mobile/lib/features/hr/data/hr_repository.dart` and related providers.
- Backend HR reminder scheduling and execution in `apps/api/src/modules/hr/jobs/attendance-reminder.processor.ts` and `apps/api/src/modules/hr/hr.module.ts`.
- Backend payroll config DTO/service behavior in `apps/api/src/modules/hr/dto/hr.dto.ts` and `apps/api/src/modules/hr/services/payroll-config.service.ts`.
- BullMQ, Firebase push delivery, and Odoo sync readiness for auto-checked-out attendance records.
