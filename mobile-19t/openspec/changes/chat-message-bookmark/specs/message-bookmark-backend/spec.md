## ADDED Requirements

### Requirement: Private message bookmark storage
The system SHALL store private chat bookmarks in a dedicated `message_bookmarks` table keyed by the authenticated user and the bookmarked message. Each bookmark record SHALL include `user_id`, `conv_id`, `message_id`, and `marked_at`, and the schema SHALL prevent duplicate bookmarks for the same user and message.

#### Scenario: Store a bookmark record
- **WHEN** a user bookmarks a message in a conversation they belong to
- **THEN** the system inserts exactly one `message_bookmarks` row for that `user_id`, `conv_id`, and `message_id`

### Requirement: Bookmark a message via REST API
The system SHALL expose `POST /conversations/:convId/bookmarks` accepting `{ message_id: uuid }`. The endpoint SHALL derive the acting user from the access token, verify the user is a member of the conversation, verify the message belongs to that conversation, reject duplicate bookmarks, and create the bookmark record without broadcasting any real-time event or creating any system message.

#### Scenario: Bookmark a visible message
- **WHEN** a conversation member sends `POST /conversations/:convId/bookmarks` with a valid `message_id` from that conversation
- **THEN** the system returns success and stores the bookmark for that user only

#### Scenario: Reject duplicate bookmark
- **WHEN** the same user bookmarks the same message again
- **THEN** the system returns an error indicating the message is already bookmarked for that user

#### Scenario: Reject foreign-conversation message
- **WHEN** a user submits a `message_id` that does not belong to the specified conversation
- **THEN** the system returns `404 Not Found`

### Requirement: Remove a bookmark via REST API
The system SHALL expose `DELETE /conversations/:convId/bookmarks/:messageId`. The endpoint SHALL validate membership and delete only the current user's bookmark record for that message in that conversation.

#### Scenario: Remove an existing bookmark
- **WHEN** a user sends `DELETE /conversations/:convId/bookmarks/:messageId` for a message they bookmarked
- **THEN** the system deletes only that user's bookmark and returns success

#### Scenario: Remove a bookmark that does not exist
- **WHEN** a user sends `DELETE /conversations/:convId/bookmarks/:messageId` for a message they have not bookmarked
- **THEN** the system returns `404 Not Found`

### Requirement: List bookmarked messages for the current user
The system SHALL expose `GET /conversations/:convId/bookmarks`. The endpoint SHALL return only the current user's bookmarked messages for that conversation ordered by `marked_at DESC`, including enough message metadata for the client to render a list and jump back to the original message.

#### Scenario: Return conversation bookmarks
- **WHEN** a user sends `GET /conversations/:convId/bookmarks`
- **THEN** the system returns an array of only that user's bookmarks for the conversation ordered newest-marked first

#### Scenario: Return empty bookmark list
- **WHEN** a user requests bookmarks for a conversation where they have none
- **THEN** the system returns `200 OK` with an empty array

### Requirement: Bookmark state remains private
The system SHALL NOT create system messages, SHALL NOT update shared pin state, and SHALL NOT broadcast bookmark mutations to other conversation members when bookmarks are created or removed.

#### Scenario: Other members do not observe bookmark mutations
- **WHEN** one user bookmarks or unbookmarks a message
- **THEN** other members of the conversation do not receive any conversation-visible change caused by that bookmark action
