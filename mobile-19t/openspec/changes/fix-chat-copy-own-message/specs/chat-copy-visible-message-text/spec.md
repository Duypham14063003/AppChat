## ADDED Requirements

### Requirement: Visible text messages SHALL expose copy actions from resolved display text
The chat UI SHALL determine text-message copy availability from the resolved text currently visible to the user, not only from the raw persisted message payload.

#### Scenario: Self-sent encrypted message shows readable text
- **WHEN** the current user opens the action menu for their own text message
- **AND** the message is visibly rendered with readable resolved text in the chat room
- **THEN** the `Sao chép` action SHALL be available even if the raw stored message payload would otherwise be empty or transformed

### Requirement: Copy action SHALL write the visible text shown to the user
When a text message is eligible for copying, the clipboard payload SHALL match the visible resolved text shown in the chat UI for that message.

#### Scenario: User copies their own resolved text message
- **WHEN** the user selects `Sao chép` on their own visible text message
- **THEN** the app SHALL copy the same readable message text that is shown in the bubble

### Requirement: Recalled and non-text messages SHALL remain excluded from text-copy action
Fixing self-message copy SHALL NOT make recalled messages or non-text message types appear copyable through the text-copy context-menu action.

#### Scenario: User opens action menu for recalled message
- **WHEN** a message has been recalled
- **THEN** the text-copy action SHALL NOT be shown

#### Scenario: User opens action menu for non-text message
- **WHEN** a message type is image, album, voice, video, file, or system
- **THEN** the text-copy action SHALL NOT be shown through the text-message copy menu path
