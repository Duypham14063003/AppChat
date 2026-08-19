## ADDED Requirements

### Requirement: Remote typing activity SHALL NOT interrupt composer focus
The chat composer SHALL remain focused and editable when another participant starts, continues, or stops typing in the active conversation.

#### Scenario: Typing indicator appears while composing
- **WHEN** the local user has focus in the chat composer and has typed draft text
- **AND** a remote typing event for the same conversation causes the typing indicator to appear
- **THEN** the composer SHALL remain focused
- **AND** the draft text SHALL remain unchanged
- **AND** the local user SHALL be able to continue entering text

#### Scenario: Typing indicator updates while composing
- **WHEN** the local user has focus in the chat composer
- **AND** repeated remote typing events update the typing indicator
- **THEN** the composer SHALL remain focused and editable

#### Scenario: Typing indicator expires while composing
- **WHEN** the local user has focus in the chat composer
- **AND** the remote typing indicator is removed by timeout or cleanup
- **THEN** the composer SHALL remain focused and editable

### Requirement: Remote message activity SHALL NOT interrupt composer draft
The chat composer SHALL preserve focus, draft text, cursor state, and editability when messages from other participants arrive in the active conversation.

#### Scenario: Remote message arrives while composing
- **WHEN** the local user has focus in the chat composer and has typed draft text
- **AND** a remote message for the active conversation is inserted into the message list
- **THEN** the composer SHALL remain focused
- **AND** the draft text SHALL remain unchanged
- **AND** the local user SHALL be able to continue entering text

#### Scenario: Remote message auto-scrolls while composing near bottom
- **WHEN** the local user has focus in the chat composer near the bottom of the conversation
- **AND** a remote message arrives and the conversation performs its normal near-bottom scroll behavior
- **THEN** the composer SHALL remain focused and editable

### Requirement: Intentional keyboard dismissal SHALL remain available
The system SHALL preserve existing keyboard dismissal behavior for explicit local user interactions outside the composer.

#### Scenario: Local user taps outside composer
- **WHEN** the local user has focus in the chat composer
- **AND** the local user taps a non-composer area of the chat screen
- **THEN** the composer focus SHALL be dismissed

#### Scenario: Local user drags message list
- **WHEN** the local user has focus in the chat composer
- **AND** the local user drags the message list to browse conversation history
- **THEN** the composer focus SHALL be dismissed according to the existing message-list drag behavior

#### Scenario: Remote updates do not count as outside interactions
- **WHEN** the local user has focus in the chat composer
- **AND** remote typing or message events update the chat screen without a local outside pointer gesture
- **THEN** the composer focus SHALL NOT be dismissed by outside-interaction handlers

### Requirement: Composer actions SHALL remain coherent after remote activity
The chat composer SHALL preserve core composer actions after remote typing or message activity occurs.

#### Scenario: Send after remote activity
- **WHEN** the local user has typed draft text in the composer
- **AND** remote typing or message activity updates the active conversation
- **AND** the local user sends the draft message
- **THEN** the message SHALL be sent with the full draft text

#### Scenario: Reply and edit state survive remote activity
- **WHEN** the composer is in reply or edit mode
- **AND** remote typing or message activity updates the active conversation
- **THEN** the composer SHALL preserve the active reply or edit context until the local user sends or cancels it

#### Scenario: Transient composer UI remains usable after remote activity
- **WHEN** composer transient UI such as mention suggestions or the emoji panel is active
- **AND** remote typing or message activity updates the active conversation
- **THEN** the composer SHALL remain usable without stale disabled or unfocused state
