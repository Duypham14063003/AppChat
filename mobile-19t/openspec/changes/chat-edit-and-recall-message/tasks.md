## 1. Backend message mutation contract

- [x] 1.1 Add backend DTOs, controller routes, and service methods for editing and recalling a chat message with sender-only validation.
- [x] 1.2 Update chat message serialization, history queries, and sync responses so edited messages expose `edited_at` and recalled messages remain in results as tombstones.
- [x] 1.3 Publish realtime events for successful message edit and recall mutations and cover permission/error cases with backend tests where the module already uses them.

## 2. Mobile data and synchronization

- [x] 2.1 Extend the mobile chat repository and websocket manager with edit/recall mutation calls and event bindings.
- [x] 2.2 Update chat providers and DAO write paths so local messages can be updated in place for edited and recalled state instead of being removed from the visible timeline.
- [x] 2.3 Reconcile history refresh and reconnect sync flows so edited/recalled messages resolve to the same local shape as realtime updates.
- [x] 2.4 Update denormalized conversation-list preview state when the latest message is edited or recalled, including same-device and realtime-triggered flows.

## 3. Mobile chat UX

- [x] 3.1 Add `Sửa` and `Thu hồi` actions to the message context menu with sender-only availability rules.
- [x] 3.2 Implement composer edit mode with prefilled text, save, and cancel behavior for eligible text messages.
- [x] 3.3 Update message bubble and reply-preview rendering to show edited state and recalled-message placeholders consistently.

## 4. Verification

- [x] 4.1 Add mobile tests for context-menu action visibility, composer edit mode transitions, and edited/recalled timeline rendering.
- [x] 4.2 Add mobile coverage for conversation-list preview updates after latest-message edit and recall events.
- [ ] 4.3 Manually verify edit and recall flows in direct and group conversations, including realtime updates across multiple sessions, refresh/reconnect behavior, and conversation-list preview synchronization.
