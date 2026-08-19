## ADDED Requirements

### Requirement: Issue JWT access and refresh tokens on login
The system SHALL issue a JWT access token (TTL 15 minutes) and a refresh token (TTL 30 days) upon successful login. The access token payload SHALL contain: userId, email, roles. The refresh token SHALL be a cryptographically random string.

#### Scenario: Tokens issued on login
- **WHEN** user successfully authenticates via Odoo SSO
- **THEN** the system returns an access token (JWT, 15 min TTL) and a refresh token (opaque string, 30 day TTL)

### Requirement: Refresh access token using refresh token
The system SHALL accept `POST /auth/refresh` with a valid refresh token and return a new access token and a new refresh token. The old refresh token SHALL be invalidated (rotation).

#### Scenario: Successful token refresh
- **WHEN** client sends `POST /auth/refresh` with a valid, non-expired refresh token
- **THEN** the system returns a new access token and a new refresh token, and the old refresh token is invalidated

#### Scenario: Refresh with expired token
- **WHEN** client sends `POST /auth/refresh` with an expired refresh token (> 30 days)
- **THEN** the system returns HTTP 401 with `{ message: "Session expired, please login again" }`

### Requirement: Token rotation on every refresh
The system SHALL issue a new refresh token on every refresh request and invalidate the previous one. The refresh token hash in `user_sessions` SHALL be updated to the new token's hash.

#### Scenario: Old token invalidated after rotation
- **WHEN** refresh token A is used to refresh and token B is issued
- **THEN** token A is no longer valid for any future refresh requests

### Requirement: Token theft detection via reuse
The system SHALL detect refresh token reuse. When an already-invalidated refresh token is used, the system SHALL immediately invalidate ALL sessions for that user (logout all devices).

#### Scenario: Reused token triggers full logout
- **WHEN** an invalidated refresh token A is used after token B was already issued
- **THEN** ALL sessions for that user are deleted, and the request returns HTTP 401 with `{ message: "Security alert: all sessions terminated" }`

### Requirement: Refresh token stored as bcrypt hash
The system SHALL store refresh tokens as bcrypt hashes in the `user_sessions` table. The plaintext refresh token SHALL only exist in the HTTP response to the client.

#### Scenario: Database does not contain plaintext tokens
- **WHEN** inspecting the user_sessions table
- **THEN** the refresh_token_hash column contains bcrypt hashes, not plaintext tokens

