## Context

The chat stack already supports message reactions, forwarding, reply state, and public pinned messages. The long-press bottom sheet exists on mobile and currently exposes actions such as pin, reply, copy, and forward. Public pins are stored server-side per conversation and intentionally produce shared effects such as system messages and visible pin state for all members.

Private message bookmarks are different. They belong to a single authenticated user, should not create shared conversation noise, and should still sync across that user's devices. The implementation touches the chat backend, REST controller, Flutter repository/provider flow, and Drift persistence, but does not need WebSocket fan-out because no other participant needs the state.

## Goals / Non-Goals

**Goals:**
- Let a user bookmark or unbookmark any non-system message they can access in a conversation.
- Persist bookmarks on the backend per user so the same user sees them across devices.
- Expose bookmark and unbookmark actions in the existing mobile message context menu.
- Provide a conversation-scoped list of bookmarked messages with tap-to-jump behavior.
- Cache bookmark state locally in Drift so the chat UI can render quickly and stay coherent offline between refreshes.

**Non-Goals:**
- Replacing or redefining public pinned-message behavior.
- Broadcasting bookmark state to other users through WebSocket or system messages.
- Adding freeform note text attached to a bookmarked message.
- Building a global cross-conversation bookmark inbox in this change.

## Decisions

### D1: Use a dedicated per-user bookmark table

**Decision:** Store bookmarks in a new `message_bookmarks` table keyed by `user_id`, `conv_id`, and `message_id`.

**Why:** Bookmark state is private and user-scoped, so it should not live on `messages` or reuse `pinned_messages`. A dedicated table keeps ownership clear, supports efficient listing by conversation, and avoids mixing private state with shared message state.

**Alternatives considered:**
- Reuse `pinned_messages` with a visibility flag. Rejected because the semantics and permission model are different.
- Add a bookmark flag directly to `messages`. Rejected because bookmarks are per user, not per message globally.

### D2: REST-only synchronization

**Decision:** Use REST APIs for bookmark create/delete/list and do not add a new WebSocket event.

**Why:** Bookmarks are only relevant to the current user, so real-time multi-user fan-out has no value. REST gives simpler validation, predictable error handling, and keeps this feature aligned with other private per-session fetch flows.

**Alternatives considered:**
- Add a private WebSocket event for bookmark updates. Rejected because it adds event complexity without improving the core use case.

### D3: Keep bookmark UI inside the existing long-press context menu

**Decision:** Add a bookmark action to the current message bottom sheet rather than inventing a separate gesture or toolbar.

**Why:** The action is message-scoped, naturally grouped with pin/reply/copy/forward, and fits the user's requested interaction. This minimizes UX surprise and implementation spread.

**Alternatives considered:**
- Add a swipe gesture for bookmarking. Rejected because swipe is already associated with reply and would be easy to trigger accidentally.
- Put bookmark only in a top app bar action. Rejected because the action belongs to an individual message.

### D4: Conversation-scoped bookmark list for retrieval

**Decision:** Add a bookmarked-messages list screen or sheet scoped to the current conversation, with tap-to-scroll back into chat.

**Why:** Bookmarking is only useful if retrieval is easy. A conversation-scoped list is a smaller, lower-risk first step than a global saved-messages feature and reuses existing scroll-to-message behavior already present for search and pinned messages.

**Alternatives considered:**
- Only show a bookmark icon on bubbles and no retrieval list. Rejected because users would have to manually scroll entire histories to find saved content.
- Build a global bookmark hub immediately. Rejected because it expands navigation and cross-conversation search scope too early.

### D5: Cache bookmark state locally in Drift

**Decision:** Add a `LocalBookmarkedMessages` Drift table and a Riverpod provider that loads cached state first, then refreshes from the API.

**Why:** This matches the app's chat architecture, keeps bookmark indicators responsive, and enables the context menu and bookmark list to reflect known state before the network round-trip finishes.

**Alternatives considered:**
- Keep bookmark state in memory only. Rejected because it would disappear on restart and feel inconsistent across screens.
- Fetch fresh bookmark state on every menu open without cache. Rejected because it would add latency to a high-frequency interaction.

## Risks / Trade-offs

- [Risk] Bookmark state can become stale across multiple devices because there is no WebSocket sync. → Mitigation: refresh bookmarks on chat screen entry, after every create/delete mutation, and when opening the bookmark list.
- [Risk] New per-conversation API calls can add extra startup work to chat screens. → Mitigation: use cached Drift data first and keep bookmark payloads lightweight.
- [Risk] Users may confuse bookmark with pin if the UI labels are too similar. → Mitigation: use explicit Vietnamese copy that emphasizes private visibility, such as "Đánh dấu tin nhắn" and "Bỏ đánh dấu".
- [Risk] Partitioned message storage may complicate validation joins. → Mitigation: follow the existing chat-service pattern of verifying the message by `id` plus `conv_id` before inserting bookmark rows.

## Migration Plan

1. Add the backend migration and entity for `message_bookmarks`.
2. Release REST endpoints and service logic without changing existing pin behavior.
3. Add the Drift schema migration and mobile repository/provider wiring.
4. Enable the context-menu action and bookmarked-message retrieval UI.
5. Validate create/delete/list behavior on one device and multi-device sync for the same user account.

**Rollback:** If the UI rollout must be reverted, the backend endpoints and table can remain unused safely. If the backend migration itself must be rolled back, remove mobile calls first, then revert the migration.

## Open Questions

None. The initial change will stay conversation-scoped and bookmark state will remain private to the authenticated user.
