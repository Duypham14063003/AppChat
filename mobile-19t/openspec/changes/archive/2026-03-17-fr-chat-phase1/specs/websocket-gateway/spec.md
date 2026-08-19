## ADDED Requirements

### Requirement: WebSocket Gateway accepts connections on /ws path
The system SHALL expose a WebSocket Gateway on path `/ws` using `@nestjs/platform-ws`. The gateway SHALL accept raw WebSocket connections (not Socket.io).

#### Scenario: Client connects to WebSocket endpoint
- **WHEN** client opens WebSocket connection to `ws://host:3000/ws`
- **THEN** the connection is established and server waits for auth message

### Requirement: WebSocket authentication via first message
The system SHALL require clients to send `{ event: "auth", data: { token: "<jwt_access_token>" } }` as the first message within 5 seconds of connecting. The server SHALL validate the JWT, extract userId, and associate the connection with the user.

#### Scenario: Valid JWT authentication
- **WHEN** client sends auth message with valid JWT within 5 seconds
- **THEN** server responds with `{ event: "auth_success", data: { userId } }` and the connection is authenticated

#### Scenario: Invalid JWT authentication
- **WHEN** client sends auth message with expired or invalid JWT
- **THEN** server responds with `{ event: "auth_error", data: { message: "Invalid token" } }` and closes the connection

#### Scenario: Auth timeout
- **WHEN** client does not send auth message within 5 seconds
- **THEN** server closes the connection with code 4001

### Requirement: Connection management tracks active users
The system SHALL maintain an in-memory map of userId → WebSocket connection(s). A user MAY have multiple active connections (multi-device). When a connection closes, it SHALL be removed from the map.

#### Scenario: User connects from two devices
- **WHEN** user authenticates from both mobile and desktop
- **THEN** both connections are tracked and both receive messages

#### Scenario: Connection cleanup on disconnect
- **WHEN** a WebSocket connection closes (network drop, client close)
- **THEN** the connection is removed from the active connections map

### Requirement: Heartbeat keeps connections alive
The system SHALL send WebSocket ping frames every 30 seconds. If no pong is received within 10 seconds, the connection SHALL be considered dead and closed.

#### Scenario: Healthy connection responds to ping
- **WHEN** server sends ping frame
- **THEN** client responds with pong and connection stays alive

#### Scenario: Dead connection is cleaned up
- **WHEN** server sends ping and no pong received within 10 seconds
- **THEN** server closes the connection and removes it from active map

### Requirement: Message rate limiting at gateway level
The system SHALL enforce rate limits at the WebSocket gateway: 30 messages per minute per user, 10 file upload messages per minute per user. Rate tracking SHALL use Redis sliding window counters.

#### Scenario: User exceeds message rate limit
- **WHEN** user sends 31st message within 1 minute
- **THEN** server responds with `{ event: "error", data: { code: "RATE_LIMITED", message: "Too many messages" } }` and the message is not processed

#### Scenario: Rate limit resets after window
- **WHEN** 1 minute passes since rate limit was hit
- **THEN** user can send messages again

### Requirement: JSON message envelope format
All WebSocket messages SHALL use the format `{ event: string, data: object, id?: string }`. The `id` field is optional and used for request-response correlation (ACK).

#### Scenario: Client sends properly formatted message
- **WHEN** client sends `{ event: "send_message", data: { ... }, id: "msg-uuid" }`
- **THEN** server processes the message and responds with ACK using the same `id`

