## ADDED Requirements

### Requirement: Send text message via WebSocket
The system SHALL accept `send_message` WebSocket events with payload `{ id, conv_id, type, content, reply_to_id?, metadata? }`. The server SHALL validate the sender is a member of the conversation, insert the message into PostgreSQL, publish to Redis Pub/Sub, and ACK back to the sender.

#### Scenario: Successful text message send
- **WHEN** authenticated user sends `{ event: "send_message", data: { id: "<uuid>", conv_id: "<uuid>", type: "text", content: "Hello" } }`
- **THEN** server inserts message into DB, publishes to Redis `chat:conv:{conv_id}`, and responds with `{ event: "message_ack", data: { id: "<uuid>", status: "sent", created_at: "<timestamp>" } }`

#### Scenario: Send to conversation user is not a member of
- **WHEN** user sends message to a conversation they are not a member of
- **THEN** server responds with `{ event: "error", data: { code: "FORBIDDEN", message: "Not a member of this conversation" } }`

#### Scenario: Duplicate message (idempotency)
- **WHEN** user sends a message with an ID that already exists in the database
- **THEN** server responds with ACK (idempotent — no duplicate insert) using `INSERT ... ON CONFLICT DO NOTHING`

### Requirement: Receive messages in real-time
The system SHALL push new messages to all online members of a conversation via WebSocket event `new_message` with the full message object. The sender's originating connection SHALL NOT receive the `new_message` event (they already have the message via optimistic UI + ACK).

#### Scenario: Online recipient receives message
- **WHEN** user A sends a message in conversation with user B (online)
- **THEN** user B receives `{ event: "new_message", data: { message } }` via WebSocket within 500ms

#### Scenario: Sender does not receive echo
- **WHEN** user A sends a message
- **THEN** user A's connection receives `message_ack` but NOT `new_message` for their own message

### Requirement: Group message fan-out
When a message is sent in a GROUP conversation, the system SHALL deliver it to all online members via Redis Pub/Sub fan-out. Each member's WebSocket connection SHALL receive the `new_message` event.

#### Scenario: Group message delivered to all online members
- **WHEN** user A sends message in group with 10 members, 7 online
- **THEN** all 7 online members (except A) receive `new_message` within 1 second

### Requirement: Offline delivery via FCM push notification
When a message recipient has no active WebSocket connection, the system SHALL enqueue a BullMQ job to send a Firebase FCM push notification. The notification SHALL include sender name, message preview (truncated to 100 chars), and conversation ID for deep linking.

#### Scenario: Offline user receives push notification
- **WHEN** user A sends message to user B who is offline
- **THEN** a BullMQ job is created to send FCM push to B's registered device tokens

#### Scenario: Firebase not configured
- **WHEN** FIREBASE_PROJECT_ID environment variable is empty
- **THEN** the system logs a warning and skips push notification delivery (no error thrown)

### Requirement: Conversation last_message_at updated on new message
When a new message is sent, the system SHALL update `conversations.last_message_at` to the message's `created_at` timestamp. This enables sorting the conversation list by most recent activity.

#### Scenario: Conversation sort order updates
- **WHEN** a new message is sent in conversation X
- **THEN** `conversations.last_message_at` for X is updated to the message's created_at

