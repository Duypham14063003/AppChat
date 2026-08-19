## Why

Direct-message bubbles on the receiving side currently render with an unintended left gutter, making personal chat messages look visibly detached from the main conversation edge. This regression hurts visual consistency and makes direct chats feel misaligned compared with group chats and outgoing messages.

## What Changes

- Fix incoming direct-message bubble layout so it no longer reserves avatar gutter space when avatar and sender-name chrome are intentionally hidden.
- Preserve the existing group-chat behavior where incoming messages can align with avatar and sender-name gutters.
- Keep related message UI elements, such as forwarded headers, quoted replies, and reaction rows, visually aligned with the corrected direct-message bubble position.

## Capabilities

### New Capabilities
- `flutter-chat-bubble-layout`: Defines alignment and spacing requirements for incoming and outgoing chat bubbles across direct and group conversations.

### Modified Capabilities
- None.

## Impact

- Affected Flutter chat UI code in `apps/mobile/lib/features/chat/screens/chat_screen.dart` and `apps/mobile/lib/features/chat/widgets/message_bubble.dart`
- Potential follow-on verification for nearby chat UI elements such as reaction bars, forwarded-message headers, and reply previews
- No backend or API contract changes
