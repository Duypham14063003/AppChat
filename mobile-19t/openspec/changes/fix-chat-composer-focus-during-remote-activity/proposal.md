## Why

Users can lose the ability to compose a chat message when another participant is typing or sends a message in the same conversation. Remote realtime activity should update the chat timeline and typing indicator without stealing focus, disabling input, or making the composer appear stuck.

## What Changes

- Preserve composer focus and draft text while remote typing indicators appear, update, and disappear.
- Preserve composer focus and draft text while remote messages arrive and the message list updates.
- Prevent parent chat-screen dismissal handlers from treating composer interactions as outside taps during remote layout changes.
- Keep send, reply, edit, attachment, emoji, mention, and multiline composer behavior stable.
- Add focused regression coverage for composer focus and typing continuity during remote activity.

## Capabilities

### New Capabilities
- `chat-composer-focus-stability`: Covers chat composer focus, draft, and input continuity while remote typing and message events update the conversation UI.

### Modified Capabilities
- None.

## Impact

- Affected code:
  - `apps/mobile/lib/features/chat/screens/chat_screen.dart`
  - `apps/mobile/lib/features/chat/widgets/message_input_bar.dart`
  - chat widget/helper tests under `apps/mobile/test/features/chat/`
- No backend, API, WebSocket payload, persistence, or notification contract changes.
- No new runtime dependencies are expected.
