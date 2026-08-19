## ADDED Requirements

### Requirement: Composer draft state SHALL reset on conversation switch
The chat composer SHALL start with a clean transient state when the user opens a different conversation than the one currently bound to the composer.

#### Scenario: Unsent text does not carry into another room
- **WHEN** the user has typed unsent draft text in conversation A
- **AND** the user navigates to conversation B
- **THEN** the composer in conversation B SHALL display no draft text from conversation A
- **AND** the composer SHALL be ready for new input for conversation B

#### Scenario: Returning to another room does not reuse the prior room instance
- **WHEN** the user enters draft text in conversation A
- **AND** the user opens conversation B
- **THEN** the composer for conversation B SHALL be created with a clean draft state even if the chat screen widget tree is reused during navigation

### Requirement: Conversation switch SHALL clear transient composer UI state
The system SHALL clear transient composer state derived from the previous conversation when the active `conversationId` changes.

#### Scenario: Mention state is cleared on room switch
- **WHEN** the user has an active mention query or mention metadata in conversation A
- **AND** the user navigates to conversation B
- **THEN** the composer in conversation B SHALL not retain the previous conversation's mention query, mention offsets, or mention overlay

#### Scenario: Preview and emoji state are cleared on room switch
- **WHEN** the composer in conversation A has an active emoji panel, link preview, or preview loading state
- **AND** the user navigates to conversation B
- **THEN** the composer in conversation B SHALL not retain those transient states from conversation A

### Requirement: Same-conversation rebuilds SHALL preserve composer continuity
The system SHALL preserve normal composer continuity when the active conversation does not change.

#### Scenario: Same-room updates keep the draft
- **WHEN** the user has typed unsent draft text in the active conversation
- **AND** the conversation screen rebuilds without changing `conversationId`
- **THEN** the composer SHALL preserve the existing draft text and remain usable

#### Scenario: Edit and reply flows remain scoped to same-room behavior
- **WHEN** the composer is in reply or edit mode for the active conversation
- **AND** the conversation screen rebuilds without changing `conversationId`
- **THEN** the composer SHALL preserve the current reply or edit state until the user sends or cancels it
