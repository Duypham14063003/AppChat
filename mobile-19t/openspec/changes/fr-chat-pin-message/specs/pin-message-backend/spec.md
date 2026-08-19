## ADDED Requirements

### Requirement: Pinned messages database table
The system SHALL store pinned messages in a dedicated `pinned_messages` table with columns: `conv_id` (uuid, PK composite), `message_id` (uuid, PK composite), `pinned_by` (uuid, FK→users), `pinned_at` (timestamptz, DEFAULT now()). The table SHALL have an index on `(conv_id, pinned_at DESC)` for ordered retrieval.

#### Scenario: Table structure supports pinned message storage
- **WHEN** a message is pinned in a conversation
- **THEN** a row is inserted into `pinned_messages` with the conversation ID, message ID, pinner's user ID, and current timestamp

### Requirement: Pin a message via REST API
The system SHALL expose `POST /conversations/:convId/pins` accepting `{ message_id: uuid }`. The endpoint SHALL validate membership, check permission (any member for DIRECT, admin/creator for GROUP), verify the message belongs to the conversation, enforce the 5-pin limit, insert into `pinned_messages`, create a system message "pinned a message", and broadcast a `pin_update` event via Redis PubSub. The endpoint SHALL return 201 with the pinned message data including message content.

#### Scenario: Member pins a message in DIRECT conversation
- **WHEN** a member sends `POST /conversations/:convId/pins { message_id }` for a DIRECT conversation
- **THEN** the system inserts the pin, creates a system message, broadcasts `pin_update`, and returns 201

#### Scenario: Admin pins a message in GROUP conversation
- **WHEN** an admin sends `POST /conversations/:convId/pins { message_id }` for a GROUP conversation
- **THEN** the system inserts the pin, creates a system message, broadcasts `pin_update`, and returns 201

#### Scenario: Non-admin attempts to pin in GROUP conversation
- **WHEN** a member with role "member" sends `POST /conversations/:convId/pins` for a GROUP conversation
- **THEN** the system returns 403 Forbidden

#### Scenario: Pin limit exceeded
- **WHEN** a user attempts to pin a 6th message in a conversation that already has 5 pins
- **THEN** the system returns 400 Bad Request with message "Maximum 5 pinned messages per conversation"

#### Scenario: Message already pinned
- **WHEN** a user attempts to pin a message that is already pinned
- **THEN** the system returns 409 Conflict

#### Scenario: Message does not belong to conversation
- **WHEN** a user attempts to pin a message_id that does not belong to the specified conversation
- **THEN** the system returns 404 Not Found

### Requirement: Unpin a message via REST API
The system SHALL expose `DELETE /conversations/:convId/pins/:messageId`. The endpoint SHALL validate membership, check permission (same rules as pin), delete from `pinned_messages`, create a system message "unpinned a message", and broadcast a `pin_update` event. The endpoint SHALL return 200.

#### Scenario: Admin unpins a message
- **WHEN** an admin sends `DELETE /conversations/:convId/pins/:messageId`
- **THEN** the system removes the pin, creates a system message, broadcasts `pin_update`, and returns 200

#### Scenario: Unpin a message that is not pinned
- **WHEN** a user sends `DELETE /conversations/:convId/pins/:messageId` for a message that is not pinned
- **THEN** the system returns 404 Not Found

### Requirement: List pinned messages via REST API
The system SHALL expose `GET /conversations/:convId/pins`. The endpoint SHALL validate membership and return all pinned messages ordered by `pinned_at DESC`, each including the message content, sender info, and pin metadata. The endpoint SHALL return 200 with an array.

#### Scenario: Retrieve pinned messages for a conversation
- **WHEN** a member sends `GET /conversations/:convId/pins`
- **THEN** the system returns 200 with an array of pinned messages ordered newest-pinned first, each containing `message_id`, `conv_id`, `pinned_by`, `pinned_at`, and nested message data (content, type, sender_id, sender name, created_at)

#### Scenario: No pinned messages
- **WHEN** a member sends `GET /conversations/:convId/pins` for a conversation with no pins
- **THEN** the system returns 200 with an empty array

### Requirement: Unpin all messages via REST API
The system SHALL expose `DELETE /conversations/:convId/pins` (no messageId param). The endpoint SHALL validate membership, require admin/creator role for GROUP (any member for DIRECT), delete all pins for the conversation, create a system message "unpinned all messages", and broadcast a `pin_update` event. The endpoint SHALL return 200.

#### Scenario: Admin unpins all messages in a group
- **WHEN** an admin sends `DELETE /conversations/:convId/pins` (no messageId)
- **THEN** the system removes all pins, creates a system message, broadcasts `pin_update` with action "unpinned_all", and returns 200

### Requirement: Real-time pin update broadcast
The system SHALL broadcast a `pin_update` event to all online conversation members via Redis PubSub after any pin/unpin action. The payload SHALL include `_event: "pin_update"`, `conv_id`, `action` ("pinned" | "unpinned" | "unpinned_all"), `message_id` (null for unpin_all), `pinned_by`, and `pinned_messages` (full updated list).

#### Scenario: Pin update received by online members
- **WHEN** a message is pinned in a conversation
- **THEN** all online members of that conversation receive a WebSocket event with event name `pin_update` containing the updated pinned messages list

### Requirement: Pin permission enforcement
The system SHALL enforce pin permissions: in DIRECT conversations, any member MAY pin/unpin. In GROUP conversations, only members with role "admin" or the conversation creator MAY pin/unpin. The system SHALL check `conversation_members.role` and `conversations.created_by` for authorization.

#### Scenario: Creator pins in GROUP without admin role
- **WHEN** the conversation creator (who may have role "member") sends a pin request for a GROUP conversation
- **THEN** the system allows the pin because the user is the creator

### Requirement: System messages for pin actions
The system SHALL create system messages (type "system") for pin/unpin actions using the existing `insertSystemMessage` pattern. The content key SHALL be "pinned_message" for pin and "unpinned_message" for unpin. The metadata SHALL include `{ action: "pinned_message", message_id, pinned_by }`.

#### Scenario: System message created on pin
- **WHEN** a message is pinned
- **THEN** a system message with content "pinned_message" and metadata containing the pinned message_id is inserted into the conversation and broadcast to all members

### Requirement: PinnedMessage TypeORM entity
The system SHALL have a `PinnedMessage` TypeORM entity mapped to the `pinned_messages` table with relations to `Conversation` (ManyToOne) and `User` (ManyToOne for pinned_by). The entity SHALL be registered in `ChatModule`'s `TypeOrmModule.forFeature()`.

#### Scenario: Entity is usable in repository queries
- **WHEN** the service injects `Repository<PinnedMessage>`
- **THEN** it can perform CRUD operations on the `pinned_messages` table

