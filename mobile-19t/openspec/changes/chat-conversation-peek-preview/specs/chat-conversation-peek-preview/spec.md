## ADDED Requirements

### Requirement: Users can peek at a conversation without marking it read
The system SHALL allow users to preview recent messages from a conversation list item without changing that conversation's read/unread state.

#### Scenario: Long-press opens conversation preview
- **WHEN** the user long-presses a conversation row in the chat list
- **THEN** the system SHALL open a read-only conversation preview surface for that conversation

#### Scenario: Preview preserves unread counters
- **WHEN** a conversation has unread messages and the user opens then dismisses the preview
- **THEN** the conversation SHALL remain unread and its unread counters SHALL remain unchanged

#### Scenario: Preview does not send read receipts
- **WHEN** the preview loads or refreshes recent messages
- **THEN** the system SHALL NOT send a websocket `mark_read` event for that conversation

### Requirement: Full conversation entry remains read-consuming
The system SHALL keep the existing full conversation entry behavior where opening the full chat marks visible messages as read through the established read-sync flow.

#### Scenario: Single tap opens full chat
- **WHEN** the user single-taps a conversation row
- **THEN** the system SHALL open the full chat screen using the existing route
- **AND** existing read reconciliation MAY mark the conversation as read

#### Scenario: Open chat from preview
- **WHEN** the user taps the preview surface's explicit "Open chat" action
- **THEN** the system SHALL navigate to the full chat screen
- **AND** existing read reconciliation MAY mark the conversation as read

### Requirement: Preview loading uses a read-only data path
The system SHALL load preview messages through a path that is separate from active conversation read reconciliation.

#### Scenario: Preview loads cached messages
- **WHEN** recent messages are available in local cache
- **THEN** the preview SHALL render those messages without setting the active conversation id

#### Scenario: Preview refreshes server messages
- **WHEN** the preview refreshes recent messages from the server
- **THEN** the system MAY cache the fetched messages for later display
- **AND** the system SHALL NOT reset unread counters or write `lastViewedAt`

### Requirement: Preview UI is read-only and transient
The system SHALL present the peek preview as a transient read-only surface that does not expose full chat composer behavior.

#### Scenario: Preview on narrow screens
- **WHEN** the user opens a peek preview on a phone-sized screen
- **THEN** the preview SHALL appear as a modal bottom sheet

#### Scenario: Preview on wide screens
- **WHEN** the user opens a peek preview on a wide layout
- **THEN** the preview SHALL appear as a dialog or popover-style surface without selecting the conversation in the split chat panel

#### Scenario: Preview content is simplified
- **WHEN** recent messages include deleted, system, or non-text messages
- **THEN** the preview SHALL render safe simplified text for those messages instead of exposing unsupported full-message actions
