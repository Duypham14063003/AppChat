## ADDED Requirements

### Requirement: Backend updates last_seen_at on WebSocket authentication
The `ChatGateway.handleAuth()` method SHALL update the authenticated user's `last_seen_at` field to the current timestamp when a WebSocket connection is successfully authenticated. This SHALL be done via a direct query or repository update on the `User` entity.

#### Scenario: User connects via WebSocket
- **WHEN** a user successfully authenticates a WebSocket connection
- **THEN** the user's `last_seen_at` in the `users` table is updated to `now()`

### Requirement: Backend updates last_seen_at on last WebSocket disconnect
The `ChatGateway.handleDisconnect()` method SHALL update the user's `last_seen_at` field to the current timestamp when their last WebSocket connection closes (i.e., `ConnectionManager.isOnline(userId)` returns false after removal). If the user still has other active connections, `last_seen_at` SHALL NOT be updated.

#### Scenario: User's last connection closes
- **WHEN** a user's WebSocket disconnects AND they have no other active connections
- **THEN** the user's `last_seen_at` is updated to `now()`

#### Scenario: User has multiple connections and one closes
- **WHEN** a user's WebSocket disconnects BUT they still have other active connections
- **THEN** the user's `last_seen_at` is NOT updated (they are still online)

### Requirement: Flutter displays online status in ChatScreen AppBar
The ChatScreen AppBar subtitle SHALL display the other member's online status based on `last_seen_at`. If `last_seen_at` is within the last 2 minutes, display "Đang hoạt động" (online) with a green indicator. Otherwise, display "Hoạt động X phút/giờ/ngày trước" with the relative time.

#### Scenario: User is online (last_seen_at within 2 minutes)
- **WHEN** the other member's `last_seen_at` is less than 2 minutes ago
- **THEN** the AppBar subtitle shows "Đang hoạt động" with a green dot indicator

#### Scenario: User was recently active
- **WHEN** the other member's `last_seen_at` is 15 minutes ago
- **THEN** the AppBar subtitle shows "Hoạt động 15 phút trước"

#### Scenario: User was active hours ago
- **WHEN** the other member's `last_seen_at` is 3 hours ago
- **THEN** the AppBar subtitle shows "Hoạt động 3 giờ trước"

#### Scenario: User has no last_seen_at
- **WHEN** the other member's `last_seen_at` is null
- **THEN** the AppBar subtitle shows nothing or "Offline"

