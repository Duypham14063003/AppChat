## 1. Conversation Entry Synchronization

- [x] 1.1 Audit the current `ChatScreen` and `chatMessagesProvider` entry lifecycle, then add a conversation-scoped refresh path that runs when a user opens or re-enters a conversation.
- [x] 1.2 Update message-loading logic so the conversation detail view resolves from the refreshed durable message store instead of relying only on stale in-memory provider state.
- [x] 1.3 Verify that inbound websocket messages remain persisted idempotently and become visible immediately after opening the affected conversation.

## 2. Read-State Reconciliation

- [x] 2.1 Refine unread reset handling so opening a conversation clears local unread and unread-mention state responsively without letting stale refreshes reintroduce incorrect counters.
- [x] 2.2 Add a reconciliation step after `mark_read` so conversation-list state converges with authoritative conversation data.
- [x] 2.3 Ensure list preview, unread badges, and detail messages stay aligned for both “conversation opened after new message” and “conversation already open during new message” flows.

## 3. Verification

- [x] 3.1 Add or update targeted tests and/or debugable verification hooks for message sync and unread-state transitions in the mobile chat flow.
- [x] 3.2 Run project-appropriate analysis and tests for the affected chat files and confirm the two reported regressions are covered.

## 4. Follow-up Regression Hardening (Unread Badge Suppression)

- [x] 4.1 Remove or narrowly scope global timestamp-based force-read overrides so inactive conversations keep server-authoritative unread counters.
- [x] 4.2 Ensure read-clearing logic applies only to the actively viewed conversation with a valid read checkpoint.
- [x] 4.3 Update inbound `new_message` list handling so unread signal is preserved for inactive conversations until read reconciliation completes.
- [x] 4.4 Add tests for: (a) server unread counters not being forced to zero by local heuristic, and (b) unread badge visibility after inbound messages on inactive conversations.
- [ ] 4.5 Manually verify unread badge behavior when (a) a new message arrives in an inactive conversation, (b) user reads then leaves a conversation, and (c) app resumes/reconnects with mixed local/server timestamps.
