## ADDED Requirements

### Requirement: Create leave request via REST API
The system SHALL expose `POST /hr/leaves` accepting `{ type, start_date, end_date, reason }`. Type SHALL be one of: "annual", "sick", "personal". The endpoint SHALL create a leave request with status "draft" and return 201.

#### Scenario: Create draft leave request
- **WHEN** an employee sends POST /hr/leaves with type "annual", start_date "2026-04-01", end_date "2026-04-03", reason "Nghỉ phép gia đình"
- **THEN** the system creates a leave request with status "draft" and returns 201

#### Scenario: Invalid leave type
- **WHEN** an employee sends a leave request with type "vacation"
- **THEN** the system returns 400 Bad Request

#### Scenario: End date before start date
- **WHEN** an employee sends a leave request with end_date before start_date
- **THEN** the system returns 400 Bad Request

### Requirement: Submit leave request
The system SHALL expose `PATCH /hr/leaves/:id/submit`. The endpoint SHALL change status from "draft" to "submitted" and send a push notification to all admin users with message "{employee_name} xin nghỉ {type} từ {start_date} đến {end_date}".

#### Scenario: Submit draft request
- **WHEN** an employee submits a draft leave request
- **THEN** status changes to "submitted" and admin users receive a push notification

#### Scenario: Submit non-draft request
- **WHEN** an employee attempts to submit a request that is already "submitted" or "approved"
- **THEN** the system returns 400 Bad Request

### Requirement: Approve leave request
The system SHALL expose `PATCH /hr/leaves/:id/approve` (admin only). The endpoint SHALL change status to "approved", set approved_by and approved_at, send push notification to the employee "{approver_name} đã duyệt đơn nghỉ của bạn", and mark for Odoo sync.

#### Scenario: Admin approves leave
- **WHEN** an admin approves a submitted leave request
- **THEN** status changes to "approved", employee receives notification, record marked for Odoo sync

#### Scenario: Non-admin attempts to approve
- **WHEN** a regular employee attempts to approve a leave request
- **THEN** the system returns 403 Forbidden

### Requirement: Reject leave request
The system SHALL expose `PATCH /hr/leaves/:id/reject` (admin only) accepting `{ reject_reason }`. The endpoint SHALL change status to "rejected", set reject_reason, send push notification to the employee "{approver_name} đã từ chối đơn nghỉ: {reject_reason}".

#### Scenario: Admin rejects leave with reason
- **WHEN** an admin rejects a leave request with reason "Thiếu nhân sự trong thời gian này"
- **THEN** status changes to "rejected", employee receives notification with the reason

### Requirement: List leave requests via REST API
The system SHALL expose `GET /hr/leaves` with optional query params `status` (filter) and `user_id` (admin only). Employees see only their own requests. Admins see all or filter by user. Returns paginated list ordered by created_at DESC.

#### Scenario: Employee views own leaves
- **WHEN** an employee sends GET /hr/leaves
- **THEN** the system returns only their leave requests

#### Scenario: Admin views pending leaves
- **WHEN** an admin sends GET /hr/leaves?status=submitted
- **THEN** the system returns all submitted leave requests awaiting approval

### Requirement: Leave request database table
The system SHALL create a `leave_requests` table with columns: `id` (uuid PK), `user_id` (uuid FK→users), `type` (varchar(30) NOT NULL), `start_date` (date NOT NULL), `end_date` (date NOT NULL), `reason` (text), `status` (varchar(20) DEFAULT 'draft'), `approved_by` (uuid FK→users nullable), `approved_at` (timestamptz nullable), `reject_reason` (text nullable), `odoo_synced` (boolean DEFAULT false), `created_at` (timestamptz DEFAULT now()). Index on `(user_id, created_at DESC)`.

#### Scenario: Table supports leave request lifecycle
- **WHEN** a leave request is created, submitted, and approved
- **THEN** the status transitions are persisted correctly with approval metadata

### Requirement: Flutter leave screens
The system SHALL provide: LeaveListScreen (list of leave requests with status badges, filter tabs: All/Pending/Approved/Rejected), LeaveCreateScreen (form with type picker, date range picker, reason text field, save draft / submit buttons), LeaveDetailScreen (full details, approve/reject buttons for admin).

#### Scenario: Employee creates and submits leave
- **WHEN** the employee fills the leave form and taps "Gửi duyệt"
- **THEN** the leave request is created with status "submitted" and appears in the list with "Chờ duyệt" badge

#### Scenario: Admin sees pending leaves
- **WHEN** an admin opens the leave list with "Chờ duyệt" filter
- **THEN** all submitted leave requests are shown with approve/reject actions

