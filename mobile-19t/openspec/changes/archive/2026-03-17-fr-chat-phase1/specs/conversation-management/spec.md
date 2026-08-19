## ADDED Requirements

### Requirement: Create direct conversation
The system SHALL provide `POST /conversations` endpoint to create a DIRECT conversation between two users. If a DIRECT conversation already exists between the two users, the system SHALL return the existing conversation instead of creating a duplicate.

#### Scenario: Create new direct conversation
- **WHEN** user A sends `POST /conversations { type: "DIRECT", member_id: "<user_B_id>" }`
- **THEN** a new conversation is created with type DIRECT, both users added as members, and the conversation object is returned with HTTP 201

#### Scenario: Direct conversation already exists
- **WHEN** user A sends `POST /conversations { type: "DIRECT", member_id: "<user_B_id>" }` and a DIRECT conversation between A and B already exists
- **THEN** the existing conversation is returned with HTTP 200

#### Scenario: Cannot create direct conversation with self
- **WHEN** user sends `POST /conversations { type: "DIRECT", member_id: "<own_id>" }`
- **THEN** server returns HTTP 400 with error message

### Requirement: List user's conversations
The system SHALL provide `GET /conversations` endpoint that returns all conversations the authenticated user is a member of, sorted by `last_message_at DESC` (most recent first). The response SHALL include last message preview, unread count, and other member info for DIRECT conversations.

#### Scenario: List conversations with pagination
- **WHEN** user sends `GET /conversations?limit=20&cursor=<timestamp>`
- **THEN** server returns up to 20 conversations with `{ conversations, nextCursor, hasMore }`

#### Scenario: Conversation includes last message preview
- **WHEN** user lists conversations
- **THEN** each conversation includes `lastMessage: { content, senderName, type, createdAt }` (truncated to 100 chars)

#### Scenario: Conversation includes unread count
- **WHEN** user lists conversations
- **THEN** each conversation includes `unreadCount` calculated as messages after `conversation_members.last_read_at`

### Requirement: Get conversation details
The system SHALL provide `GET /conversations/:id` endpoint that returns conversation details including members list. Only members of the conversation can access it.

#### Scenario: Get conversation as member
- **WHEN** member sends `GET /conversations/:id`
- **THEN** server returns conversation details with members list

#### Scenario: Get conversation as non-member
- **WHEN** non-member sends `GET /conversations/:id`
- **THEN** server returns HTTP 403

### Requirement: Cursor-based message pagination
The system SHALL provide `GET /conversations/:id/messages` endpoint with cursor-based pagination using timestamp. Default page size is 30 messages. Supports `dir=before` (older) and `dir=after` (newer).

#### Scenario: Load initial messages
- **WHEN** user sends `GET /conversations/:id/messages?limit=30`
- **THEN** server returns the 30 most recent messages with `{ messages, nextCursor, hasMore }`

#### Scenario: Load older messages (infinite scroll)
- **WHEN** user sends `GET /conversations/:id/messages?cursor=<timestamp>&limit=30&dir=before`
- **THEN** server returns 30 messages older than cursor timestamp

#### Scenario: No more messages
- **WHEN** user requests messages and there are no more older messages
- **THEN** server returns `{ messages: [...], nextCursor: null, hasMore: false }`

### Requirement: Conversation access control
All conversation endpoints SHALL verify the authenticated user is a member of the conversation before returning data or accepting modifications. Non-members SHALL receive HTTP 403.

#### Scenario: Non-member cannot read messages
- **WHEN** non-member sends `GET /conversations/:id/messages`
- **THEN** server returns HTTP 403 with `{ message: "Not a member of this conversation" }`

