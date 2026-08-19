## ADDED Requirements

### Requirement: Authorized HR can open employee attendance
The employee detail screen SHALL expose a `Chấm công` tab for administrators, managers, and the configured HR-manager role, and SHALL load attendance only for the employee identified by the detail route. Users without employee-attendance permission SHALL NOT be able to retrieve another employee's attendance through the supporting API.

#### Scenario: HR opens an employee attendance tab
- **WHEN** an administrator, manager, or configured HR manager opens the `Chấm công` tab for an employee
- **THEN** the system SHALL request and display that employee's attendance for the selected payroll month

#### Scenario: Unauthorized user requests another employee
- **WHEN** a user without employee-attendance permission requests another employee's attendance summary
- **THEN** the system SHALL reject the request without returning attendance data

### Requirement: Employee attendance uses the payroll summary source
The employee attendance tab SHALL use the backend-owned payroll cycle and completed-attendance result exposed by the employee payroll summary. It SHALL NOT independently recalculate actual working days from raw sessions or use the conflicting check-in-date calculation.

#### Scenario: Attendance tab and payroll export use the same cycle
- **WHEN** HR views an employee for a payroll month and exports payroll for the same month
- **THEN** the employee tab SHALL use the same effective cycle boundaries and actual-working-days rule as the payroll summary and export

#### Scenario: Saturday completed attendance is shown
- **WHEN** the summary counts a completed Saturday attendance session as `0.5` day
- **THEN** the employee attendance tab SHALL display `0.5` for that date without recalculating it as a full day

### Requirement: HR can navigate payroll months
The attendance tab SHALL default to the current payroll month and SHALL allow HR to move to another valid `YYYY-MM` payroll month. Attendance state SHALL be keyed by employee user ID and payroll month so changing either value loads the corresponding summary.

#### Scenario: HR changes the payroll month
- **WHEN** HR navigates from one payroll month to another
- **THEN** the system SHALL load the same employee's summary for the newly selected month and update the displayed cycle

#### Scenario: HR opens a different employee
- **WHEN** HR navigates from one employee detail screen to another while the same month is selected
- **THEN** the system SHALL load data for the new employee ID and SHALL NOT display the previous employee's cached summary as current data

### Requirement: Attendance summary distinguishes availability states
The attendance tab SHALL display the actual-working-days value when attendance status is `available`, including an explicit zero. It SHALL display a non-numeric explanation for `unmapped` and `unavailable` states and SHALL provide loading, empty, error, retry, and refresh states.

#### Scenario: Employee has zero qualifying days
- **WHEN** the payroll summary reports `available` attendance data and `0` actual working days
- **THEN** the tab SHALL display `0` days rather than an unavailable or empty state

#### Scenario: Employee lacks an Odoo mapping
- **WHEN** the payroll summary reports `unmapped`
- **THEN** the tab SHALL explain that the employee is not mapped to the attendance source and SHALL NOT display zero days

#### Scenario: Attendance source fails
- **WHEN** the payroll summary reports `unavailable`
- **THEN** the tab SHALL explain that attendance data could not be loaded and SHALL offer a retry without displaying zero days

### Requirement: HR can audit attendance by calendar date
For an available summary, the attendance tab SHALL provide a responsive payroll-cycle calendar and day detail that expose every returned attendance session, whether it counted, its day value or exclusion reason, and overlapping leave orders. The existing working-day detail presentation MAY be reused but SHALL function as embedded employee-detail content on supported screen sizes.

#### Scenario: HR selects a date with attendance
- **WHEN** HR selects a date containing one or more returned attendance sessions
- **THEN** the tab SHALL show each session's check-in, check-out, worked hours, counted state, and exclusion reason when excluded

#### Scenario: HR selects a date with an order
- **WHEN** HR selects a date overlapped by a returned leave, WFH, or OT order
- **THEN** the tab SHALL mark the date and show the related order details separately from the attendance calculation

#### Scenario: Employee is inactive
- **WHEN** HR opens an inactive employee who has historical attendance data
- **THEN** the tab SHALL allow payroll-month navigation and display the historical summary under the same rules as an active employee

