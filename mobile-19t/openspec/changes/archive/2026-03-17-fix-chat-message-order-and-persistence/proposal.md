## Why

The chat feature has two critical bugs discovered during mobile testing:

1. **Message display order is reversed** — newest messages appear at the top of the screen instead of the bottom (Telegram-style). This is caused by a double-reversal bug: the `ListView.builder` uses `reverse: true` but the `itemBuilder` also manually reverses the index (`messages.length - 1 - index`), negating the intended effect. This violates SRS requirement CHAT-FR-031 and design decision D6.

2. **Messages not persisting to server database** — when chatting rapidly, messages stay as `pending` in local Drift cache but never reach PostgreSQL. Root causes: (a) `WebSocketManager._send()` silently drops messages when `_channel` is null, (b) no handling of server-side rate limit rejection (30 msg/min), (c) offline queue only flushes on reconnect, not for messages dropped while "connected", (d) insufficient logging makes these failures invisible.

## What Changes

- Fix double-reversal in `ChatScreen` `ListView.builder` index mapping so newest messages render at the bottom
- Add return value to `WebSocketManager._send()` so callers know if the message was actually sent
- Add WS error/rate-limit event handling in `ChatNotifier` to detect server rejections
- Add periodic retry mechanism for `pending` messages (not just on reconnect)
- Add debug logging for WS state transitions, message send/drop, and connection lifecycle
- Fix offline banner to also show during `connecting` state (not just `disconnected`)

## Capabilities

### New Capabilities

- `chat-ws-reliability`: WebSocket message delivery reliability — send confirmation, error handling, periodic retry for pending messages, and diagnostic logging

### Modified Capabilities

_None — no spec-level requirement changes. The existing SRS requirements (CHAT-FR-001, CHAT-FR-021, CHAT-FR-029, CHAT-FR-031) are correct; the implementation deviates from them._

## Impact

- **Flutter files**: `chat_screen.dart`, `websocket_manager.dart`, `chat_providers.dart`, `offline_queue_service.dart`
- **No backend changes** — server implementation is correct; issues are client-side only
- **No database schema changes**
- **No API changes**
- **Risk**: Low — all changes are in Flutter client code, no shared state or breaking changes
