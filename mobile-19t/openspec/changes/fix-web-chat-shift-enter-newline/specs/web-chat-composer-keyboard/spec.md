## ADDED Requirements

### Requirement: Web composer supports Shift+Enter newline
The web chat composer SHALL insert a newline at the current cursor or selection when the user presses Shift+Enter.

#### Scenario: Insert newline at cursor
- **WHEN** a web user focuses the chat composer, types text, places the cursor in the composer, and presses Shift+Enter
- **THEN** the composer text SHALL include a newline at the cursor position
- **AND** the message SHALL NOT be sent

#### Scenario: Keep caret visible after newline
- **WHEN** a web user presses Shift+Enter while the composer is already filled to its visible multiline height
- **THEN** the composer SHALL scroll its text viewport so the cursor position after the inserted newline remains visible

#### Scenario: Replace selected text with newline
- **WHEN** a web user selects part of the composer text and presses Shift+Enter
- **THEN** the selected text SHALL be replaced with a newline
- **AND** the cursor SHALL move after the inserted newline

### Requirement: Web composer preserves Enter-to-send
The web chat composer SHALL preserve the existing desktop shortcut where Enter without Shift sends the message.

#### Scenario: Enter sends non-empty message
- **WHEN** a web user focuses the chat composer, enters a non-empty message, and presses Enter without Shift
- **THEN** the composer SHALL send the current message

#### Scenario: Enter does not send empty message
- **WHEN** a web user focuses the chat composer with empty or whitespace-only text and presses Enter without Shift
- **THEN** the composer SHALL NOT send a message

### Requirement: Multiline composer state remains coherent
The chat composer SHALL keep text-derived state coherent after keyboard newline insertion.

#### Scenario: Multiline message sends with line breaks
- **WHEN** a web user creates a multiline message using Shift+Enter and then sends it
- **THEN** the sent message text SHALL preserve the inserted line break

#### Scenario: Newline insertion updates composer text state
- **WHEN** a web user inserts a newline through Shift+Enter
- **THEN** composer features that depend on text changes, including send-button enabled state, mention offset tracking, and link preview detection, SHALL be updated consistently with other text insertions

#### Scenario: Clearing multiline text restores visible empty state
- **WHEN** a web user creates enough line breaks for the composer to scroll internally and then clears the composer text with keyboard deletion or select-all deletion
- **THEN** the composer SHALL show the empty input state without requiring the user to manually scroll inside the field

### Requirement: Mobile composer behavior remains unchanged
The mobile chat composer SHALL continue to rely on multiline text input behavior for newline entry.

#### Scenario: Mobile newline behavior is preserved
- **WHEN** a mobile user uses the platform keyboard newline action in the chat composer
- **THEN** the composer SHALL continue to support multiline input according to the existing mobile behavior
