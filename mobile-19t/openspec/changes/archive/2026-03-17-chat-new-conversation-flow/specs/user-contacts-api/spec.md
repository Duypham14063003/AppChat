## ADDED Requirements

### Requirement: List active users for contact selection
The system SHALL provide `GET /users` endpoint that returns a paginated list of active users. The response SHALL include id, name, email, department, job_title, and avatar_url for each user. The current authenticated user SHALL be excluded from the results.

#### Scenario: List all active users
- **WHEN** authenticated user sends `GET /users`
- **THEN** server returns up to 50 active users (excluding the requester) sorted by name, with `{ users, total, nextCursor, hasMore }`

#### Scenario: Search users by name
- **WHEN** authenticated user sends `GET /users?search=Ngoc`
- **THEN** server returns active users whose name or email contains "Ngoc" (case-insensitive), excluding the requester

#### Scenario: Paginate user list
- **WHEN** authenticated user sends `GET /users?cursor=<last_user_id>&limit=50`
- **THEN** server returns the next page of up to 50 users after the cursor

#### Scenario: Unauthenticated request
- **WHEN** unauthenticated request sends `GET /users`
- **THEN** server returns HTTP 401

### Requirement: User list response format
The system SHALL return each user with the following fields: `id` (uuid), `name` (string), `email` (string), `department` (string|null), `jobTitle` (string|null), `avatarUrl` (string|null).

#### Scenario: User response includes all required fields
- **WHEN** user list is returned
- **THEN** each user object contains id, name, email, department, jobTitle, avatarUrl with no sensitive fields (password, tokens, sessions)

### Requirement: Deactivated users excluded
The system SHALL NOT include users with `is_active = false` in the contact list results.

#### Scenario: Deactivated user not shown
- **WHEN** user B has `is_active = false`
- **THEN** user B does not appear in `GET /users` results

