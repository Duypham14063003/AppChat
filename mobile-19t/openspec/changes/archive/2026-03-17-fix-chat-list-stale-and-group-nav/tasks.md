## 1. Add deleteConversationsNotIn to ChatDao

- [x] 1.1 In `apps/mobile/lib/core/database/chat_dao.dart`, add method:
  ```dart
  Future<void> deleteConversationsNotIn(Set<String> ids)
  ```
  Implementation: use Drift's `delete(localConversations)..where((t) => t.id.isNotIn(ids))` then `.go()`.

- [x] 1.2 Verify: method compiles, `flutter analyze` passes.

## 2. Update _refreshFromApi to sync-delete stale conversations

- [x] 2.1 In `ChatListNotifier._refreshFromApi()` (`apps/mobile/lib/features/chat/providers/chat_providers.dart`): after `dao.insertConversations(entries)`, collect the set of conversation IDs from the API response (`entries.map((e) => e.id.value).toSet()`). If the set is not empty, call `dao.deleteConversationsNotIn(remoteIds)`.

- [ ] 2.2 Verify: delete a conversation from the server DB → pull-to-refresh on the app → conversation disappears from the list.

## 3. Fix GroupCreateNameScreen navigation

- [x] 3.1 In `GroupCreateNameScreen._createGroup()` (`apps/mobile/lib/features/chat/screens/group_create_name_screen.dart`): change `context.go('/chat/$convId')` to `context.pushReplacement('/chat/$convId')`.

- [x] 3.2 Before the navigation line, add `ref.invalidate(chatListProvider)` to ensure the chat list refreshes when the user navigates back.

- [x] 3.3 Add import for `chatListProvider` if not already imported (it's in `../providers/chat_providers.dart`).

- [ ] 3.4 Verify: create a group → chat screen opens → press back → returns to chat list → new group is visible.

## 4. Verification

- [x] 4.1 Run `flutter analyze` in `apps/mobile` — no errors.
- [ ] 4.2 End-to-end: delete a conversation from DB → refresh chat list → conversation gone.
- [ ] 4.3 End-to-end: create group → back works → group visible in list.
