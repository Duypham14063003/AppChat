## ADDED Requirements

### Requirement: Three roles exist in the system
The system SHALL support exactly three roles: Admin, Manager, Employee. Every user MUST have at least one role. The default role for new users SHALL be Employee.

#### Scenario: New user gets Employee role
- **WHEN** a user logs in for the first time
- **THEN** the user is assigned the Employee role

### Requirement: JWT guard protects all endpoints except public ones
The system SHALL apply a JWT authentication guard globally. Only explicitly marked public endpoints (`/auth/login`, `/auth/refresh`, `/health`) SHALL be accessible without a valid access token.

#### Scenario: Request without token is rejected
- **WHEN** a request is sent to a protected endpoint without an Authorization header
- **THEN** the system returns HTTP 401

#### Scenario: Request with valid token is accepted
- **WHEN** a request is sent with a valid `Authorization: Bearer <accessToken>` header
- **THEN** the request proceeds to the controller with the user context attached

#### Scenario: Request with expired token is rejected
- **WHEN** a request is sent with an expired access token
- **THEN** the system returns HTTP 401 with `{ message: "Token expired" }`

### Requirement: Roles guard restricts access by role
The system SHALL provide a `@Roles()` decorator and `RolesGuard` that restricts endpoint access to users with specified roles. The guard SHALL read roles from the JWT payload.

#### Scenario: Employee cannot access admin endpoint
- **WHEN** a user with only Employee role accesses an endpoint decorated with `@Roles('admin')`
- **THEN** the system returns HTTP 403 with `{ message: "Insufficient permissions" }`

#### Scenario: Admin can access admin endpoint
- **WHEN** a user with Admin role accesses an endpoint decorated with `@Roles('admin')`
- **THEN** the request proceeds normally

### Requirement: Permission matrix is enforced
The system SHALL enforce the permission matrix defined in AUTH-FR-007: Admin has full access, Manager can approve leaves and view team data, Employee can only access personal data and chat.

#### Scenario: Manager approves team leave request
- **WHEN** a Manager sends a request to approve a leave request from their team
- **THEN** the request is allowed

#### Scenario: Employee cannot approve leave requests
- **WHEN** an Employee sends a request to approve a leave request
- **THEN** the system returns HTTP 403

