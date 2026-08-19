## Why

On Flutter Web, the chat composer does not insert a line break when the user presses Shift+Enter, even though mobile multiline entry works. This breaks expected desktop chat behavior and makes it difficult to compose multi-line messages from Chrome/web.

## What Changes

- Make the web chat composer explicitly insert a newline when Shift+Enter is pressed.
- Preserve the current desktop behavior where Enter without Shift sends the message.
- Preserve mobile behavior where the keyboard newline action continues to create line breaks.
- Keep paste, mention detection, link preview detection, and send-button behavior coherent after newline insertion.
- Add focused tests for web keyboard behavior and multi-line send content.

## Capabilities

### New Capabilities
- `web-chat-composer-keyboard`: Web chat composer keyboard behavior for Enter-to-send and Shift+Enter newline handling.

### Modified Capabilities
<!-- No existing archived capability requirements are being modified. -->

## Impact

- Mobile Flutter chat composer widget: `apps/mobile/lib/features/chat/widgets/message_input_bar.dart`.
- Chat composer tests: `apps/mobile/test/features/chat/message_input_bar_test.dart` or focused web-keyboard tests.
- No backend, API, database, or notification contract changes.
