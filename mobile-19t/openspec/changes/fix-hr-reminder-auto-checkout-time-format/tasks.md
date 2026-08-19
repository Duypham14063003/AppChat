## 1. Backend Time Contract

- [x] 1.1 Normalize payroll config time fields to `HH:mm` at the backend boundary used by Flutter reads and writes.
- [x] 1.2 Add or update backend tests covering `GET /hr/config` and `PATCH /hr/config` time normalization and nullable reminder values.

## 2. Reminder Scheduling And Auto-Checkout

- [x] 2.1 Register stable repeatable BullMQ schedulers for `checkin-reminder`, `checkout-reminder`, and `auto-checkout` in the HR reminder queue startup path.
- [x] 2.2 Update auto-checkout execution to derive `checkout_at` from the configured `auto_checkout_time` instead of worker execution time.
- [x] 2.3 Ensure auto-checked-out attendance rows are left ready for downstream sync and add backend tests for scheduler and auto-checkout behavior.

## 3. Mobile Payroll Config UX

- [x] 3.1 Update the payroll config screen to display all time fields in `HH:mm` format when loading config from the API.
- [x] 3.2 Replace fragile free-text editing for reminder and auto-checkout fields with a time-safe selection flow, including clear support for nullable reminder fields.
- [x] 3.3 Ensure the payroll config save path submits only valid `HH:mm` values and preserves `null` for cleared reminder fields.

## 4. HR Notification Navigation And Verification

- [x] 4.1 Extend shared push-notification tap handling so `hr_checkin_reminder`, `hr_checkout_reminder`, and `hr_auto_checkout` route to `/hr`.
- [x] 4.2 Add or update mobile tests for payroll config time formatting and HR notification tap routing.
- [ ] 4.3 Run end-to-end verification for near-future reminder and auto-checkout schedules and document any environment prerequisites for FCM-based testing.
