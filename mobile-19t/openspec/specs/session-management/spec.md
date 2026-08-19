## ADDED Requirements

### Requirement: Login creates a device session
The system SHALL create a new session record in `user_sessions` on every successful login, storing: user_id, device_id, device_name, refresh_token_hash, last_ip, expires_at. Multiple sessions per user SHALL be allowed (multi-device).

#### Scenario: Login from two devices creates two sessions
- **WHEN** user logs in from iPhone and then from Windows PC
- **THEN** two separate session records exist in user_sessions, each with its own refresh token

### Requirement: List active sessions
The system SHALL provide `GET /auth/sessions` returning all active sessions for the authenticated user, including: session id, device_name, last_used_at, last_ip, created_at.

#### Scenario: User views their sessions
- **WHEN** user sends `GET /auth/sessions`
- **THEN** the system returns a list of all active sessions with device info and last activity timestamps

### Requirement: Logout current device
The system SHALL provide `POST /auth/logout` that deletes the current device's session (identified by the refresh token) and returns success. The access token remains valid until expiry but the refresh token is revoked.

#### Scenario: Logout deletes current session only
- **WHEN** user sends `POST /auth/logout` from iPhone
- **THEN** the iPhone session is deleted, but the Windows PC session remains active

#### Scenario: Audit log for logout
- **WHEN** user logs out
- **THEN** an audit log entry is written with event type "auth.logout", user ID, device, and IP

### Requirement: Logout all devices
The system SHALL provide `POST /auth/logout-all` that deletes ALL sessions for the authenticated user.

#### Scenario: Logout all removes every session
- **WHEN** user sends `POST /auth/logout-all`
- **THEN** all sessions for that user are deleted, and all devices must re-login

### Requirement: Delete specific session
The system SHALL provide `DELETE /auth/sessions/:id` that deletes a specific session by ID. Users SHALL only be able to delete their own sessions.

#### Scenario: User removes a specific device session
- **WHEN** user sends `DELETE /auth/sessions/abc-123`
- **THEN** the session with that ID is deleted if it belongs to the authenticated user

#### Scenario: User cannot delete another user's session
- **WHEN** user sends `DELETE /auth/sessions/xyz-789` where xyz-789 belongs to another user
- **THEN** the system returns HTTP 404

### Requirement: Account deactivation by Admin
The system SHALL allow Admin users to deactivate an account via `PATCH /users/:id/deactivate`. Deactivation SHALL set `users.is_active = false`, delete all sessions for that user, and block future login attempts.

#### Scenario: Admin deactivates a user
- **WHEN** Admin sends `PATCH /users/abc/deactivate`
- **THEN** the user's is_active is set to false, all their sessions are deleted, and an audit log entry is written

#### Scenario: Deactivated user cannot login
- **WHEN** a deactivated user attempts to login
- **THEN** the system returns HTTP 403 with `{ message: "Tài khoản đã bị vô hiệu hóa" }`

### Requirement: Session expiry cleanup
The system SHALL periodically clean up expired sessions (where expires_at < now) from the user_sessions table.

#### Scenario: Expired sessions are removed
- **WHEN** a scheduled cleanup job runs
- **THEN** all sessions with expires_at in the past are deleted from user_sessions

