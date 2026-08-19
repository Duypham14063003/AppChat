## group-create-navigation

Fix navigation after group creation so users can return to the chat list, and ensure the new group appears immediately.

### Requirements

1. In `GroupCreateNameScreen._createGroup()`, change `context.go('/chat/$convId')` to `context.pushReplacement('/chat/$convId')`.
   - This replaces the group name screen with the chat screen while keeping `/chat` (the list) in the back stack.
   - Back navigation from the new chat screen returns to the chat list.

2. After successful group creation (before navigation), invalidate `chatListProvider` so the chat list rebuilds with fresh data when the user navigates back.
   - Use `ref.invalidate(chatListProvider)`.

### Acceptance Criteria

- Given: user is on the group name screen and taps "Tạo nhóm"
- When: group creation succeeds
- Then: user is navigated to the new group's chat screen AND can press back to return to the chat list

- Given: user created a group and navigated back to the chat list
- When: the chat list screen is displayed
- Then: the new group conversation appears in the list without manual pull-to-refresh

### Files

- `apps/mobile/lib/features/chat/screens/group_create_name_screen.dart` — change navigation method and add provider invalidation
