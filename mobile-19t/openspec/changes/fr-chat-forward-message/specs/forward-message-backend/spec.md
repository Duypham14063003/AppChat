## ADDED Requirements

### Requirement: Forward messages via WebSocket event
The system SHALL accept `forward_message` WebSocket events with payload `{ message_ids: string[], conv_ids: string[], hide_sender: boolean }`. The server SHALL validate the sender is a member of all target conversations, look up original messages, and create new messages in each target conversation with the original content, type, and metadata preserved.

#### Scenario: Successful forward of single message to single conversation
- **WHEN** authenticated user sends `{ event: "forward_message", data: { message_ids: ["msg-1"], conv_ids: ["conv-a"], hide_sender: false } }`
- **THEN** server creates a new message in conv-a with the same type, content, and metadata as msg-1, with `forwarded_from_id` set to msg-1's ID and `forwarded_from_sender` set to msg-1's sender name, and responds with `{ event: "forward_ack", data: { forwarded_count: 1 } }`

#### Scenario: Forward multiple messages to multiple conversations
- **WHEN** user forwards 3 messages to 2 conversations
- **THEN** server creates 6 new messages (3 per conversation), each with correct `forwarded_from_id` and `forwarded_from_sender`, and responds with `{ event: "forward_ack", data: { forwarded_count: 6 } }`

#### Scenario: Forward with hide_sender enabled
- **WHEN** user forwards with `hide_sender: true`
- **THEN** all created messages have `forwarded_from_sender` set to `null` and `forwarded_from_id` set to the original message ID

### Requirement: Validate membership in target conversations
The server SHALL verify the forwarding user is a member of every target conversation before creating any forwarded messages. If any target conversation fails validation, the entire forward operation SHALL be rejected.

#### Scenario: User is not a member of target conversation
- **WHEN** user forwards to a conversation they are not a member of
- **THEN** server responds with `{ event: "error", data: { code: "FORBIDDEN", message: "Not a member of target conversation" } }` and no messages are created

### Requirement: Block forwarding of deleted messages
The server SHALL reject forwarding of messages where `deleted_at IS NOT NULL`. If any message in the batch is deleted, only that message SHALL be skipped (other valid messages proceed).

#### Scenario: Forward a deleted message
- **WHEN** user forwards a message that has been soft-deleted
- **THEN** that message is skipped, other valid messages in the batch are forwarded, and the ack includes the actual forwarded count

### Requirement: Preserve message order when forwarding multiple messages
The server SHALL sort forwarded messages by their original `created_at` ascending and insert them with incrementing timestamps (+1ms each) to maintain chronological order in the target conversation.

#### Scenario: Forward 3 messages in mixed order
- **WHEN** user forwards messages with original timestamps [14:03, 14:01, 14:02]
- **THEN** they appear in the target conversation in order [14:01, 14:02, 14:03] with new sequential timestamps

### Requirement: Fan-out forwarded messages via Redis Pub/Sub
Each forwarded message SHALL be published to Redis Pub/Sub on the target conversation's channel, triggering real-time delivery to all online members. Offline members SHALL receive push notifications via BullMQ.

#### Scenario: Online member receives forwarded message
- **WHEN** a message is forwarded to a conversation where member B is online
- **THEN** member B receives a `new_message` WebSocket event with the forwarded message data including `forwarded_from_id` and `forwarded_from_sender`

### Requirement: Validate membership in source conversation
The server SHALL verify the forwarding user is a member of the conversation containing the original messages.

#### Scenario: User forwards from a conversation they left
- **WHEN** user tries to forward messages from a conversation they are no longer a member of
- **THEN** server responds with error code "FORBIDDEN"

