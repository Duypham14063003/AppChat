## Why

Users currently cannot reliably copy their own chat messages in some cases, even though the same copy action is available for other messages. This breaks a basic message interaction and is especially confusing when the message is visible on screen but the copy option is missing or copies empty content.

This needs to be fixed now because the chat UI can render resolved text for self-sent messages while the copy action still depends on the raw stored `message.content` field. In encrypted or resolved-content flows, that raw field may be empty even though the visible message text is available to the user.

## What Changes

- Make chat message copy behavior depend on the text currently available to the user, not only on the raw persisted message content field.
- Ensure the copy action remains available for self-sent text messages when their visible text was resolved from encrypted or transformed message state.
- Keep recalled messages and non-copyable message types excluded from copy actions.
- Add focused coverage for copying self-sent messages whose displayed text differs from the raw stored payload.

## Capabilities

### New Capabilities
- `chat-copy-visible-message-text`: Allows chat users to copy the visible text of eligible messages, including self-sent messages whose display text is resolved from encrypted or transformed state.

### Modified Capabilities
<!-- No existing capability requirements are being modified. -->

## Impact

- Chat action menu rendering in `apps/mobile/lib/features/chat/widgets/message_context_menu.dart`
- Chat message action handling in `apps/mobile/lib/features/chat/screens/chat_screen.dart`
- Chat message UI resolution logic in `apps/mobile/lib/features/chat/providers/chat_providers.dart`
- Mobile chat widget and provider tests covering copy eligibility and copied text selection
