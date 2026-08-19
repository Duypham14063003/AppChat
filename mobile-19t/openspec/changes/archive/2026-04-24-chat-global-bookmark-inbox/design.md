## Context

The existing `chat-message-bookmark` change introduced private per-user bookmarks with conversation-scoped REST APIs, local Drift persistence, and a bookmark list that can only be opened from inside a chat screen. In the mobile app today, bookmarked retrieval is still anchored to one conversation: `ChatScreen` shows a bookmark count in the app bar, opens `BookmarkedMessagesListScreen`, and returns a `messageId` so the current chat can scroll to the source message.

That is enough for message-level saving, but it does not satisfy the "saved messages inbox" pattern shown in the target UI. Users want to enter from the chat list, browse all of their saved items in one place, then open the originating conversation and land on the bookmarked message with highlight feedback. The codebase already has two important building blocks we can reuse:

- Chat conversations are cached locally in `LocalConversations`, including display metadata such as type, group name/avatar, and direct-message peer info.
- Chat navigation already supports `/chat/:id?messageId=:messageId`, and `ChatScreen` can resolve older-history jumps and highlight the target once it is loaded.

The change therefore expands bookmark retrieval scope without changing bookmark ownership semantics: bookmarks remain private, REST-driven, and invisible to other participants.

## Goals / Non-Goals

**Goals:**
- Provide a global bookmark inbox API for the authenticated user across all accessible conversations.
- Add a mobile entry point from the chat list to a dedicated saved-messages screen.
- Let the saved-messages screen show bookmark items ordered by `marked_at DESC` with enough message and conversation context to browse effectively.
- Support a simple top-level filter model for `all`, `direct`, and `group` saved items.
- Reuse existing chat deep-link and highlight behavior so tapping a saved item opens the correct conversation and jumps to the source message.
- Keep current conversation-scoped bookmark actions and list behavior working as-is.

**Non-Goals:**
- Replacing the existing conversation-scoped bookmark list.
- Adding freeform notes, labels, folders, or bulk actions for bookmarks.
- Broadcasting bookmark changes through WebSocket events or system messages.
- Adding full-text search inside the global saved-messages inbox in this change.

## Decisions

### D1: Reuse the existing `message_bookmarks` table and add a global read path

**Decision:** Keep bookmark storage in the existing per-user `message_bookmarks` table and add a global listing query instead of introducing a second bookmark table or a materialized inbox table.

**Why:** The storage model already captures the right ownership semantics (`user_id`, `conv_id`, `message_id`, `marked_at`). The new need is retrieval shape, not a new ownership model. Reusing the current table avoids migration churn and keeps bookmark mutation behavior unchanged.

**Alternatives considered:**
- Add a dedicated "saved inbox" table. Rejected because it duplicates bookmark state and creates synchronization risk.
- Denormalize bookmarks onto `messages`. Rejected because bookmarks are user-specific, not message-global.

### D2: Add a user-scoped global bookmark endpoint

**Decision:** Introduce a user-scoped global read endpoint such as `GET /users/me/bookmarks` with `limit`, `cursor`, and optional `conv_type` filter.

**Why:** Global bookmark retrieval is no longer conversation-owned. A user-scoped route communicates that clearly, avoids awkward fake conversation context, and fits the privacy model better than extending `/conversations/:id/bookmarks`.

**Alternatives considered:**
- Reuse `GET /conversations/:id/bookmarks` repeatedly from mobile and merge results client-side. Rejected because it creates N+1 network requests and cannot paginate a unified inbox correctly.
- Add a generic `/bookmarks` route without user scoping. Rejected because the acting user is always implicit and `/users/me/bookmarks` is clearer.

### D3: Return a flattened bookmark item with conversation metadata

**Decision:** The global endpoint returns flattened items containing bookmark metadata, source message preview data, and enough conversation display data to render the inbox without additional per-item fetches.

**Why:** The saved-messages screen needs to render items from mixed conversation types. Returning only `conv_id` and `message_id` would force extra lookups or rely too heavily on local cache completeness. A flattened response keeps the screen responsive and removes N+1 fetch pressure.

**Alternatives considered:**
- Return only bookmark IDs and let mobile join everything locally. Rejected because it depends on local caches always being fresh.
- Return nested full conversation/message payloads. Rejected because it is heavier than the UI needs and complicates API evolution.

### D4: Keep mobile cache additive and compose global items from bookmark + conversation cache

**Decision:** Do not replace the existing conversation-scoped bookmark cache. Instead, add a global mobile provider that reads cached bookmark rows across all conversations, joins them with `LocalConversations` display metadata when needed, and refreshes from the new global endpoint.

**Why:** The current Drift schema already stores bookmark rows by `convId` and message. A global provider can reuse that data model while adding a DAO query for cross-conversation ordering. This keeps per-conversation bookmark consumers stable and lets the global inbox layer evolve independently.

**Alternatives considered:**
- Add a second local table just for global inbox rows. Rejected because it duplicates bookmark state and doubles invalidation work.
- Expand the bookmark table immediately with conversation display columns. Rejected for now because `LocalConversations` already contains the needed metadata and avoids another migration unless later proven necessary.

### D5: Use chat-list app bar entry + existing deep-link route for navigation

**Decision:** Add a saved-messages icon to `ChatListScreen` and navigate from the global inbox into `/chat/:convId?messageId=:messageId`.

**Why:** The target experience begins from the chat list, not from within a conversation. The route format already exists and `ChatScreen` already handles initial target jump and historical pagination, so reusing it is lower risk than inventing a custom callback-based return flow.

**Alternatives considered:**
- Keep the only entry point inside `ChatScreen`. Rejected because it does not satisfy the saved-inbox mental model.
- Open the conversation first and then pass target state through in-memory arguments only. Rejected because it bypasses existing route behavior and is harder to restore consistently.

### D6: Support a minimal filter model in v1

**Decision:** The global inbox screen supports `all`, `direct`, and `group` filters, with `all` as the default state shown in the UI.

**Why:** The desired UI shows an "All" dropdown, and conversation type is the simplest stable filter dimension already present in cached and server data. This keeps v1 aligned with the target layout without introducing per-conversation grouping or search complexity.

**Alternatives considered:**
- No filter in v1. Rejected because it diverges from the requested interaction model.
- Dynamic per-conversation filters. Rejected because it expands UI state and pagination semantics more than needed for the first release.

## Risks / Trade-offs

- **[Risk] Global and conversation-scoped bookmark providers can drift after mutations** → Mitigation: invalidate or refresh both scopes after bookmark create/delete actions.
- **[Risk] Local conversation metadata may be stale when rendering cached global bookmarks** → Mitigation: prefer fresh server payload after refresh and continue syncing `LocalConversations` through existing chat list flows.
- **[Risk] Pagination combined with filters can produce inconsistent client merging if cursors are reused across filter states** → Mitigation: scope cursors to the active filter and reset pagination whenever the filter changes.
- **[Risk] Large bookmark counts could make an unpaginated inbox expensive** → Mitigation: require paginated backend reads from the first version and implement explicit "load more" behavior.

## Migration Plan

1. Add the global bookmark listing endpoint and supporting DTO/query/service logic on the backend.
2. Add mobile repository/provider/DAO support for cross-conversation bookmark reads while keeping existing conversation-scoped providers intact.
3. Add the saved-messages screen, chat-list entry point, and navigation wiring into `ChatScreen` using the existing `messageId` route parameter.
4. Validate bookmark mutations still refresh both the conversation-scoped and global inbox views.

**Rollback:** The change is additive. If the global inbox UI must be rolled back, keep the existing bookmark mutation and conversation-scoped retrieval flow intact while removing the new endpoint usage and chat-list entry point.

## Open Questions

None. This change assumes the first inbox filter model is `all / direct / group` and defers inbox search to a later change.
