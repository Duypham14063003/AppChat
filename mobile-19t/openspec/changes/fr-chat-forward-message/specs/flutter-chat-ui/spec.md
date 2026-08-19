## MODIFIED Requirements

### Requirement: Drift local database schema for chat
The Flutter app SHALL define Drift tables for `conversations` and `messages` mirroring the server schema. The `LocalMessages` table SHALL include `forwardedFromId` (text nullable) and `forwardedFromSender` (text nullable) columns. The local DB SHALL support: insert/update/delete operations, query by conversation with ordering, FTS5 search on message content, and 7-day eviction policy.

#### Scenario: Drift schema includes forward columns
- **WHEN** a forwarded message is received from server API or WebSocket
- **THEN** it can be inserted into Drift `LocalMessages` table with `forwardedFromId` and `forwardedFromSender` populated without data loss

#### Scenario: Migration from schema version 3 to 4
- **WHEN** app upgrades from schema version 3 to 4
- **THEN** `forwardedFromId` and `forwardedFromSender` columns are added to `local_messages` table via ALTER TABLE, existing messages are unaffected

## ADDED Requirements

### Requirement: MessageBubble selection mode support
The ChatScreen SHALL support a selection mode where messages display checkboxes and respond to tap for selection toggle. In selection mode, the normal message tap behavior (if any) SHALL be suppressed.

#### Scenario: Message shows checkbox in selection mode
- **WHEN** ChatScreen is in selection mode
- **THEN** each non-system message shows a circular checkbox to its left

#### Scenario: Tap message in selection mode toggles selection
- **WHEN** user taps a message in selection mode
- **THEN** the message's selection state toggles and the checkbox updates

### Requirement: Forward messages provider method
The chat providers SHALL include a `forwardMessages(List<String> messageIds, List<String> convIds, bool hideSender)` method that sends the `forward_message` WebSocket event and handles the ack response.

#### Scenario: Forward messages via provider
- **WHEN** `forwardMessages` is called with message IDs, conversation IDs, and hideSender flag
- **THEN** a `forward_message` WebSocket event is sent with the correct payload

