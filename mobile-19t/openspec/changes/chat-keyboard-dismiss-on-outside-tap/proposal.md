## Why

In the mobile chat screen, the composer `TextField` opens the keyboard as expected, but tapping outside the input does not reliably dismiss focus. The keyboard remains visible and can cover message content or action controls, especially on smaller screens.

This behavior reduces chat readability and feels inconsistent with common messaging UX. Users expect to tap the message area to hide the keyboard and return to reading mode.

## What Changes

- Add consistent outside-tap keyboard dismissal behavior for the chat conversation screen.
- Add drag/scroll dismissal behavior while browsing the message list.
- Ensure composer-adjacent overlays (mention suggestions, emoji panel) do not remain in an inconsistent state after focus is dismissed.
- Keep existing send/edit/reply behavior intact after focus dismissal updates.
- Add focused widget-level and manual verification coverage for keyboard dismissal behavior.

## Capabilities

### New Capabilities
- `chat-keyboard-dismiss`: The chat composer keyboard and related overlays dismiss predictably when the user interacts outside the active input context.

### Modified Capabilities
<!-- No existing capability requirements are being modified. -->

## Impact

- **Chat screen interaction layer**: `apps/mobile/lib/features/chat/screens/chat_screen.dart`
- **Composer focus behavior**: `apps/mobile/lib/features/chat/widgets/message_input_bar.dart`
- **Message-list scroll interaction**: chat message list view behavior
- **Verification**: `apps/mobile/test/features/chat/` widget tests and manual QA scenarios on mobile devices
