## MODIFIED Requirements

### Requirement: Send text message via WebSocket
The system SHALL accept `send_message` WebSocket events with payload `{ id, conv_id, type, content, reply_to_id?, metadata?, forwarded_from_id?, forwarded_from_sender? }`. The server SHALL validate the sender is a member of the conversation, insert the message into PostgreSQL including `forwarded_from_id` and `forwarded_from_sender` columns, publish to Redis Pub/Sub, and ACK back to the sender.

#### Scenario: Successful text message send
- **WHEN** authenticated user sends `{ event: "send_message", data: { id: "<uuid>", conv_id: "<uuid>", type: "text", content: "Hello" } }`
- **THEN** server inserts message into DB with `forwarded_from_id` and `forwarded_from_sender` as NULL, publishes to Redis `chat:conv:{conv_id}`, and responds with `{ event: "message_ack", data: { id: "<uuid>", status: "sent", created_at: "<timestamp>" } }`

#### Scenario: Send message with forward fields
- **WHEN** authenticated user sends a message with `forwarded_from_id` and `forwarded_from_sender` in the payload
- **THEN** server inserts message with those forward fields populated

