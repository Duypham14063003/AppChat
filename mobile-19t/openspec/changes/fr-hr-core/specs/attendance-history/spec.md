## ADDED Requirements

### Requirement: Attendance history list via REST API
The system SHALL expose `GET /hr/attendance` accepting optional query params `from` (date), `to` (date), `user_id` (uuid, admin only). Returns paginated attendance records ordered by `checkin_at DESC`. Employees see only their own records. Admins can filter by user_id to see team data.

#### Scenario: Employee views own history
- **WHEN** an employee sends GET /hr/attendance?from=2026-03-01&to=2026-03-31
- **THEN** the system returns their attendance records for March 2026

#### Scenario: Admin views team member history
- **WHEN** an admin sends GET /hr/attendance?user_id=abc-123&from=2026-03-01&to=2026-03-31
- **THEN** the system returns attendance records for user abc-123

#### Scenario: Non-admin attempts to view other user
- **WHEN** a regular employee sends GET /hr/attendance?user_id=other-user-id
- **THEN** the system returns 403 Forbidden

### Requirement: Attendance summary via REST API
The system SHALL expose `GET /hr/attendance/summary` accepting `from` and `to` date params. Returns aggregated data: total_days_worked, total_hours, total_ot_hours, days_late (checkin after standard start time), days_absent (workdays with no checkin). Uses payroll_config for standard hours.

#### Scenario: Monthly summary
- **WHEN** an employee requests summary for March 2026
- **THEN** the system returns { total_days: 20, total_hours: 168.5, total_ot: 8.5, days_late: 2, days_absent: 1 }

### Requirement: Flutter AttendanceHistoryScreen with calendar and list
The system SHALL provide an AttendanceHistoryScreen with two views: (1) Calendar view using `table_calendar` showing colored dots per day (green=on-time, yellow=late, red=absent, blue=OT), (2) List view showing each day's checkin time, checkout time, total hours, OT hours, and status. Tapping a calendar day scrolls the list to that date.

#### Scenario: Calendar view shows attendance status
- **WHEN** the user opens attendance history for March 2026
- **THEN** the calendar shows colored indicators for each workday based on attendance status

#### Scenario: List view shows daily details
- **WHEN** the user views the list for a day they worked 9.5 hours
- **THEN** the list item shows checkin time, checkout time, total: 9.5h, OT: 1.5h, status: "Tăng ca"

### Requirement: Attendance status classification
The system SHALL classify each attendance day with a status: "Đúng giờ" (checkin before or at standard start), "Trễ" (checkin after standard start), "Tăng ca" (has OT hours > 0), "Vắng" (workday with no attendance record). Standard start time is derived from payroll_config.

#### Scenario: On-time classification
- **WHEN** standard start is 08:00 and employee checks in at 07:55
- **THEN** status is "Đúng giờ"

#### Scenario: Late classification
- **WHEN** standard start is 08:00 and employee checks in at 08:15
- **THEN** status is "Trễ"

