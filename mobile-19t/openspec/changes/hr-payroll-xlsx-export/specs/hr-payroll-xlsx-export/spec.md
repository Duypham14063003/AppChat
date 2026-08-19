## ADDED Requirements

### Requirement: HR leave list exposes payroll workbook export
The system SHALL expose a payroll workbook export action from the HR leave list workflow for users who are allowed to approve leave requests.

#### Scenario: Approver sees export action
- **WHEN** a user with HR approver permissions opens the "Xem Don" screen
- **THEN** the system shows an export action for payroll workbook download

#### Scenario: Non-approver does not see export action
- **WHEN** a user without HR approver permissions opens the "Xem Don" screen
- **THEN** the system does not show the payroll workbook export action

### Requirement: Payroll export endpoint returns an XLSX attachment
The system SHALL expose an authenticated HR payroll export endpoint that returns an `.xlsx` file attachment for a selected payroll month.

#### Scenario: Successful workbook download
- **WHEN** an authorized user requests payroll export for month `2026-07`
- **THEN** the system returns HTTP 200 with an `.xlsx` attachment containing the payroll workbook for that month

#### Scenario: Unsupported format is not returned
- **WHEN** an authorized user requests payroll export
- **THEN** the system returns workbook content in `.xlsx` format and not as CSV or JSON attachment output

### Requirement: Payroll month maps to payroll-cycle boundaries
The system SHALL translate the selected payroll month into an inclusive payroll-cycle date range using the configured payroll start day. For a payroll start day of 25, payroll month `YYYY-MM` SHALL map from day 25 of the previous month through day 24 of the selected month.

#### Scenario: Payroll month uses cross-month cycle
- **WHEN** payroll start day is `25` and an authorized user requests payroll month `2026-07`
- **THEN** the system computes export totals for `2026-06-25` through `2026-07-24`, inclusive

#### Scenario: Payroll month uses configured start day consistently
- **WHEN** payroll start day is changed to `20` and an authorized user requests payroll month `2026-07`
- **THEN** the system computes export totals for `2026-06-20` through `2026-07-19`, inclusive

### Requirement: Payroll workbook includes active employees only
The system SHALL generate workbook rows only for employees whose `users.is_active` value is `true` at export time.

#### Scenario: Active employee is included
- **WHEN** an employee has `is_active = true` during workbook generation
- **THEN** the system includes that employee in the payroll workbook

#### Scenario: Inactive employee is excluded
- **WHEN** an employee has `is_active = false` during workbook generation
- **THEN** the system excludes that employee from the payroll workbook

### Requirement: Payroll workbook columns follow the HR salary-processing schema
The system SHALL generate one workbook row per included employee with the following columns in order: `STT`, `HỌ VÀ TÊN`, `NGHỈ PHÉP CÓ LƯƠNG`, `NGHỈ PHÉP KHÔNG LƯƠNG`, `NGHỈ KHÔNG PHÉP`, `CÔNG THỰC TẾ`, `TỔNG NGÀY CÔNG TÍNH LƯƠNG`, `SỐ NGÀY LÀM TẠI NHÀ`, `GIỜ OT (GIỜ)`, `NHẬN VIỆC/NGHỈ VIỆC`, `XÁC NHẬN (Đ/S)`, `NHẬP SAIA/LỆCH (nếu có)`.

#### Scenario: Workbook contains required headers
- **WHEN** an authorized user opens the exported workbook
- **THEN** the worksheet header row contains the required columns in the defined order

#### Scenario: Workbook preserves blank manual columns
- **WHEN** the system generates a payroll workbook row
- **THEN** the `NHẬN VIỆC/NGHỈ VIỆC`, `XÁC NHẬN (Đ/S)`, and `NHẬP SAIA/LỆCH (nếu có)` cells are left blank

### Requirement: Workbook name reflects employment status
The system SHALL render the `HỌ VÀ TÊN` column from the employee name and append ` (thử việc)` when `user.employment_status = probation` and ` (thực tập)` when `user.employment_status = intern`.

#### Scenario: Probation employee name is suffixed
- **WHEN** an included employee has `employment_status = probation`
- **THEN** the workbook shows `HỌ VÀ TÊN` as `<employee name> (thử việc)`

#### Scenario: Official employee name has no probation suffix
- **WHEN** an included employee has `employment_status = official`
- **THEN** the workbook shows `HỌ VÀ TÊN` as the employee name without a probation or intern suffix

### Requirement: Workbook totals use payroll-ready numeric values
The system SHALL populate payroll metric columns as numeric spreadsheet cells. `TỔNG NGÀY CÔNG TÍNH LƯƠNG` SHALL equal `CÔNG THỰC TẾ + NGHỈ PHÉP CÓ LƯƠNG`.

#### Scenario: Payroll-compensated days are derived from worked and paid leave days
- **WHEN** an employee has `20` actual worked days and `1.5` paid leave days in the payroll cycle
- **THEN** the workbook sets `TỔNG NGÀY CÔNG TÍNH LƯƠNG` to numeric value `21.5`

#### Scenario: Decimal metrics remain numeric
- **WHEN** an employee has fractional leave or WFH totals such as `0.5` or `1.5`
- **THEN** the workbook stores those values as numbers and not as date-formatted cells

### Requirement: Workbook row totals derive from approved HR and attendance data
The system SHALL derive payroll totals from server-side attendance and approved HR records for the computed payroll cycle. `NGHỈ PHÉP CÓ LƯƠNG` SHALL come from approved paid leave totals, `NGHỈ PHÉP KHÔNG LƯƠNG` SHALL come from approved unpaid leave totals, `NGHỈ KHÔNG PHÉP` SHALL come from absent-without-leave totals, `CÔNG THỰC TẾ` SHALL come from attended workday totals, `SỐ NGÀY LÀM TẠI NHÀ` SHALL come from approved WFH totals, and `GIỜ OT (GIỜ)` SHALL come from approved OT totals.

#### Scenario: Approved WFH contributes to WFH days
- **WHEN** an employee has approved WFH records totaling `2.0` days in the payroll cycle
- **THEN** the workbook sets `SỐ NGÀY LÀM TẠI NHÀ` to numeric value `2.0`

#### Scenario: Pending leave does not affect payroll workbook totals
- **WHEN** an employee has leave requests in `draft` or `submitted` status during the payroll cycle
- **THEN** the system excludes those requests from the workbook’s paid leave, unpaid leave, WFH, and OT totals

### Requirement: Payroll workbook ordering is deterministic
The system SHALL order workbook rows so official employees appear first, probation employees next, intern employees next, and rows within the same employment-status group remain deterministically ordered.

#### Scenario: Official employees appear before probation employees
- **WHEN** the workbook contains both official and probation employees
- **THEN** all official employee rows appear before all probation employee rows

#### Scenario: Intern employees appear after probation employees
- **WHEN** the workbook contains both probation and intern employees
- **THEN** all probation employee rows appear before all intern employee rows
