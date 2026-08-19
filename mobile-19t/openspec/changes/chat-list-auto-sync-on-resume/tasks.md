## 1. Resume-Driven Chat List Sync

- [x] 1.1 Add a chat-list refresh trigger when the mobile app returns to the foreground
- [x] 1.2 Keep the resume-driven refresh scoped so it updates chat list state without causing unnecessary global invalidation

## 2. Inbound Message Reconciliation

- [x] 2.1 Ensure chat-list websocket preview handling updates local list state immediately for new messages
- [x] 2.2 Add reconciliation behavior so chat list refreshes when preview-only local updates are not enough to reflect the latest server state

## 3. Verification

- [x] 3.1 Add mobile tests for resume-driven chat-list refresh and inbound-message list freshness where feasible
- [ ] 3.2 Manually verify that after backgrounding the app and receiving a new message, returning to the app shows the latest conversation preview without pull-to-refresh or opening the conversation first
