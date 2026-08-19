## ADDED Requirements

### Requirement: Pinned message bar at top of chat screen
The system SHALL display a `PinnedMessageBar` widget between the WebSocket connection banner and the message list in `ChatScreen`. The bar SHALL show the currently selected pinned message's sender name and truncated content (max 1 line, ellipsis overflow). The bar SHALL display a pin icon (📌) and the current pin index (e.g., "2/3"). The bar SHALL only be visible when the conversation has at least one pinned message.

#### Scenario: Bar displays when pins exist
- **WHEN** a conversation has 3 pinned messages
- **THEN** the PinnedMessageBar is visible showing "📌 1/3" and the newest pinned message's content

#### Scenario: Bar hidden when no pins
- **WHEN** a conversation has no pinned messages
- **THEN** the PinnedMessageBar is not rendered

### Requirement: Tap pinned bar to scroll to message
The system SHALL scroll to the currently displayed pinned message and highlight it for 2 seconds when the user taps the PinnedMessageBar. The scroll SHALL use the existing `ItemScrollController` from `ScrollablePositionedList`.

#### Scenario: Tap scrolls to pinned message
- **WHEN** the user taps the PinnedMessageBar showing message X
- **THEN** the message list scrolls to message X and highlights it for 2 seconds

### Requirement: Tap pinned bar to cycle through pins
The system SHALL cycle through pinned messages on repeated taps of the PinnedMessageBar. The cycle order SHALL be newest-pinned first, then older pins, wrapping back to newest. The counter display SHALL update (e.g., "1/3" → "2/3" → "3/3" → "1/3"). Each tap SHALL also scroll to the newly selected pin.

#### Scenario: Cycle through 3 pinned messages
- **WHEN** the user taps the PinnedMessageBar 3 times
- **THEN** the bar cycles through pins showing "1/3", "2/3", "3/3" and scrolls to each respective message

#### Scenario: Cycle wraps around
- **WHEN** the user is viewing pin "3/3" and taps again
- **THEN** the bar shows "1/3" and scrolls to the newest pinned message

### Requirement: Pinned messages list screen
The system SHALL provide a `PinnedMessagesListScreen` accessible by tapping a "📌 N pinned" indicator in the chat AppBar (shown when pins exist). The screen SHALL display all pinned messages in a scrollable list ordered by `pinned_at` DESC. Each item SHALL show the message sender name, avatar, content preview, message timestamp, and who pinned it. Tapping an item SHALL navigate back to the chat screen and scroll to that message.

#### Scenario: Open pinned messages list
- **WHEN** the user taps "📌 3 pinned" in the chat AppBar
- **THEN** the PinnedMessagesListScreen opens showing all 3 pinned messages

#### Scenario: Tap item to jump to message
- **WHEN** the user taps a pinned message in the list
- **THEN** the app navigates back to the chat screen and scrolls to that message with highlight

#### Scenario: Empty state
- **WHEN** the pinned messages list screen is opened but all pins have been removed
- **THEN** the screen shows an empty state message

### Requirement: Pin count indicator in chat AppBar
The system SHALL display a tappable "📌 N" badge in the chat AppBar actions when the conversation has pinned messages. N is the total number of pinned messages. Tapping it opens the PinnedMessagesListScreen.

#### Scenario: Pin count badge visible
- **WHEN** a conversation has 2 pinned messages
- **THEN** the AppBar shows a "📌 2" action button

#### Scenario: Pin count badge hidden
- **WHEN** a conversation has no pinned messages
- **THEN** no pin badge is shown in the AppBar

### Requirement: LocalPinnedMessages Drift table
The system SHALL add a `LocalPinnedMessages` table to the Drift database with columns: `convId` (text), `messageId` (text), `pinnedBy` (text), `pinnedAt` (dateTime), with composite primary key `(convId, messageId)`. The schema version SHALL increment from 5 to 6 with appropriate migration.

#### Scenario: Schema migration from 5 to 6
- **WHEN** the app upgrades from schema version 5 to 6
- **THEN** the `LocalPinnedMessages` table is created

### Requirement: Pinned messages Riverpod provider
The system SHALL provide a `pinnedMessagesProvider(conversationId)` family AsyncNotifier that loads pinned messages from the local Drift table, fetches from the REST API on init, and listens for `pin_update` WebSocket events to stay in sync. The provider SHALL expose the list of pinned messages ordered by `pinned_at` DESC.

#### Scenario: Provider loads pinned messages on init
- **WHEN** the ChatScreen is opened for a conversation
- **THEN** the pinnedMessagesProvider fetches pinned messages from the API and caches them locally

#### Scenario: Provider updates on pin_update event
- **WHEN** a `pin_update` WebSocket event is received for the conversation
- **THEN** the provider updates its state with the new pinned messages list from the event payload

### Requirement: Pin/unpin via ChatRepository
The system SHALL add methods to `ChatRepository`: `pinMessage(convId, messageId)`, `unpinMessage(convId, messageId)`, `getPinnedMessages(convId)`, and `unpinAllMessages(convId)`. These SHALL call the corresponding REST endpoints.

#### Scenario: Pin message HTTP call
- **WHEN** `pinMessage(convId, messageId)` is called
- **THEN** it sends `POST /conversations/:convId/pins` with `{ message_id }` and returns the response

### Requirement: Real-time pin update handling
The system SHALL register a `pin_update` WebSocket event handler in the pinned messages provider. When received, the handler SHALL update the local Drift table and provider state with the new pinned messages list from the event payload.

#### Scenario: Remote pin update syncs locally
- **WHEN** another user pins a message and the `pin_update` event arrives
- **THEN** the local `LocalPinnedMessages` table is updated and the UI reflects the new pin immediately

