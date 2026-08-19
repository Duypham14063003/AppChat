## 1. Preview Data Path

- [x] 1.1 Add a read-only conversation preview provider/helper that loads recent messages without using `chatMessagesProvider`.
- [x] 1.2 Ensure preview loading never calls `markConversationViewed`, never resets unread counters, never sets `activeChatConversationIdProvider`, and never sends websocket `mark_read`.
- [x] 1.3 Preserve cache-first behavior and optionally refresh recent server messages without changing read state.

## 2. Preview UI

- [x] 2.1 Add a conversation peek preview widget/surface with header, recent message list, close action, and explicit "Open chat" action.
- [x] 2.2 Use a bottom sheet on narrow screens and a dialog/popover-style surface on wide screens.
- [x] 2.3 Render text, system, deleted, and non-text message previews safely without exposing full composer actions.

## 3. Chat List Integration

- [x] 3.1 Add long-press handling to `ConversationTile` and wire it from `ChatListScreen`.
- [x] 3.2 Keep single tap behavior unchanged so full chat entry still uses existing read-sync.
- [x] 3.3 Ensure opening the full chat from the preview uses existing navigation and intentionally marks the conversation read.

## 4. Verification

- [x] 4.1 Add unit/widget tests for helper decisions around preview versus full entry read-state behavior.
- [x] 4.2 Add widget coverage for long-press opening the preview and "Open chat" navigation.
- [ ] 4.3 Manually verify that long-press preview keeps unread badges visible after dismissing the preview.
- [ ] 4.4 Manually verify that tapping the conversation or pressing "Open chat" still clears unread through existing read-sync.
