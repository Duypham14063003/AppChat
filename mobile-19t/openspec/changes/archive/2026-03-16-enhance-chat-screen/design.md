## Context

The ChatScreen currently shows a hardcoded "Chat" title — users cannot identify who they are chatting with. The MessageBubble shows only content and timestamp with no sender identification. The `_refreshFromApi()` method in `ChatListNotifier` never maps `otherMemberName`/`otherMemberAvatar` from the API response despite these fields existing in the Drift table. The ContactPickerScreen uses `context.go()` which destroys the navigation back stack. The backend tracks WebSocket connections in-memory via `ConnectionManager` but never updates `User.last_seen_at` on connect/disconnect.

Current architecture:
- Backend: `ChatGateway` handles WS auth/disconnect, `ConnectionManager` tracks online users in-memory, `User.last_seen_at` only updated on login
- Flutter: `ChatScreen` receives `conversationId` from route, loads messages via `chatMessagesProvider`, no conversation detail loading
- Flutter: `LocalConversation` has `otherMemberName`/`otherMemberAvatar` fields but they are never populated
- API: `GET /conversations` returns `members[].user.{id, name, avatar_url}` via TypeORM joins; `GET /conversations/:id` returns full member info including `last_seen_at`

## Goals / Non-Goals

**Goals:**
- Users can see who they are chatting with (name, avatar) in the ChatScreen AppBar
- Users can see online/last-active status of the conversation partner
- Incoming messages show sender avatar and name
- Navigation back from a newly created conversation works correctly
- Conversation list shows correct member names (fix data mapping bug)

**Non-Goals:**
- Real-time presence push (WS events for online/offline) — using polling/refresh of `last_seen_at` instead
- Group chat header (showing multiple members) — DIRECT only for now
- Typing indicators
- User profile screen on avatar tap

## Decisions

### D1: Conversation detail data source
**Decision**: Create `conversationDetailProvider` that reads from `ChatDao.getConversation(id)` first, falls back to `ChatRepository.getConversation(id)` if not found locally.
**Rationale**: The conversation data is already cached locally by `ChatListNotifier._refreshFromApi()`. For most cases, the local read is sufficient. The API fallback handles edge cases (deep link, push notification tap before list loads).

### D2: Online status approach
**Decision**: Update `User.last_seen_at` on WS connect/disconnect in `ChatGateway`. Flutter reads `last_seen_at` from `GET /conversations/:id` response (which includes `members.user.last_seen_at`). Display "Đang hoạt động" if within 2 minutes, otherwise "Hoạt động X trước".
**Rationale**: Simple, no new WS events needed. The 2-minute threshold accounts for the gap between actual disconnect and `last_seen_at` update. Accurate enough for a <50 employee company.
**Alternative**: Real-time presence via WS events — rejected as over-engineering for this scale. Can be added later.

### D3: Storing last_seen_at locally
**Decision**: Add `otherMemberLastSeenAt` field to `LocalConversations` Drift table. Populate from API response in `_refreshFromApi()` and `conversationDetailProvider`.
**Rationale**: Allows displaying status from cached data without an extra API call. The value may be slightly stale but is refreshed on each conversation list load and when entering a chat.
**Note**: Adding a column to Drift table requires running `build_runner` to regenerate code.

### D4: Navigation fix approach
**Decision**: Change `context.go('/chat/$convId')` to `context.pushReplacement('/chat/$convId')` in ContactPickerScreen.
**Rationale**: `pushReplacement` replaces the current route (`/contacts/pick`) with `/chat/:id` while keeping `/chat` in the stack. This gives the correct back behavior: ChatScreen → back → ChatList.

### D5: MessageBubble sender info
**Decision**: Pass `senderName` and `senderAvatar` as optional parameters to `MessageBubble`. ChatScreen gets these from `conversationDetailProvider`. For DIRECT chats, all non-mine messages use the same sender info (the other member).
**Rationale**: Keeps MessageBubble stateless and reusable. The sender info comes from conversation-level data, not per-message lookup.

## Risks / Trade-offs

- **[Risk] Drift table schema change** → Adding `otherMemberLastSeenAt` column requires `build_runner` regeneration. Mitigated by running codegen as part of implementation.
- **[Risk] last_seen_at staleness** → If the backend crashes without clean disconnect, `last_seen_at` won't be updated. Mitigated by the 2-minute threshold — user will show as "offline" after 2 minutes regardless.
- **[Trade-off] No real-time presence** → Status only updates when conversation detail is fetched. Acceptable for v1; can add WS presence events later.
- **[Trade-off] API call on chat open** → `conversationDetailProvider` may call `GET /conversations/:id` if data isn't cached. This is a single lightweight call and only happens on first open.

