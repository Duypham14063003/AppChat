## ADDED Requirements

### Requirement: Message status lifecycle tracking
The system SHALL track message status through the lifecycle: pending → sent → delivered → read. Status transitions SHALL be communicated via WebSocket events.

#### Scenario: Message acknowledged as sent
- **WHEN** server successfully inserts message into PostgreSQL
- **THEN** server sends `{ event: "message_ack", data: { id, status: "sent", created_at } }` to the sender's WebSocket connection

#### Scenario: Message marked as delivered
- **WHEN** recipient's device receives the message via WebSocket (or on reconnect sync)
- **THEN** recipient's client sends `{ event: "mark_delivered", data: { message_id, conv_id } }` and server notifies sender with `{ event: "message_status", data: { id, status: "delivered", user_id } }`

### Requirement: Read receipts via mark_read event
The system SHALL accept `mark_read` WebSocket events from clients. When a user reads messages in a conversation, the client sends `{ event: "mark_read", data: { conv_id, message_id } }`. The server SHALL update `conversation_members.last_read_message_id` and `last_read_at`, then notify the sender(s).

#### Scenario: User reads messages
- **WHEN** user opens conversation and scrolls to latest message
- **THEN** client sends `mark_read` with the latest message_id, server updates last_read_message_id and last_read_at

#### Scenario: Sender receives read receipt
- **WHEN** recipient reads sender's message
- **THEN** sender receives `{ event: "message_read", data: { conv_id, user_id, message_id } }` via WebSocket

### Requirement: Unread count calculation
The system SHALL calculate unread count per conversation per user as the number of messages in the conversation with `created_at > conversation_members.last_read_at` (excluding messages sent by the user themselves).

#### Scenario: Unread count is accurate
- **WHEN** user has last_read_at = T1 and 5 new messages exist after T1 (3 from others, 2 from self)
- **THEN** unread count for this conversation is 3

#### Scenario: Unread count resets on read
- **WHEN** user sends mark_read for the latest message
- **THEN** unread count for this conversation becomes 0

### Requirement: Message status display indicators
The Flutter client SHALL display message status visually: ⏳ (pending/sending), ✓ (sent), ✓✓ (delivered), ✓✓ blue (read). Status updates SHALL be reflected in real-time as WebSocket events arrive.

#### Scenario: Status icon updates in real-time
- **WHEN** sender's message transitions from sent → delivered → read
- **THEN** the status icon on the message bubble updates accordingly without requiring screen refresh

