## Why

The chat list screen has two bugs and one UX gap:

1. **Stale conversations persist locally**: When conversations are deleted on the server (directly in DB or via API), `ChatListNotifier._refreshFromApi()` only upserts conversations from the API response into the local Drift database. It never removes conversations that no longer exist on the server. This means deleted conversations remain visible indefinitely until the 30-day eviction timer fires.

2. **Group creation navigation broken**: `GroupCreateNameScreen` uses `context.go('/chat/$convId')` after creating a group. `context.go()` replaces the entire navigation stack, so the user lands on the chat screen with no back button to return to the chat list.

3. **New group not visible in chat list**: After creating a group, `chatListProvider` is not invalidated. The new conversation only appears after a manual pull-to-refresh or a WebSocket `new_message` event.

## What Changes

Flutter (Mobile) only — no backend changes needed:

- Add a `deleteConversationsNotIn(Set<String> ids)` method to `ChatDao` that removes local conversations whose IDs are not in the provided set
- Update `ChatListNotifier._refreshFromApi()` to call this method after upserting, passing the set of IDs from the API response
- Change `GroupCreateNameScreen` navigation from `context.go()` to `context.pushReplacement()` so the chat list remains in the back stack
- Invalidate `chatListProvider` after successful group creation in `GroupCreateNameScreen`

## Capabilities

### Modified Capabilities
- `chat-list-sync`: Fix `_refreshFromApi()` to remove stale local conversations not present in the API response
- `group-create-navigation`: Fix navigation after group creation and ensure the new group appears in the chat list

## Impact

- **Flutter**: Modified `ChatDao` (1 new method), modified `ChatListNotifier._refreshFromApi()` (add delete step), modified `GroupCreateNameScreen` (navigation + invalidation)
- **Backend**: No changes
- **Dependencies**: No new dependencies
- **Risk**: Low — the sync delete only removes conversations not returned by the API. If the API paginates and doesn't return all conversations, this could incorrectly delete valid ones. However, the current `getConversations()` API does not paginate (returns all), so this is safe.
