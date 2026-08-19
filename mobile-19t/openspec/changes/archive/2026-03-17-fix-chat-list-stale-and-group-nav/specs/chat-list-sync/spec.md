## chat-list-sync

Remove stale local conversations that no longer exist on the server after each successful API refresh.

### Requirements

1. `ChatDao` must expose a method `deleteConversationsNotIn(Set<String> ids)` that deletes all rows from `local_conversations` where `id` is NOT in the provided set.

2. `ChatListNotifier._refreshFromApi()` must, after successfully upserting conversations from the API:
   - Collect the set of conversation IDs from the API response
   - Call `dao.deleteConversationsNotIn(remoteIds)` to remove stale entries
   - Only perform the delete when the API response contains at least one conversation (guard against empty responses from transient errors)

3. The delete must happen AFTER the upsert, so that the local DB first gets updated data, then stale entries are removed.

4. On API error (catch block), no deletion should occur — the existing local data is preserved as-is.

### Acceptance Criteria

- Given: conversation C exists locally but was deleted on the server
- When: `_refreshFromApi()` completes successfully
- Then: conversation C is no longer in the local DB and does not appear in the chat list

- Given: API returns an empty list (transient error or genuinely no conversations)
- When: `_refreshFromApi()` processes the response
- Then: local conversations are NOT deleted (guard against empty response)

### Files

- `apps/mobile/lib/core/database/chat_dao.dart` — add `deleteConversationsNotIn` method
- `apps/mobile/lib/features/chat/providers/chat_providers.dart` — update `_refreshFromApi()` in `ChatListNotifier`
