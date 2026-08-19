## ADDED Requirements

### Requirement: Calculate working days from attendance records
The system SHALL calculate the total number of working days by counting unique dates that have attendance check-in records, applying weekday-based business rules.

#### Scenario: Monday to Friday attendance counted as full day
- **WHEN** an employee has check-in records on weekdays (Monday through Friday)
- **THEN** each unique date SHALL count as 1.0 working day

#### Scenario: Saturday attendance counted as full day
- **WHEN** an employee has a check-in record on Saturday
- **THEN** it SHALL count as 1.0 working day regardless of hours worked

#### Scenario: Sunday attendance not counted
- **WHEN** an employee has a check-in record on Sunday
- **THEN** it SHALL NOT be counted toward working days total

#### Scenario: Multiple check-ins on same day counted once
- **WHEN** an employee has multiple check-in records on the same calendar date
- **THEN** that date SHALL count as only 1.0 working day

### Requirement: Backend API returns working days in summary
The attendance summary API endpoint SHALL include a `working_days` field in the response that contains the calculated working days count.

#### Scenario: Summary endpoint includes working days
- **WHEN** client requests attendance summary for a date range via GET /hr/attendance/summary
- **THEN** response SHALL include `working_days` field with numeric value

#### Scenario: Working days calculation spans date range
- **WHEN** client specifies `from` and `to` query parameters
- **THEN** working days SHALL be calculated only for attendance records within that date range (inclusive)

### Requirement: Frontend displays working days metric
The attendance history screen SHALL display the working days count prominently alongside existing metrics (OT hours, leave days, WFH days).

#### Scenario: Summary card shows working days
- **WHEN** user views the attendance history screen for a month
- **THEN** a summary card labeled "Ngày công thực tế" SHALL display the working days count

#### Scenario: Working days updates when month changes
- **WHEN** user navigates to a different month in the calendar
- **THEN** the working days count SHALL update to reflect the selected month's data

#### Scenario: Working days shown with numeric format
- **WHEN** working days are displayed in the UI
- **THEN** the value SHALL be shown as a number with format "X ngày" (e.g., "22 ngày")
