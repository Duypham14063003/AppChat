## ADDED Requirements

### Requirement: Checkin reminder push notification
The system SHALL run a BullMQ cron job daily at the time configured in `payroll_config.checkin_reminder_time`. The job SHALL query all active users who have NOT checked in today and send each a push notification with title "Nhắc nhở checkin" and body "Bạn chưa checkin hôm nay. Bấm để checkin." with data `{ type: "hr_checkin_reminder" }`. If `checkin_reminder_time` is null, the job SHALL skip.

#### Scenario: Reminder sent to users who forgot checkin
- **WHEN** the checkin reminder job runs at 09:15 and 5 users have not checked in
- **THEN** 5 push notifications are sent, one to each user

#### Scenario: No reminder when all checked in
- **WHEN** the checkin reminder job runs and all active users have checked in
- **THEN** no notifications are sent

#### Scenario: Reminder disabled
- **WHEN** admin sets checkin_reminder_time to null
- **THEN** the checkin reminder job does not send any notifications

### Requirement: Checkout reminder push notification
The system SHALL run a BullMQ cron job daily at the time configured in `payroll_config.checkout_reminder_time`. The job SHALL query all users who have checked in today but NOT checked out, and send each a push notification with title "Nhắc nhở checkout" and body "Bạn chưa checkout hôm nay. Bấm để checkout." with data `{ type: "hr_checkout_reminder" }`. If `checkout_reminder_time` is null, the job SHALL skip.

#### Scenario: Reminder sent to users who forgot checkout
- **WHEN** the checkout reminder job runs at 18:30 and 3 users have not checked out
- **THEN** 3 push notifications are sent

#### Scenario: Reminder disabled
- **WHEN** admin sets checkout_reminder_time to null
- **THEN** the checkout reminder job does not send any notifications

### Requirement: Auto-checkout at configured time
The system SHALL run a BullMQ cron job daily at the time configured in `payroll_config.auto_checkout_time` (only if `auto_checkout_enabled = true`). The job SHALL find all attendance records for today where `checkout_at IS NULL`, set `checkout_at` to the auto_checkout_time, calculate `total_hours` and `ot_hours`, and mark the record for Odoo sync. A push notification SHALL be sent to each affected user: "Hệ thống đã tự động checkout cho bạn lúc {time}."

#### Scenario: Auto-checkout triggered
- **WHEN** auto_checkout runs at 23:59 and 2 users have not checked out
- **THEN** both records are updated with checkout_at=23:59, total_hours and ot_hours calculated, notifications sent

#### Scenario: Auto-checkout disabled
- **WHEN** auto_checkout_enabled is false
- **THEN** the auto-checkout job does not run

#### Scenario: No pending checkouts
- **WHEN** auto_checkout runs but all users have already checked out
- **THEN** no records are updated and no notifications are sent

### Requirement: Reminder job reads config dynamically
The reminder and auto-checkout jobs SHALL read `payroll_config` from the database on each execution. Admin changes to reminder times or auto-checkout settings SHALL take effect on the next job cycle without requiring server restart.

#### Scenario: Admin changes reminder time
- **WHEN** admin changes checkin_reminder_time from "09:15" to "09:30"
- **THEN** the next day's reminder runs at 09:30

