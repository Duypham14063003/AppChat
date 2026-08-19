## ADDED Requirements

### Requirement: Migration alters reaction PK to support multi-reaction
The system SHALL migrate the `message_reactions` table to use composite PK `(message_id, user_id, emoji)` instead of `(message_id, user_id)`. The migration SHALL add an index on `message_id` for fast lookups.

#### Scenario: Migration runs successfully
- **WHEN** the migration is executed
- **THEN** the `message_reactions` table PK is `(message_id, user_id, emoji)` and an index `idx_reactions_message_id` exists on `message_id`

### Requirement: Toggle reaction inserts or deletes
The `ChatService` SHALL expose a `toggleReaction(userId, messageId, convId, emoji)` method. If the reaction `(message_id, user_id, emoji)` exists, it SHALL be deleted. If it does not exist, it SHALL be inserted.

#### Scenario: Add a new reaction
- **WHEN** user sends `toggle_reaction` with `emoji: "👍"` and no existing reaction for that tuple
- **THEN** a row `(message_id, user_id, "👍")` is inserted into `message_reactions`

#### Scenario: Remove an existing reaction
- **WHEN** user sends `toggle_reaction` with `emoji: "👍"` and a row `(message_id, user_id, "👍")` already exists
- **THEN** that row is deleted from `message_reactions`

### Requirement: Enforce max 3 reactions per user per message
The system SHALL reject a new reaction if the user already has 3 different emoji reactions on the same message. The existing reactions SHALL NOT be affected.

#### Scenario: User at reaction limit
- **WHEN** user has 3 reactions on a message and sends `toggle_reaction` with a 4th emoji
- **THEN** the server responds with error code `REACTION_LIMIT` and message "Maximum 3 reactions per message"

#### Scenario: Toggle-off still works at limit
- **WHEN** user has 3 reactions and sends `toggle_reaction` for an emoji they already reacted with
- **THEN** that reaction is removed (toggle-off is not blocked by the limit)

### Requirement: Membership validation
The system SHALL verify that the user is a member of the conversation before allowing a reaction. Non-members SHALL receive a `FORBIDDEN` error.

#### Scenario: Non-member attempts reaction
- **WHEN** a user who is not a member of the conversation sends `toggle_reaction`
- **THEN** the server responds with error code `FORBIDDEN`

### Requirement: WebSocket event toggle_reaction
The `ChatGateway` SHALL handle a `toggle_reaction` client event with payload `{ message_id, conv_id, emoji }`. It SHALL delegate to `ChatService.toggleReaction()`.

#### Scenario: Client sends toggle_reaction
- **WHEN** an authenticated client sends `{ event: "toggle_reaction", data: { message_id, conv_id, emoji } }`
- **THEN** the gateway calls `ChatService.toggleReaction()` and processes the result

### Requirement: Broadcast reaction_update to conversation members
After a successful toggle, the system SHALL broadcast a `reaction_update` event to all online members of the conversation via Redis PubSub. The payload SHALL include `message_id`, `conv_id`, `user_id`, `user_name`, `emoji`, `action` ("added" or "removed"), and a full `reactions` array with aggregated counts and user lists.

#### Scenario: Reaction added broadcast
- **WHEN** user "Nguyen A" adds 👍 to a message in a conversation with 3 members
- **THEN** all online members receive `{ event: "reaction_update", data: { message_id, conv_id, user_id, user_name: "Nguyen A", emoji: "👍", action: "added", reactions: [{ emoji: "👍", count: N, users: [{id, name}] }, ...] } }`

#### Scenario: Reaction removed broadcast
- **WHEN** user removes their 👍 reaction
- **THEN** all online members receive `reaction_update` with `action: "removed"` and updated `reactions` array

### Requirement: Reactions included in message fetch responses
The `getMessages()` and `syncMessages()` methods SHALL include a `reactions` field on each message. The field SHALL contain an array of `{ emoji, count, users: [{ id, name }] }` objects, aggregated from `message_reactions` joined with `users`.

#### Scenario: Fetch messages with reactions
- **WHEN** client fetches messages for a conversation
- **THEN** each message object includes a `reactions` array (empty array if no reactions)

#### Scenario: Sync includes reactions
- **WHEN** client syncs messages since a timestamp
- **THEN** synced messages include their current `reactions` array

### Requirement: DTO validation for toggle_reaction
The system SHALL validate the `toggle_reaction` payload: `message_id` (UUID), `conv_id` (UUID), and `emoji` (string, max 10 chars, non-empty) are all required.

#### Scenario: Missing emoji field
- **WHEN** client sends `toggle_reaction` without `emoji`
- **THEN** server responds with error code `INVALID_FORMAT`

#### Scenario: Invalid emoji length
- **WHEN** client sends `toggle_reaction` with emoji longer than 10 characters
- **THEN** server responds with error code `INVALID_FORMAT`
