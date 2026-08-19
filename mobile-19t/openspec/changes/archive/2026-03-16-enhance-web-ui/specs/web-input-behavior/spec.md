## ADDED Requirements

### Requirement: Enter key sends message on web platform
On web (`kIsWeb == true`), pressing Enter without Shift in the `MessageInputBar` TextField SHALL send the message (equivalent to tapping the send button). Pressing Shift+Enter SHALL insert a newline. On non-web platforms, the existing behavior (Enter always inserts newline, send via button) SHALL be preserved.

#### Scenario: Enter sends on web
- **GIVEN** the app is running on web and the user has typed text in the message input
- **WHEN** the user presses Enter (without Shift)
- **THEN** the message is sent and the input field is cleared

#### Scenario: Shift+Enter inserts newline on web
- **GIVEN** the app is running on web and the user has typed text in the message input
- **WHEN** the user presses Shift+Enter
- **THEN** a newline is inserted in the text field and the message is NOT sent

#### Scenario: Enter inserts newline on mobile
- **GIVEN** the app is running on a mobile platform (not web)
- **WHEN** the user presses Enter in the message input
- **THEN** a newline is inserted (existing behavior unchanged)

#### Scenario: Empty input ignores Enter on web
- **GIVEN** the app is running on web and the message input is empty or whitespace-only
- **WHEN** the user presses Enter
- **THEN** nothing happens (no empty message sent)

### Requirement: Focus returns to input after sending on web
On web, after a message is sent via Enter key, the `TextField` SHALL retain focus so the user can immediately continue typing.

#### Scenario: Focus retained after Enter-send
- **GIVEN** the app is running on web
- **WHEN** the user sends a message by pressing Enter
- **THEN** the TextField retains focus and the cursor is in the input field
