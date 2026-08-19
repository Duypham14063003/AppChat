## Why

When users type a draft in one chat room and switch to another room, the composer can keep showing the previous room's unsent text. This leaks draft context across conversations and makes the chat experience feel unreliable.

The issue should be fixed now because the current chat screen already reuses room widgets during navigation changes, and composer state needs to remain scoped to the active conversation.

## What Changes

- Reset composer draft state when the active chat conversation changes.
- Ensure unsent text, mention state, link preview state, emoji state, and related transient composer UI do not carry over to a different room.
- Preserve existing send, reply, edit, attachment, and typing behaviors within the same conversation.
- Add regression coverage for switching between conversations after entering a draft.

## Capabilities

### New Capabilities
- `chat-composer-room-switch-reset`: The chat composer keeps transient draft state isolated to the active conversation and clears it when the user enters a different room.

### Modified Capabilities
- None.

## Impact

- Affected code:
  - `apps/mobile/lib/features/chat/screens/chat_screen.dart`
  - `apps/mobile/lib/features/chat/widgets/message_input_bar.dart`
  - `apps/mobile/test/features/chat/`
- No backend, API, database, or websocket contract changes.
- No new runtime dependencies are expected.
