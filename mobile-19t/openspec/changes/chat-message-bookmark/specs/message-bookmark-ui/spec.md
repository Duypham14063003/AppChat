## ADDED Requirements

### Requirement: Bookmark action in the message context menu
The system SHALL show a bookmark action in the existing long-press message context menu for non-system messages. The label SHALL be "Đánh dấu tin nhắn" when the message is not bookmarked by the current user and "Bỏ đánh dấu" when it already is.

#### Scenario: Show bookmark action for unbookmarked message
- **WHEN** the user long-presses a normal message that is not in their bookmark set
- **THEN** the context menu shows the action "Đánh dấu tin nhắn"

#### Scenario: Show unbookmark action for bookmarked message
- **WHEN** the user long-presses a message they previously bookmarked
- **THEN** the context menu shows the action "Bỏ đánh dấu"

### Requirement: Bookmark action updates private state
The system SHALL call the bookmark REST API when the user taps the bookmark action, dismiss the bottom sheet, refresh bookmark state for the current conversation, and show user feedback if the request fails.

#### Scenario: Bookmark from context menu
- **WHEN** the user taps "Đánh dấu tin nhắn"
- **THEN** the app stores the bookmark through the backend and updates local bookmark state for that conversation

#### Scenario: Backend bookmark request fails
- **WHEN** the bookmark API returns an error
- **THEN** the app keeps the previous bookmark state and shows an error SnackBar

### Requirement: Local bookmark cache
The system SHALL store bookmark state in a Drift table dedicated to bookmarked messages and load that cache before the network refresh completes. The schema migration SHALL preserve existing chat data while adding bookmark storage.

#### Scenario: Cached bookmarks appear before refresh
- **WHEN** the user opens a conversation that has locally cached bookmarked messages
- **THEN** the app can determine bookmarked state immediately before the latest API response arrives

### Requirement: Conversation bookmark provider
The system SHALL provide a conversation-scoped bookmark state provider that can answer whether a message is bookmarked, refresh from the backend, and expose the ordered bookmark list for UI consumers.

#### Scenario: Query message bookmark state
- **WHEN** the context menu is built for a message
- **THEN** the app can determine from the provider whether the current user has bookmarked that message

#### Scenario: Refresh bookmark list after mutation
- **WHEN** a bookmark is created or removed
- **THEN** the provider refreshes and exposes the latest conversation bookmark list

### Requirement: Browse bookmarked messages in a conversation
The system SHALL provide a conversation-scoped bookmarked-messages browsing UI that lists the current user's bookmarked messages ordered by bookmark time and lets the user tap an entry to jump back to the source message in the chat timeline.

#### Scenario: Open bookmarked messages list
- **WHEN** the user opens the bookmarked-messages UI for a conversation
- **THEN** the app shows only that user's bookmarked messages for that conversation ordered newest-bookmarked first

#### Scenario: Jump from bookmark list to message
- **WHEN** the user taps an item in the bookmarked-messages list
- **THEN** the app navigates back to the chat view and scrolls to the original message

### Requirement: Optional bookmarked visual state in chat
The system SHALL support showing bookmarked state on individual messages in the conversation UI so the current user can recognize which messages they saved without opening the bookmark list.

#### Scenario: Bookmarked message shows saved state
- **WHEN** a message is bookmarked by the current user
- **THEN** the chat UI can render a bookmark indicator for that message visible only within that user's app session and synced state
