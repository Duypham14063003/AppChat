## Why

Chat message navigation currently succeeds only when the target message is already present in the loaded timeline window. As a result, tapping a pinned, bookmarked, replied-to, or deep-linked older message can fail with "Tin nhắn không trong phạm vi hiển thị" even though the message still exists in conversation history.

## What Changes

- Add a shared chat message jump flow that attempts to load older history before declaring that a target message is unavailable.
- Use the shared flow for pinned-message taps, bookmarked-message taps, reply navigation, and `initialMessageId` deep-link handling.
- Show clear loading and failure behavior while the app searches older pages for the requested message.
- Add verification coverage for successful historical jumps and exhausted-history failure handling.

## Capabilities

### New Capabilities
- `chat-message-jump-navigation-ui`: Reliable navigation to older in-conversation messages by progressively loading history until the target message is found or history is exhausted.

### Modified Capabilities
<!-- No existing capability requirements are being modified. -->

## Impact

- **Flutter chat UI**: `apps/mobile/lib/features/chat/screens/chat_screen.dart`
- **Pinned and bookmarked entry points**: `apps/mobile/lib/features/chat/widgets/pinned_message_bar.dart`, `apps/mobile/lib/features/chat/screens/pinned_messages_screen.dart`, `apps/mobile/lib/features/chat/screens/bookmarked_messages_screen.dart`
- **Chat timeline loading**: `apps/mobile/lib/features/chat/providers/chat_providers.dart`
- **Verification**: mobile tests for jump-to-old-message behavior
