## MODIFIED Requirements

### Requirement: Permission matrix is enforced
The system SHALL enforce the permission matrix defined in AUTH-FR-007: Admin has full access, Manager can approve leaves, view team data, and download HR payroll export workbooks for active employees in supported payroll cycles, and Employee can only access personal data and chat.

#### Scenario: Manager approves team leave request
- **WHEN** a Manager sends a request to approve a leave request from their team
- **THEN** the request is allowed

#### Scenario: Employee cannot approve leave requests
- **WHEN** an Employee sends a request to approve a leave request
- **THEN** the system returns HTTP 403

#### Scenario: Manager downloads payroll workbook
- **WHEN** a Manager requests the HR payroll export workbook for a supported payroll month
- **THEN** the system allows the export request

#### Scenario: Employee cannot download payroll workbook
- **WHEN** an Employee requests the HR payroll export workbook
- **THEN** the system returns HTTP 403
