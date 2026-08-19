## ADDED Requirements

### Requirement: Offline message queue in Drift
The Flutter client SHALL queue messages locally in Drift when the device is offline or WebSocket is disconnected. Queued messages SHALL have status `pending` and be stored with all message fields (id, conv_id, content, type, created_at).

#### Scenario: Message queued when offline
- **WHEN** user sends a message while offline
- **THEN** message is saved to Drift with status=pending, displayed in chat with ⏳ indicator

#### Scenario: Queued messages sent on reconnect
- **WHEN** WebSocket connection is re-established
- **THEN** all pending messages are sent in chronological order (oldest first)

### Requirement: Retry logic with exponential backoff
The system SHALL retry sending failed messages up to 5 times with exponential backoff (1s, 2s, 4s, 8s, 16s). After 5 failed attempts, the message SHALL be marked as `failed` with a visible "Gửi thất bại" label and a manual Retry button.

#### Scenario: Transient failure with retry
- **WHEN** message send fails due to network error
- **THEN** system retries with exponential backoff up to 5 times

#### Scenario: Permanent failure after max retries
- **WHEN** message fails 5 consecutive times
- **THEN** message status changes to `failed`, bubble shows "Gửi thất bại" with Retry button

#### Scenario: Manual retry succeeds
- **WHEN** user taps Retry on a failed message
- **THEN** message is re-sent via WebSocket, retry counter resets

### Requirement: Reconnect missed messages sync
When the WebSocket connection is re-established after a disconnection, the client SHALL send `{ event: "sync", data: { last_synced_at: "<ISO-timestamp>" } }`. The server SHALL return all messages newer than `last_synced_at` for all conversations the user is a member of.

#### Scenario: Sync after brief disconnection
- **WHEN** client reconnects after 5 minutes offline and sends sync with last_synced_at
- **THEN** server responds with `{ event: "sync_response", data: { messages: [...] } }` containing all missed messages

#### Scenario: Sync merges with local cache
- **WHEN** sync_response contains messages
- **THEN** client inserts them into Drift local DB, deduplicating by message ID, and updates UI

#### Scenario: Large sync response is paginated
- **WHEN** more than 100 messages were missed
- **THEN** server returns messages in batches of 100 with a continuation token

### Requirement: WebSocket auto-reconnect with exponential backoff
The Flutter WebSocket manager SHALL automatically reconnect when the connection drops. Reconnection SHALL use exponential backoff: 1s, 2s, 4s, 8s, 16s, max 30s. On successful reconnect, the client SHALL re-authenticate and trigger sync.

#### Scenario: Auto-reconnect on network drop
- **WHEN** WebSocket connection drops unexpectedly
- **THEN** client attempts reconnection with exponential backoff

#### Scenario: Reconnect triggers auth + sync
- **WHEN** WebSocket reconnects successfully
- **THEN** client sends auth message, then sync message with last_synced_at

### Requirement: Offline indicator in UI
The Flutter app SHALL display a visible banner "Không có kết nối" when the WebSocket is disconnected. The banner SHALL disappear when connection is restored.

#### Scenario: Offline banner shown
- **WHEN** WebSocket connection is lost
- **THEN** a banner appears at the top of the screen with "Không có kết nối"

#### Scenario: Offline banner hidden on reconnect
- **WHEN** WebSocket connection is restored
- **THEN** the offline banner disappears

