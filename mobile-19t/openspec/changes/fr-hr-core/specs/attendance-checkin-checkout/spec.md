## ADDED Requirements

### Requirement: Checkin via REST API
The system SHALL expose `POST /hr/attendance/checkin` accepting `{ timestamp, lat, lng, device_id }`. The endpoint SHALL validate: user has not already checked in today, timestamp is not older than 24 hours, lat/lng are valid coordinates (not null). On success, INSERT into `attendance` table and return the attendance record with status 201.

#### Scenario: Successful checkin
- **WHEN** an employee sends POST /hr/attendance/checkin with valid GPS and timestamp
- **THEN** the system creates an attendance record with checkin_at, lat, lng, device_id and returns 201

#### Scenario: Duplicate checkin same day
- **WHEN** an employee who already checked in today sends another checkin request
- **THEN** the system returns 409 Conflict with message "Bạn đã checkin hôm nay"

#### Scenario: Timestamp too old
- **WHEN** an employee sends checkin with timestamp older than 24 hours
- **THEN** the system returns 400 Bad Request with message "Timestamp quá cũ"

### Requirement: Checkout via REST API
The system SHALL expose `POST /hr/attendance/checkout` accepting `{ timestamp, lat, lng, device_id }`. The endpoint SHALL validate: user has checked in today and has not yet checked out. On success, UPDATE the attendance record with checkout_at, checkout GPS, calculate total_hours and ot_hours, return the updated record.

#### Scenario: Successful checkout
- **WHEN** an employee who checked in at 8:00 sends checkout at 17:30
- **THEN** the system updates the record with checkout_at, total_hours=9.5, ot_hours=1.5 (if standard=8h)

#### Scenario: Checkout without checkin
- **WHEN** an employee who has not checked in today sends a checkout request
- **THEN** the system returns 400 Bad Request with message "Bạn chưa checkin hôm nay"

#### Scenario: Duplicate checkout
- **WHEN** an employee who already checked out today sends another checkout request
- **THEN** the system returns 409 Conflict with message "Bạn đã checkout hôm nay"

### Requirement: OT auto-calculation on checkout
The system SHALL calculate overtime hours on checkout using the formula: `total_hours = (checkout_at - checkin_at) in decimal hours`, `ot_hours = max(0, total_hours - standard_hours_per_day)`. The `standard_hours_per_day` value SHALL be read from the `payroll_config` table (default 8.0).

#### Scenario: OT calculated correctly
- **WHEN** standard_hours is 8.0 and employee works 10.5 hours
- **THEN** total_hours=10.5 and ot_hours=2.5

#### Scenario: No OT when under standard hours
- **WHEN** standard_hours is 8.0 and employee works 7.0 hours
- **THEN** total_hours=7.0 and ot_hours=0.0

### Requirement: Offline-first checkin/checkout on Flutter
The system SHALL save checkin/checkout to Drift local database immediately with status `pending_sync`. The system SHALL then attempt to POST to the server. If offline, the record SHALL remain in Drift and sync when connectivity returns. The original timestamp from the local record SHALL be used (not the sync time).

#### Scenario: Checkin while offline
- **WHEN** the user taps Checkin while offline
- **THEN** the record is saved locally with GPS and timestamp, and synced to server when online

#### Scenario: Sync pending records on reconnect
- **WHEN** the app regains network connectivity and has pending_sync attendance records
- **THEN** each record is POSTed to the server using the original timestamp

### Requirement: GPS capture on checkin/checkout
The system SHALL capture GPS coordinates (latitude, longitude) using the `geolocator` package when the user taps Checkin or Checkout. The system SHALL request location permission if not granted. If GPS is unavailable, the system SHALL allow checkin/checkout with null coordinates and log a warning.

#### Scenario: GPS captured successfully
- **WHEN** the user taps Checkin with GPS enabled
- **THEN** the system captures lat/lng and includes them in the checkin request

#### Scenario: GPS permission denied
- **WHEN** the user taps Checkin but GPS permission is denied
- **THEN** the system allows checkin with null coordinates and shows a warning "Không thể lấy vị trí GPS"

### Requirement: Attendance database table
The system SHALL create an `attendance` table with columns: `id` (uuid PK), `user_id` (uuid FK→users), `checkin_at` (timestamptz NOT NULL), `checkout_at` (timestamptz nullable), `checkin_lat` (decimal(10,7)), `checkin_lng` (decimal(10,7)), `checkout_lat` (decimal(10,7)), `checkout_lng` (decimal(10,7)), `device_id` (varchar), `total_hours` (decimal(4,2)), `ot_hours` (decimal(4,2)), `odoo_synced` (boolean DEFAULT false), `odoo_synced_at` (timestamptz), `created_at` (timestamptz DEFAULT now()). Index on `(user_id, checkin_at DESC)`.

#### Scenario: Table supports attendance records
- **WHEN** a checkin is recorded
- **THEN** a row is inserted with all required fields and the record is queryable by user and date

### Requirement: Flutter AttendanceScreen UI
The system SHALL provide an AttendanceScreen showing: today's checkin status (not checked in / checked in at HH:mm / checked out at HH:mm), large Checkin and Checkout buttons (Checkout disabled until checked in), today's total hours and OT if checked out. The screen SHALL be the default view of the HR tab.

#### Scenario: User not checked in
- **WHEN** the user opens the HR tab and has not checked in today
- **THEN** the Checkin button is enabled, Checkout button is disabled, status shows "Chưa checkin"

#### Scenario: User checked in but not out
- **WHEN** the user has checked in at 8:00 but not checked out
- **THEN** the Checkin button is disabled, Checkout button is enabled, status shows "Đã checkin lúc 08:00"

