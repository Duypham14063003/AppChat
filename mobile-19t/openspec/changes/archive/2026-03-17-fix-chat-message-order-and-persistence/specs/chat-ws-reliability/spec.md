## ADDED Requirements

### Requirement: Chat message display order
The chat screen SHALL display messages with the newest message at the bottom of the viewport and oldest messages at the top, following the Telegram-style layout defined in SRS design decision D6.

When using `ListView.builder` with `reverse: true` and data sorted by `created_at DESC`, the item builder SHALL map `index` directly to `messages[index]` without additional index reversal.

#### Scenario: Newest message appears at bottom
- **WHEN** a conversation has messages with timestamps 00:17, 00:18, 00:19, 00:20
- **THEN** the message at 00:20 SHALL appear at the bottom of the visible area and 00:17 at the top

#### Scenario: New incoming message appends at bottom
- **WHEN** the user is viewing a conversation and a new message arrives
- **THEN** the new message SHALL appear below the previous newest message

### Requirement: WebSocket send feedback
The `WebSocketManager._send()` method SHALL return a `bool` indicating whether the message was dispatched to the WebSocket sink. It SHALL return `false` when `_channel` is null or the sink write fails, and `true` when the message was successfully written to the sink.

#### Scenario: Send when connected
- **WHEN** the WebSocket channel is active and `_send()` is called
- **THEN** the method SHALL write the envelope to the sink and return `true`

#### Scenario: Send when disconnected
- **WHEN** the WebSocket channel is null and `_send()` is called
- **THEN** the method SHALL return `false` without throwing an exception

### Requirement: Periodic pending message retry
The `OfflineQueueService` SHALL run a periodic timer (every 10 seconds) that flushes pending messages when the WebSocket is in `connected` state. This is in addition to the existing reconnect-triggered flush.

Messages that have exceeded the maximum retry count (5) SHALL be marked as `failed`.

#### Scenario: Pending message retried while connected
- **WHEN** a message has `status: pending` and `retryCount < 5` and WebSocket is connected
- **THEN** the periodic timer SHALL attempt to resend the message via WebSocket within 10 seconds

#### Scenario: Message marked failed after max retries
- **WHEN** a message has `status: pending` and `retryCount >= 5`
- **THEN** the system SHALL update the message status to `failed`

#### Scenario: Timer does not run when disconnected
- **WHEN** the WebSocket is in `disconnected` or `connecting` state
- **THEN** the periodic timer SHALL skip the flush cycle

### Requirement: Server error event handling
The chat message provider SHALL listen for `send_error` WebSocket events. When a `send_error` is received for a message, the message SHALL remain in `pending` status for retry by the periodic timer or reconnect flush.

#### Scenario: Rate limit rejection
- **WHEN** the server sends a `send_error` event with reason `rate_limit` for a message
- **THEN** the message SHALL remain `pending` and be retried on the next flush cycle

#### Scenario: Generic server error
- **WHEN** the server sends a `send_error` event for a message
- **THEN** the system SHALL log the error with `[WS]` prefix and increment the retry count

### Requirement: WebSocket diagnostic logging
The `WebSocketManager` SHALL emit `debugPrint` logs prefixed with `[WS]` for the following events:
- State transitions (disconnected → connecting → connected)
- Connection URL on connect attempt
- Auth success and auth error
- Message send success and message drop (channel null)
- Reconnect scheduling with delay value

#### Scenario: State transition logged
- **WHEN** the WebSocket state changes from `disconnected` to `connecting`
- **THEN** a debug log `[WS] State: disconnected → connecting` SHALL be emitted

#### Scenario: Message drop logged
- **WHEN** `_send()` is called with `_channel == null`
- **THEN** a debug log `[WS] Message dropped (no channel): <event>` SHALL be emitted

### Requirement: Offline banner covers connecting state
The chat screen offline banner SHALL be visible when the WebSocket state is either `disconnected` or `connecting`, not only `disconnected`.

#### Scenario: Banner shown while connecting
- **WHEN** the WebSocket state is `connecting`
- **THEN** the offline banner SHALL display "Đang kết nối..."

#### Scenario: Banner shown while disconnected
- **WHEN** the WebSocket state is `disconnected`
- **THEN** the offline banner SHALL display "Không có kết nối"

#### Scenario: Banner hidden when connected
- **WHEN** the WebSocket state is `connected`
- **THEN** the offline banner SHALL NOT be visible
