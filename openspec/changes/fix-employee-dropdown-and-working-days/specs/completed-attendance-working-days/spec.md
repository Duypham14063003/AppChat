## ADDED Requirements

### Requirement: Actual working days use completed same-day attendance
The system SHALL calculate actual working days from unique Asia/Ho_Chi_Minh calendar dates containing at least one attendance session with both a valid check-in and a valid check-out on that same local calendar date. A qualifying Saturday SHALL count as `0.5` actual working day; every other qualifying date SHALL count as `1` actual working day.

#### Scenario: Completed attendance session
- **WHEN** an employee checks in and checks out on the same Ho Chi Minh City calendar date
- **THEN** that non-Saturday date SHALL count as one actual working day

#### Scenario: Multiple completed sessions on one date
- **WHEN** an employee has multiple completed attendance sessions on the same Ho Chi Minh City calendar date
- **THEN** the date's weekday value SHALL be applied only once

#### Scenario: Saturday completed attendance
- **WHEN** an employee has a completed same-day attendance session on Saturday
- **THEN** that date SHALL count as `0.5` actual working day

#### Scenario: Sunday completed attendance
- **WHEN** an employee has a completed same-day attendance session on Sunday
- **THEN** that date SHALL count as one actual working day

#### Scenario: Open attendance session
- **WHEN** an attendance session has a check-in but no check-out
- **THEN** that session SHALL NOT contribute an actual working day

#### Scenario: Overnight attendance session
- **WHEN** an attendance session checks in on one Ho Chi Minh City calendar date and checks out on a later date
- **THEN** that session SHALL NOT contribute an actual working day

### Requirement: Leave and remote-work records do not create actual working days
Actual working days SHALL be attendance-only and SHALL NOT be increased by WFH, paid leave, unpaid leave, holidays, or leave-order records without qualifying completed attendance.

#### Scenario: WFH without attendance
- **WHEN** an employee has an approved WFH day but no completed same-day attendance session
- **THEN** the WFH day SHALL NOT count as an actual working day

#### Scenario: Leave without attendance
- **WHEN** an employee has paid or unpaid leave but no completed same-day attendance session
- **THEN** the leave date SHALL NOT count as an actual working day

### Requirement: Employee payroll summary exposes actual working days
The backend SHALL expose an approver-authorized employee payroll summary for a requested employee user ID and payroll month. The response SHALL identify the employee, the effective payroll-cycle boundaries, attendance-data availability, and the actual-working-days value when attendance data is available.

#### Scenario: Manager requests employee summary
- **WHEN** an admin, manager, or configured HR manager requests a valid employee and payroll month
- **THEN** the backend SHALL return that employee's summary for the backend-derived payroll cycle

#### Scenario: Unauthorized employee requests another employee
- **WHEN** a user without leave-approval permission requests another employee's payroll summary
- **THEN** the backend SHALL reject the request

#### Scenario: Valid attendance source has no qualifying dates
- **WHEN** the employee has a valid Odoo attendance mapping and the attendance fetch succeeds but no qualifying sessions exist in the cycle
- **THEN** the response SHALL report available attendance data and `0` actual working days

#### Scenario: Odoo mapping is missing
- **WHEN** the employee cannot be mapped to an Odoo employee
- **THEN** the response SHALL report attendance data as unmapped and SHALL NOT represent the result as zero actual working days

#### Scenario: Attendance source is unavailable
- **WHEN** the Odoo attendance request fails
- **THEN** the response SHALL report attendance data as unavailable and SHALL NOT represent the result as zero actual working days

### Requirement: Payroll cycles use a single backend-owned range
The employee payroll summary SHALL derive its date range from the existing payroll start-day configuration and SHALL use the same half-open cycle semantics as leave filtering and payroll export.

#### Scenario: Payroll cycle starts on day 25
- **WHEN** HR requests month `2026-08` and the configured start day is 25
- **THEN** the summary SHALL include check-ins from `2026-07-25` through `2026-08-24` and exclude check-ins on `2026-08-25`

#### Scenario: Payroll cycle crosses a year boundary
- **WHEN** HR requests January and the configured start day is greater than 1
- **THEN** the summary SHALL correctly include the applicable dates from December of the previous year

### Requirement: Leave-order screen displays selected employee actual working days
The leave-order screen SHALL display an actual-working-days metric for an individually selected employee using the selected payroll month's summary. The metric SHALL remain independent of order status and order type filters.

#### Scenario: Selected employee has working days and no orders
- **WHEN** the selected employee has qualifying attendance but no leave orders in the cycle
- **THEN** the screen SHALL display the actual-working-days value together with the empty order-list state

#### Scenario: Genuine zero working days
- **WHEN** the selected employee summary reports available attendance data and zero qualifying dates
- **THEN** the screen SHALL display `0 days` rather than hiding the metric

#### Scenario: Attendance data is not available
- **WHEN** the selected employee summary reports unmapped or unavailable attendance data
- **THEN** the screen SHALL display a non-numeric attendance-data status instead of `0 days`

#### Scenario: All employees are selected
- **WHEN** the employee filter is set to "All employees"
- **THEN** the screen SHALL NOT display an individual actual-working-days value

### Requirement: Payroll export uses the same actual-working-days rule
The payroll workbook's `CÔNG THỰC TẾ` column SHALL use the completed same-day attendance calculation defined by this capability. Other payroll values SHALL retain their existing per-date caps and payroll policy semantics so removing WFH from actual working days does not unintentionally remove valid WFH from payroll-compensated totals.

#### Scenario: WFH without attendance in payroll export
- **WHEN** an employee has WFH without qualifying attendance in the payroll cycle
- **THEN** the workbook SHALL exclude that date from `CÔNG THỰC TẾ` while preserving WFH and payroll-compensated totals according to existing payroll policy

#### Scenario: UI and workbook use the same attendance data
- **WHEN** HR views an employee summary and exports payroll for the same completed attendance data and payroll cycle
- **THEN** the UI actual-working-days value SHALL equal that employee's `CÔNG THỰC TẾ` workbook value

### Requirement: HR can audit actual working days by calendar date
The leave-order screen SHALL allow HR to open the selected employee's actual-working-days metric and inspect the payroll cycle as a calendar. The audit SHALL expose every fetched attendance session, whether it was counted, its day value or exclusion reason, and every employee order overlapping the cycle.

#### Scenario: HR selects a counted Saturday
- **WHEN** HR selects a Saturday containing a valid completed attendance session
- **THEN** the detail SHALL show the session times and `0.5` counted day

#### Scenario: HR selects a day containing an excluded session
- **WHEN** HR selects a day containing an open, invalid, reversed, or overnight session
- **THEN** the detail SHALL show that session with a descriptive reason it was not counted

#### Scenario: Employee orders overlap the cycle
- **WHEN** the employee has leave, WFH, OT, rejected, or cancelled orders overlapping the payroll cycle
- **THEN** the calendar SHALL mark their covered dates and SHALL provide a list of all such orders with type, status, dates, duration, and time details
