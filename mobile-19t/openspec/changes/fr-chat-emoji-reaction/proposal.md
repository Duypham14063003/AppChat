## Why

The chat feature currently has no way for users to react to messages. Emoji reactions (Telegram-style) let users express quick feedback without sending a new message, reducing noise and improving engagement. The `message_reactions` table already exists in PostgreSQL but has zero API surface — this change builds the full stack from backend service through WebSocket events to Flutter UI.

## What Changes

- Migrate `message_reactions` PK from `(message_id, user_id)` to `(message_id, user_id, emoji)` to support multiple reactions per user per message (max 3)
- Add `toggleReaction()` to `ChatService` with insert/delete toggle logic and reaction limit enforcement
- Add `toggle_reaction` WebSocket event (client→server) and `reaction_update` broadcast (server→all members) via Redis PubSub
- Include aggregated reactions in message fetch responses (`getMessages`, `syncMessages`) so reactions sync with messages
- Add `LocalMessageReactions` Drift table in Flutter for offline storage
- Build Flutter UI: long-press reaction picker (6 quick emojis + full picker), double-tap for ❤️, reaction bar below message bubbles, reaction details bottom sheet
- Add animations: scale bounce on picker appear, emoji fly-from-picker-to-bar on selection

## Capabilities

### New Capabilities
- `reaction-backend`: Server-side toggle logic, WebSocket events, reaction aggregation in message responses, migration
- `reaction-flutter-ui`: Flutter UI components — reaction picker overlay, reaction bar, reaction details sheet, double-tap gesture, animations
- `reaction-flutter-state`: Flutter state management — local SQLite table, Riverpod providers, WebSocket event handling, optimistic updates

### Modified Capabilities
<!-- No existing spec-level requirements are changing -->

## Impact

- **Database**: Migration to alter `message_reactions` PK, add index
- **Backend**: `ChatService`, `ChatGateway`, `chat.dto.ts` — new methods and WS event handler
- **Frontend**: New Drift table + codegen, new widgets (`ReactionPicker`, `ReactionBar`, `ReactionDetailsSheet`), modified `ChatScreen` (gesture handling), new providers
- **Dependencies**: `emoji_picker_flutter` Flutter package for full emoji picker
