## ADDED Requirements

### Requirement: Offline resend processing is active in authenticated sessions
The system SHALL initialize mobile pending-message resend processing for authenticated users so reconnect and retry listeners are active without requiring a specific chat screen to be open.

#### Scenario: Authenticated session starts resend processing
- **WHEN** the user is authenticated in the mobile app
- **THEN** offline resend processing is initialized and listens to WebSocket connection state and message acknowledgements

#### Scenario: Logout stops resend processing
- **WHEN** the user logs out or becomes unauthenticated
- **THEN** offline resend processing stops and does not continue retrying pending messages for that session

### Requirement: Pending text messages auto-resend after reconnect
The system SHALL automatically retry pending outgoing text messages when WebSocket connectivity is restored.

#### Scenario: Send text while disconnected then reconnect
- **WHEN** a user sends a text message while WebSocket transport is unavailable and the message is stored locally as `pending`
- **THEN** after WebSocket reconnects, the client automatically retries sending that pending message

#### Scenario: ACK resolves pending retry
- **WHEN** a retried pending message receives `message_ack` for the same message ID
- **THEN** the local message status is updated from `pending` to `sent`

### Requirement: Immediate send transport failure remains retryable
The system SHALL keep outgoing messages retryable when the immediate WebSocket send attempt cannot be dispatched.

#### Scenario: sendMessage returns false during transient disconnect
- **WHEN** a text message is optimistically inserted and `sendMessage(...)` returns `false`
- **THEN** the message remains in `pending` state and is retried by reconnect/queue replay behavior instead of being dropped

### Requirement: Media retries remain in pending upload pipeline
The system SHALL not replay media optimistic payloads through the text resend path.

#### Scenario: Pending media exists during reconnect
- **WHEN** pending image, album, voice, or video messages exist with pending upload records
- **THEN** reconnect processing retries them through pending upload handling and does not emit invalid plain `send_message` payloads containing local file paths

### Requirement: Retry attempts are bounded
The system SHALL mark messages as failed after bounded retry attempts when delivery continues to fail.

#### Scenario: Retry cap reached
- **WHEN** a pending retryable message repeatedly fails until the configured max retry count is exceeded
- **THEN** the message status transitions to `failed`

#### Scenario: User retries failed message
- **WHEN** the user triggers retry for a failed message
- **THEN** retry state resets and the message re-enters `pending` delivery flow
