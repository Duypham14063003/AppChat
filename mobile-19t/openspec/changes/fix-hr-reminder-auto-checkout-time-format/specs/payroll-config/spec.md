## ADDED Requirements

### Requirement: Payroll config API time values are normalized for clients
The system SHALL expose payroll config time fields intended for admin editing in `HH:mm` format so that clients can read and save the same values without additional manual cleanup.

#### Scenario: Config read returns normalized reminder times
- **WHEN** an admin requests `GET /hr/config` and the stored database values include seconds such as `09:30:00`
- **THEN** the API response returns `09:30` for `checkin_reminder_time`, `checkout_reminder_time`, `work_start_time`, and `auto_checkout_time`

### Requirement: Payroll config screen uses time-safe editing flows
The Flutter payroll config screen SHALL present payroll time fields using normalized `HH:mm` display values and a time-safe editing flow that prevents accidental submission of invalid time strings.

#### Scenario: Screen loads raw database time values
- **WHEN** the mobile app loads payroll config values originating from PostgreSQL `time` columns
- **THEN** each time field is shown to the admin in `HH:mm` format

#### Scenario: Admin edits a reminder time
- **WHEN** an admin changes a reminder or auto-checkout time from the payroll config screen
- **THEN** the app submits the updated value in `HH:mm` format

### Requirement: Reminder fields can be explicitly cleared
The payroll config screen SHALL allow admins to clear nullable reminder fields so that reminder schedules can be disabled without entering placeholder text.

#### Scenario: Admin disables checkin reminder
- **WHEN** the admin clears the checkin reminder value and saves the form
- **THEN** the app sends `null` for `checkin_reminder_time`

#### Scenario: Admin leaves auto-checkout enabled
- **WHEN** the admin enables auto-checkout and saves the form
- **THEN** the app requires and submits a valid `auto_checkout_time` value in `HH:mm` format
