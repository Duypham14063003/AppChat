## Context

The Flutter chat app uses a cache-first architecture: `ChatListNotifier` loads conversations from the local Drift/SQLite database, then refreshes from the API in the background. The refresh uses `insertConversations()` which is an upsert — it only adds or updates rows, never deletes. The `ChatDao` has an `evictOldData()` method that deletes conversations not viewed in 30 days, but no method to sync-delete based on server state.

The group creation flow navigates using `context.go()` which replaces the entire GoRouter stack. All chat routes live inside a `ShellRoute`, so `context.go('/chat/$id')` clears the shell's child stack.

Current data flow:
- `ChatListNotifier.build()` → `dao.getConversations()` (local) → `_refreshFromApi()` (background)
- `_refreshFromApi()` → `repo.getConversations()` (API) → `dao.insertConversations()` (upsert only) → `state = AsyncData(await dao.getConversations())`
- API `GET /conversations` returns ALL conversations for the user (no pagination cursor used in the initial load)

## Goals / Non-Goals

**Goals:**
- Conversations deleted on the server are removed from the local cache on next refresh
- After creating a group, user can navigate back to the chat list
- After creating a group, the new conversation appears in the chat list immediately

**Non-Goals:**
- Real-time deletion sync via WebSocket events
- Paginated conversation list sync (current API returns all)
- Handling partial API responses (offline/error cases should not delete local data)

## Decisions

### D1: Sync-delete approach
**Decision**: After upserting API conversations, collect the set of remote IDs and delete local conversations whose IDs are not in that set. Only perform the delete when the API call succeeds (not on error).
**Rationale**: Simple and correct for the current non-paginated API. The delete happens in the same `_refreshFromApi()` method, after the upsert, so the local DB always reflects the server state after a successful refresh.
**Risk**: If the API is later changed to paginate, this approach would incorrectly delete conversations not in the current page. Mitigated by: (1) the API currently returns all conversations, (2) if pagination is added, the sync logic must be updated accordingly.

### D2: DAO method design
**Decision**: Add `deleteConversationsNotIn(Set<String> ids)` to `ChatDao`. Uses Drift's `delete` with a `WHERE id NOT IN (...)` clause.
**Rationale**: Clean separation — the DAO handles the SQL, the provider handles the business logic of when to call it.

### D3: Navigation fix
**Decision**: Change `context.go('/chat/$convId')` to `context.pushReplacement('/chat/$convId')` in `GroupCreateNameScreen._createGroup()`.
**Rationale**: `pushReplacement` replaces the current route (group name screen) with the chat screen while preserving the stack below it. The stack becomes `[/chat (list), /chat/$id]`, so back navigation returns to the chat list. This is the same pattern already used in `ContactPickerScreen`.

### D4: Chat list invalidation after group creation
**Decision**: Call `ref.invalidate(chatListProvider)` after successful group creation, before navigating.
**Rationale**: Forces the chat list to rebuild and fetch fresh data from the API, ensuring the new group appears immediately when the user navigates back.

## Risks / Trade-offs

- **[Risk] API returns empty on network error** → If `_refreshFromApi()` gets an empty response due to a transient error, it could delete all local conversations. Mitigated by: the method already has a try-catch that silently fails on error, so the delete step is only reached on successful API response. Additionally, we should guard against empty responses.
- **[Trade-off] No cascade delete of messages** → When a conversation is deleted locally, its messages remain in `local_messages`. This is acceptable because: (1) messages are evicted after 7 days by `evictOldData()`, (2) orphaned messages don't appear in the UI since they're queried by `convId`.
