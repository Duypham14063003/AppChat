## ADDED Requirements

### Requirement: Login via Odoo SSO
The system SHALL authenticate users by forwarding email and password to Odoo API (`POST /web/session/authenticate` at erp.19t.vn). On success, the system SHALL create or update the user record in PostgreSQL and return JWT tokens. The system SHALL NOT store user passwords.

#### Scenario: Successful login with valid Odoo credentials
- **WHEN** user sends `POST /auth/login` with valid email and password
- **THEN** the system calls Odoo API, creates/updates user in DB, and returns `{ accessToken, refreshToken, user: { id, email, name, department, jobTitle, avatarUrl, roles } }` with HTTP 200

#### Scenario: Login with invalid credentials
- **WHEN** user sends `POST /auth/login` with wrong password
- **THEN** the system returns HTTP 401 with `{ message: "Email hoặc mật khẩu không đúng" }`

#### Scenario: Login when Odoo is unreachable
- **WHEN** user sends `POST /auth/login` and Odoo API does not respond within 10 seconds
- **THEN** the system returns HTTP 503 with `{ message: "Không thể kết nối hệ thống, vui lòng thử lại" }`

#### Scenario: Login with deactivated account
- **WHEN** user sends `POST /auth/login` with valid Odoo credentials but `users.is_active = false`
- **THEN** the system returns HTTP 403 with `{ message: "Tài khoản đã bị vô hiệu hóa" }`

### Requirement: User provisioning from Odoo response
The system SHALL create a new user record on first login using data from Odoo response (uid, name, email). On subsequent logins, the system SHALL update the user's name, department, and job_title from Odoo.

#### Scenario: First-time login creates user
- **WHEN** user logs in for the first time (no matching odoo_uid in DB)
- **THEN** a new user record is created with odoo_uid, email, name from Odoo, default role Employee, and is_active = true

#### Scenario: Returning user gets profile updated
- **WHEN** existing user logs in and their name or department changed in Odoo
- **THEN** the user record is updated with the latest name, department, job_title from Odoo

### Requirement: Login rate limiting
The system SHALL limit login attempts to 5 per 15 minutes per IP address. After exceeding the limit, the system SHALL block login from that IP for 30 minutes.

#### Scenario: Rate limit exceeded
- **WHEN** 6th login attempt from the same IP within 15 minutes
- **THEN** the system returns HTTP 429 with `{ message: "Quá nhiều lần thử, vui lòng đợi 30 phút" }`

#### Scenario: Rate limit resets after window
- **WHEN** 30 minutes have passed since rate limit was triggered
- **THEN** login attempts from that IP are allowed again

### Requirement: Audit logging for login events
The system SHALL log all login attempts (success and failure) as structured JSON including: timestamp, email, IP address, user agent, result (success/failure), and failure reason if applicable.

#### Scenario: Successful login is logged
- **WHEN** user successfully logs in
- **THEN** an audit log entry is written with event type "auth.login.success", user ID, IP, and user agent

#### Scenario: Failed login is logged
- **WHEN** login fails due to invalid credentials
- **THEN** an audit log entry is written with event type "auth.login.failure", attempted email, IP, and reason

