## ADDED Requirements

### Requirement: Chat composer focus SHALL dismiss on outside tap
The system SHALL dismiss composer input focus when the user taps outside the active chat input area in the conversation screen.

#### Scenario: User taps message area while composer is focused
- **WHEN** the chat composer `TextField` is focused and the software keyboard is visible
- **AND** the user taps the message-list area outside the composer
- **THEN** the composer focus is removed and the keyboard begins dismissing

#### Scenario: User taps non-input chrome while composer is focused
- **WHEN** the chat composer `TextField` is focused
- **AND** the user taps non-input UI regions in the conversation screen (outside composer controls)
- **THEN** the composer focus is removed

### Requirement: Message-list drag SHALL support keyboard dismissal
The system SHALL dismiss composer focus when users drag/scroll the message list while the composer is focused.

#### Scenario: User scrolls message list with keyboard open
- **WHEN** the chat composer is focused and the keyboard is visible
- **AND** the user drags the message list to browse messages
- **THEN** the keyboard dismiss behavior is triggered and the composer focus is cleared

### Requirement: Composer transient overlays SHALL stay consistent after focus dismissal
The system SHALL keep mention/emoji UI state coherent after outside-interaction focus dismissal.

#### Scenario: Mention suggestions visible then user taps outside
- **WHEN** mention suggestions are visible for the active composer
- **AND** the user performs an outside tap dismissal interaction
- **THEN** the mention suggestion overlay is dismissed and composer focus is cleared

#### Scenario: User re-focuses composer after dismissal
- **WHEN** composer focus was dismissed by outside interaction
- **AND** the user taps back into the composer input
- **THEN** the input resumes normal typing behavior without stale overlay state from the previous focus session

### Requirement: Keyboard dismissal changes SHALL not break core composer actions
The system SHALL preserve send/edit/reply interactions after keyboard dismissal behavior is introduced.

#### Scenario: Send after re-focusing composer
- **WHEN** the user dismisses keyboard via outside tap
- **AND** re-focuses the composer and sends a message
- **THEN** message send behavior remains unchanged from current flow

#### Scenario: Edit mode remains functional after dismissal
- **WHEN** composer is in message edit mode and focus is dismissed by outside interaction
- **THEN** the user can re-focus and continue/cancel edit mode without losing edit-state integrity
