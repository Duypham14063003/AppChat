## Why

The ChatScreen currently shows a hardcoded "Chat" title in the AppBar with no indication of who the user is chatting with. There is no avatar, no name, and no online status. The MessageBubble widget only shows message content and timestamp — no sender identification for incoming messages. Additionally, `_refreshFromApi()` in `ChatListNotifier` never populates `otherMemberName` or `otherMemberAvatar` from the API response, so even the conversation list may show "Unknown" for DIRECT conversations. Finally, creating a new conversation from ContactPickerScreen uses `context.go()` which replaces the entire navigation stack, making it impossible to navigate back to the chat list.

## What Changes

Backend (NestJS):
- Update `ChatGateway.handleAuth()` to set `last_seen_at = now()` on the User entity when a WebSocket connection is authenticated
- Update `ChatGateway.handleDisconnect()` to set `last_seen_at = now()` when the user's last WebSocket connection closes

Flutter (Mobile):
- Fix `_refreshFromApi()` in `ChatListNotifier` to extract `otherMemberName` and `otherMemberAvatar` from the API response's `members` array
- Create a `conversationDetailProvider` that loads conversation info from local DB (with API fallback)
- Redesign `ChatScreen` AppBar: show other member's avatar, name, and online/last-seen status
- Enhance `MessageBubble` to show sender avatar and name for incoming messages (non-mine)
- Fix `ContactPickerScreen` navigation: change `context.go()` to `context.pushReplacement()` so the chat list remains in the back stack

## Capabilities

### New Capabilities
- `chat-screen-header`: Custom AppBar for ChatScreen showing conversation partner info (avatar, name, online status) for DIRECT conversations
- `message-bubble-sender`: Enhanced MessageBubble showing sender avatar and name for incoming messages
- `presence-status`: Backend updates `last_seen_at` on WebSocket connect/disconnect; Flutter displays online/last-seen status

### Modified Capabilities
- `chat-navigation-fix`: Fix navigation stack issue when creating new conversations, and fix `_refreshFromApi` to populate member info

## Impact

- **Backend**: Minor changes to `ChatGateway` (2 methods) to update `last_seen_at`. No new endpoints, no migrations, no new entities.
- **Flutter**: New `conversationDetailProvider`, modified `ChatScreen` (AppBar), modified `MessageBubble` (sender info), modified `chat_providers.dart` (`_refreshFromApi` mapping), modified `contact_picker_screen.dart` (navigation fix)
- **Dependencies**: No new dependencies needed

