## ADDED Requirements

### Requirement: Sender can edit their own text message
The system SHALL allow a user to edit the content of a previously sent text message only when that user is the original sender and the message has not been recalled.

#### Scenario: Sender edits a text message
- **WHEN** the original sender submits an edit request for one of their existing text messages
- **THEN** the backend updates the stored message content and records an `edited_at` timestamp

#### Scenario: Non-sender attempts to edit a message
- **WHEN** a user submits an edit request for a message sent by another user
- **THEN** the backend rejects the request with a permission error

#### Scenario: Unsupported message type is edited
- **WHEN** the sender submits an edit request for a non-text message
- **THEN** the backend rejects the request as invalid for that message type

### Requirement: Sender can recall their own message using soft-delete state
The system SHALL allow a user to recall one of their own previously sent messages by marking it with recall state instead of hard-deleting the row.

#### Scenario: Sender recalls a message
- **WHEN** the original sender submits a recall request for one of their messages
- **THEN** the backend marks that message with recall state and a `deleted_at` timestamp

#### Scenario: Non-sender attempts to recall a message
- **WHEN** a user submits a recall request for a message sent by another user
- **THEN** the backend rejects the request with a permission error

#### Scenario: Recalled message is recalled again
- **WHEN** the sender submits a recall request for a message that is already recalled
- **THEN** the backend returns a stable failure response instead of creating duplicate state changes

### Requirement: Edited and recalled messages use a canonical serialized message shape
The system SHALL return edited and recalled messages in a consistent message representation across history queries, sync responses, and realtime mutation events.

#### Scenario: History includes a recalled message
- **WHEN** a conversation history request reaches a recalled message
- **THEN** the backend returns that message as a recalled entry instead of omitting it from the result set

#### Scenario: History includes an edited message
- **WHEN** a conversation history request reaches an edited message
- **THEN** the backend returns the latest content together with its `edited_at` metadata

#### Scenario: Recalled message hides original content
- **WHEN** a recalled message is serialized to another client
- **THEN** the backend does not expose the original message content as if it were still an active message

### Requirement: Message edit and recall changes propagate in realtime
The system SHALL publish explicit realtime updates for successful edit and recall mutations so connected clients can update the affected message without reloading the conversation.

#### Scenario: Edit mutation succeeds
- **WHEN** a message edit request succeeds
- **THEN** the backend emits a realtime message-updated event containing the canonical edited message payload

#### Scenario: Recall mutation succeeds
- **WHEN** a message recall request succeeds
- **THEN** the backend emits a realtime message-recalled event containing the canonical recalled message payload
