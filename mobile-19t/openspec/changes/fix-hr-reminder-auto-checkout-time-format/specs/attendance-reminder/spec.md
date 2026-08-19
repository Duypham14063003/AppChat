## ADDED Requirements

### Requirement: Scheduled HR reminder jobs are registered at startup
The system SHALL register repeatable BullMQ jobs for checkin reminder, checkout reminder, and auto-checkout during HR module startup so that reminder execution does not depend on manual queue inserts.

#### Scenario: Reminder schedulers exist after boot
- **WHEN** the backend application starts with the HR module enabled
- **THEN** the `hr-reminders` queue contains stable repeatable schedulers for `checkin-reminder`, `checkout-reminder`, and `auto-checkout`

### Requirement: Auto-checkout uses configured checkout time
The system SHALL set `checkout_at` for auto-checked-out attendance records to the current business date combined with `payroll_config.auto_checkout_time`, rather than the worker execution timestamp.

#### Scenario: Queue executes later than the configured time
- **WHEN** `auto_checkout_time` is `23:59` and the worker processes the job at `00:01` local clock time due to queue jitter
- **THEN** the stored auto-checkout timestamp uses the configured `23:59` business cutoff for the intended day

#### Scenario: Auto-checkout hours are recalculated from configured time
- **WHEN** an open attendance record is auto-checked out using the configured cutoff time
- **THEN** `total_hours` and `ot_hours` are recalculated from that configured checkout timestamp

### Requirement: HR reminder notifications open the attendance screen
The mobile app SHALL route push-notification taps with reminder payload types `hr_checkin_reminder`, `hr_checkout_reminder`, and `hr_auto_checkout` to the HR attendance screen.

#### Scenario: User taps a checkin reminder notification
- **WHEN** the app receives a notification tap with data `{ type: "hr_checkin_reminder" }`
- **THEN** the app navigates the user to `/hr`

#### Scenario: User taps an auto-checkout notification
- **WHEN** the app receives a notification tap with data `{ type: "hr_auto_checkout" }`
- **THEN** the app navigates the user to `/hr`
