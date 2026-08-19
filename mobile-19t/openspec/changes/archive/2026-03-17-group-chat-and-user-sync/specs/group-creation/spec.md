## ADDED Requirements

### Requirement: Create group conversation API
The system SHALL provide `POST /conversations/group` endpoint that creates a GROUP conversation. The request body SHALL include `name` (string, required, 1-255 chars), `member_ids` (UUID array, required, min 2 max 200 unique IDs). The creator is automatically added as a member with role `creator`. All specified members are added with role `member`. The endpoint SHALL validate that all member_ids reference active users.

#### Scenario: Create group with valid members
- **WHEN** user sends `POST /conversations/group { name: "Dev Team", member_ids: ["id1", "id2", "id3"] }`
- **THEN** a conversation is created with type=GROUP, name="Dev Team", creator + 3 members added, and the conversation object is returned with HTTP 201

#### Scenario: Create group with fewer than 2 members
- **WHEN** user sends `POST /conversations/group { name: "Test", member_ids: ["id1"] }`
- **THEN** server returns HTTP 400 with validation error "At least 2 members required"

#### Scenario: Create group with invalid member ID
- **WHEN** user sends a request with a member_id that does not exist or is inactive
- **THEN** server returns HTTP 400 with error identifying the invalid member

#### Scenario: Create group with duplicate member IDs
- **WHEN** user sends a request with duplicate UUIDs in member_ids
- **THEN** duplicates are silently deduplicated before processing

### Requirement: Group creation generates system message
When a group is created, the system SHALL insert a message with type `system` and content `created_group` into the conversation. The message metadata SHALL include `{ action: "created_group", actor_name: "<creator_name>" }`.

#### Scenario: System message on group creation
- **WHEN** a group "Dev Team" is created by user "Nguyen Van A"
- **THEN** a system message is inserted: type=system, content="created_group", metadata includes actor_name and group name

### Requirement: Group creation subscribes online members
When a group is created, the system SHALL subscribe all online members to the conversation's Redis Pub/Sub channel so they receive real-time messages immediately.

#### Scenario: Online members receive group creation notification
- **WHEN** a group is created and member B is online via WebSocket
- **THEN** member B's WebSocket connections are subscribed to the new conversation channel

