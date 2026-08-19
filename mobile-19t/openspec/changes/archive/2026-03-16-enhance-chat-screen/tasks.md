## 1. Backend: Update last_seen_at on WebSocket lifecycle

- [x] 1.1 In `ChatGateway.handleAuth()` (`apps/api/src/modules/chat/chat.gateway.ts`): after successful JWT verification and `connectionManager.addConnection()`, update `User.last_seen_at = now()` via UserRepository or direct query. Inject `Repository<User>` into ChatGateway (add to constructor and module imports if needed).
- [x] 1.2 In `ChatGateway.handleDisconnect()`: after `connectionManager.removeConnection(socket)`, check `if (userId && !connectionManager.isOnline(userId))` — if true, update `User.last_seen_at = now()`.
- [ ] 1.3 Verify: connect via WS → check `users.last_seen_at` is updated. Disconnect → check `last_seen_at` updated again.

## 2. Flutter: Fix _refreshFromApi member info mapping

- [x] 2.1 In `ChatListNotifier._refreshFromApi()` (`apps/mobile/lib/features/chat/providers/chat_providers.dart`): extract current user ID from `authNotifierProvider`. For each conversation, extract `members` array from API response. For DIRECT conversations, find the member whose `user.id != currentUserId` and map `otherMemberName` from `user.name` and `otherMemberAvatar` from `user.avatar_url`.
- [x] 2.2 Also extract `otherMemberLastSeenAt` from the other member's `user.last_seen_at` (requires step 3.1 first).
- [ ] 2.3 Verify: after API refresh, `LocalConversation.otherMemberName` and `otherMemberAvatar` are populated. ConversationTile shows correct names.

## 3. Flutter: Add otherMemberLastSeenAt to Drift table

- [x] 3.1 Add `DateTimeColumn get otherMemberLastSeenAt => dateTime().nullable()();` to `LocalConversations` in `apps/mobile/lib/core/database/tables.dart`.
- [x] 3.2 Run `dart run build_runner build --delete-conflicting-outputs` in `apps/mobile` to regenerate Drift code.
- [ ] 3.3 Verify: `LocalConversation` class now has `otherMemberLastSeenAt` field.

## 4. Flutter: Create conversationDetailProvider

- [x] 4.1 In `apps/mobile/lib/features/chat/providers/chat_providers.dart`: create `conversationDetailProvider` as `FutureProvider.family<LocalConversation?, String>`. Logic: read from `ChatDao.getConversation(id)`. If null, fetch from `ChatRepository.getConversation(id)`, parse response, insert into local DB (including `otherMemberName`, `otherMemberAvatar`, `otherMemberLastSeenAt` for DIRECT), then return from local DB.
- [ ] 4.2 Verify: provider returns conversation data for a known conversation ID.

## 5. Flutter: Redesign ChatScreen AppBar

- [x] 5.1 In `ChatScreen.build()` (`apps/mobile/lib/features/chat/screens/chat_screen.dart`): watch `conversationDetailProvider(widget.conversationId)`. Replace hardcoded `AppBar(title: const Text('Chat'))` with a custom AppBar that shows:
  - Leading: back button (default)
  - Title row: CircleAvatar (avatar or initials) + Column(name, online status subtitle)
  - Online status: "Đang hoạt động" if `otherMemberLastSeenAt` is within 2 minutes, else "Hoạt động X phút/giờ trước", else nothing if null
- [x] 5.2 Create a helper function `_formatLastSeen(DateTime? lastSeenAt)` that returns the Vietnamese relative time string.
- [ ] 5.3 Verify: opening a DIRECT conversation shows the other member's name, avatar, and status in the AppBar.

## 6. Flutter: Enhance MessageBubble with sender info

- [x] 6.1 Add optional `senderName` (String?) and `senderAvatar` (String?) parameters to `MessageBubble` constructor in `apps/mobile/lib/features/chat/widgets/message_bubble.dart`.
- [x] 6.2 For incoming messages (`!isMine`): show a Row with a small CircleAvatar (radius 14, avatar or initials) on the left, and the existing bubble on the right. Show `senderName` as a Text widget above the message content inside the bubble (fontSize 12, AppColors.textSecondary).
- [x] 6.3 In `ChatScreen`: pass `senderName` and `senderAvatar` from `conversationDetailProvider` to `MessageBubble` for non-mine messages.
- [ ] 6.4 Verify: incoming messages show avatar and sender name. Own messages remain unchanged.

## 7. Flutter: Fix ContactPickerScreen navigation

- [x] 7.1 In `ContactPickerScreen._onContactTap()` (`apps/mobile/lib/features/chat/screens/contact_picker_screen.dart`): change `context.go('/chat/$convId')` to `context.pushReplacement('/chat/$convId')`.
- [ ] 7.2 Verify: create a new conversation → ChatScreen opens → press back → returns to ChatListScreen (not stuck).

## 8. Verification

- [ ] 8.1 Run `npm run lint` and `npm run build` in `apps/api` — no errors
- [ ] 8.2 Run `flutter analyze` in `apps/mobile` — no errors
- [ ] 8.3 End-to-end: open chat list → see correct names → tap conversation → see AppBar with name/avatar/status → see sender info on incoming messages → back works
- [ ] 8.4 End-to-end: create new conversation from contact picker → ChatScreen opens with correct header → back returns to chat list

