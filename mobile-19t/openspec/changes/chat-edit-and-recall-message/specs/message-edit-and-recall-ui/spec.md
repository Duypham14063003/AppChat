## ADDED Requirements

### Requirement: Message context menu exposes sender-only edit and recall actions
The system SHALL show `Sửa` and `Thu hồi` actions in the mobile message context menu only when the selected message is eligible for those actions for the current user.

#### Scenario: Sender long-presses editable text message
- **WHEN** the current user long-presses their own non-recalled text message
- **THEN** the context menu shows both `Sửa` and `Thu hồi`

#### Scenario: Sender long-presses own non-text message
- **WHEN** the current user long-presses their own non-text message
- **THEN** the context menu shows `Thu hồi` but does not show `Sửa`

#### Scenario: User long-presses someone else's message
- **WHEN** the current user long-presses a message sent by another participant
- **THEN** the context menu does not show `Sửa` or `Thu hồi`

### Requirement: Mobile composer supports editing an existing text message
The system SHALL let the user enter a temporary edit mode from the message context menu, prefill the composer with the current message text, and allow the user to save or cancel the edit.

#### Scenario: Enter edit mode
- **WHEN** the user taps `Sửa` on an eligible text message
- **THEN** the composer switches into edit mode with the existing message content prefilled

#### Scenario: Save edited content
- **WHEN** the user confirms the edit from composer edit mode
- **THEN** the app sends the edit mutation and updates the target message in the current timeline after success

#### Scenario: Cancel edit mode
- **WHEN** the user cancels edit mode before saving
- **THEN** the composer exits edit mode and the original message remains unchanged

### Requirement: Edited and recalled messages render explicit timeline state
The system SHALL render edited messages with a visible edited indicator and recalled messages with a visible placeholder in the conversation timeline.

#### Scenario: Edited message stays visible
- **WHEN** an edited message appears in the conversation timeline
- **THEN** the bubble shows the latest text content together with an edited-state indicator

#### Scenario: Recalled message stays visible as placeholder
- **WHEN** a recalled message appears in the conversation timeline
- **THEN** the chat keeps its place in the message order and renders a recalled-message placeholder instead of the original content

#### Scenario: Reply target was recalled
- **WHEN** the user views a reply preview that points to a recalled message
- **THEN** the app renders a degraded preview state that indicates the original message was recalled

### Requirement: Mobile chat state stays synchronized after edit and recall mutations
The system SHALL update the local chat timeline from successful mutations, realtime events, and history refreshes without requiring the user to manually reload the conversation.

#### Scenario: Open conversation receives edit event
- **WHEN** the chat screen is open and a relevant message-updated event arrives
- **THEN** the app updates that message in local state and re-renders the timeline

#### Scenario: Open conversation receives recall event
- **WHEN** the chat screen is open and a relevant message-recalled event arrives
- **THEN** the app updates that message in local state and re-renders it as recalled

#### Scenario: Reconnect loads edited or recalled messages
- **WHEN** the app refreshes a conversation from history or sync after reconnecting
- **THEN** edited and recalled messages appear with the same state as they would from realtime updates

### Requirement: Conversation list previews stay synchronized with edited and recalled latest messages
The system SHALL update the mobile conversation-list preview when the latest message in a conversation is edited or recalled so the list does not continue showing stale content.

#### Scenario: Latest message is recalled from the open conversation
- **WHEN** the current user recalls the latest message in a conversation
- **THEN** the conversation list preview updates to the recalled-message placeholder without waiting for a manual refresh

#### Scenario: Latest message is recalled by realtime event
- **WHEN** a `message_recalled` event arrives for the latest message in a conversation
- **THEN** the conversation list preview updates to the recalled-message placeholder on other connected sessions

#### Scenario: Latest message is edited
- **WHEN** the latest text message in a conversation is edited successfully
- **THEN** the conversation list preview updates to the edited text content instead of keeping the pre-edit snapshot
