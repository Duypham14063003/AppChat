## Why

Users need a private way to save important chat messages for later without turning them into conversation-wide pins. The chat module already supports public pinning, but that behavior is too visible for personal note-taking and does not match the "only I can see this" use case.

## What Changes

- Add a private message bookmark capability backed by the authenticated user, separate from pinned messages.
- Add REST endpoints to create, remove, and list bookmarked messages for a conversation without exposing bookmark state to other members.
- Extend the mobile long-press message context menu with a bookmark/unbookmark action.
- Add mobile state, local cache, and conversation-level UI for browsing the current user's bookmarked messages and jumping back to the original message.
- Optionally surface bookmarked state on individual message bubbles so users can quickly recognize saved messages.

## Capabilities

### New Capabilities
- `message-bookmark-backend`: Private per-user bookmark storage, validation, and REST APIs for bookmarking chat messages.
- `message-bookmark-ui`: Flutter context-menu integration, local bookmark cache, visual bookmark state, and bookmarked message browsing for a conversation.

### Modified Capabilities
<!-- No existing base spec requirements are being modified. -->

## Impact

- **Database**: New PostgreSQL table for per-user message bookmarks and a new Drift table for local bookmark caching.
- **API**: New REST endpoints under `/conversations/:id/bookmarks` for create, delete, and list.
- **Backend modules**: `ConversationController`, `ChatService`, chat DTOs/entities, and module registration.
- **Flutter UI**: `message_context_menu.dart`, `chat_screen.dart`, chat providers/repository, and potentially a bookmarked-messages list screen.
- **Behavioral overlap**: This change complements public pinning by introducing a private alternative rather than changing pin semantics.
