## Why

The chat screen already includes a downward floating action button, but it currently appears only after pagination or new-message events increase the message count. Users who simply scroll away from the latest messages do not get a quick way back to the bottom, which makes long conversations feel clumsy and inconsistent with the intended chat behavior.

## What Changes

- Make the chat timeline show the scroll-to-bottom FAB based on scroll position, not only when new items are appended.
- Keep the existing tap behavior that jumps the user back to the latest visible message area at the bottom of the reversed chat list.
- Preserve automatic hiding when the user returns to the bottom of the conversation.
- Add verification coverage for the visibility threshold so the FAB appears before pagination is triggered.

## Capabilities

### New Capabilities
- `chat-scroll-to-bottom-ui`: Floating scroll-to-bottom affordance for the Flutter chat timeline when the user has moved away from the latest messages.

### Modified Capabilities
<!-- No existing base spec requirements are being modified. -->

## Impact

- **Flutter UI**: `apps/mobile/lib/features/chat/screens/chat_screen.dart` visibility logic for the chat FAB.
- **Interaction model**: Scroll-position tracking using `ItemPositionsListener` on the reversed `ScrollablePositionedList`.
- **Testing**: Mobile widget or logic tests for FAB visibility around scroll thresholds and pagination boundaries.
