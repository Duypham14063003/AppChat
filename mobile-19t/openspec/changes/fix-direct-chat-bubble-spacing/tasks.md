## 1. Bubble Layout Fix

- [ ] 1.1 Update incoming bubble layout logic in `message_bubble.dart` to reserve avatar/sender gutter space only when the chat UI explicitly enables that chrome
- [ ] 1.2 Keep group-chat incoming bubble alignment behavior unchanged while removing empty gutter spacing from direct-message bubbles

## 2. Alignment Verification

- [ ] 2.1 Verify forwarded headers, quoted replies, timestamps, and reaction rows remain aligned with the corrected direct-message bubble edge
- [ ] 2.2 Manually verify incoming direct chats and incoming group chats in the Flutter messaging UI to confirm spacing is correct in both modes
