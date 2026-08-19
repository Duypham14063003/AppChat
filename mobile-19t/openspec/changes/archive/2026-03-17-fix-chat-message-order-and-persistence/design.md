## Context

The chat feature (fr-chat-phase1, 91/100 tasks complete) has two client-side bugs found during mobile testing:

1. **Message order bug**: `chat_screen.dart` uses `ListView.builder(reverse: true)` with data sorted `DESC` from Drift DAO. The `itemBuilder` applies an additional index reversal (`messages.length - 1 - index`), causing a double-reversal that puts newest messages at the top instead of the bottom.

2. **Message persistence bug**: Messages sent via WebSocket may never reach the server database. `WebSocketManager._send()` silently returns when `_channel` is null. Server rate-limit rejections (30 msg/min) are not handled. The offline queue only retries on reconnect events, not for messages dropped while the connection appears active.

Current files involved:
- `apps/mobile/lib/features/chat/screens/chat_screen.dart` — ListView rendering
- `apps/mobile/lib/core/network/websocket_manager.dart` — WS transport
- `apps/mobile/lib/features/chat/providers/chat_providers.dart` — state management
- `apps/mobile/lib/features/chat/data/offline_queue_service.dart` — retry queue

## Goals / Non-Goals

**Goals:**
- Newest messages display at the bottom of the chat screen (Telegram-style, per SRS D6)
- Messages that fail to send are retried automatically, not silently dropped
- WS connection state and message delivery failures are visible in debug logs
- Offline banner covers both `disconnected` and `connecting` states

**Non-Goals:**
- Backend changes (server implementation is correct)
- Changing the WS protocol or message format
- Adding message delivery guarantees beyond the existing 5-retry limit
- Refactoring the overall chat architecture

## Decisions

### D1: Fix index mapping, not data sort order

Remove the manual index reversal in `chat_screen.dart:142`. With `reverse: true` and data sorted DESC, `messages[index]` directly maps index 0 to the newest message at the visual bottom.

Alternative considered: Change DAO to sort ASC and remove `reverse: true`. Rejected because `reverse: true` is the standard Flutter chat pattern (handles scroll anchoring and keyboard resize correctly) and matches the SRS design decision D6.

### D2: Make `_send()` return a boolean indicating success

Change `WebSocketManager._send()` to return `bool` — `false` when `_channel` is null or sink write fails. `sendMessage()` propagates this to callers. `ChatNotifier.sendMessage()` uses the return value: if `false`, the message remains `pending` in Drift and will be picked up by the retry mechanism.

Alternative considered: Throw an exception from `_send()`. Rejected because callers already handle the `pending` → retry flow; a boolean is simpler and avoids try/catch boilerplate.

### D3: Add periodic pending-message retry timer

Add a 10-second periodic timer in `OfflineQueueService` that calls `_flushQueue()` when WS is connected. This catches messages that were silently dropped or server-rejected while the connection was active.

The existing reconnect-triggered flush remains. The periodic timer is additive.

### D4: Handle server error events

Register a handler for `send_error` WS events in `ChatNotifier`. When received, log the error and leave the message as `pending` for retry. After max retries (5), mark as `failed` per existing logic.

### D5: Add structured debug logging

Add `debugPrint` calls for: WS state transitions, connect URL, auth success/failure, message send/drop, and retry attempts. All prefixed with `[WS]` for easy filtering in Flutter DevTools.

## Risks / Trade-offs

- **10s retry timer could cause duplicate sends** → Mitigated by server-side `ON CONFLICT (id, created_at) DO NOTHING` idempotency. Client UUID ensures dedup.
- **Periodic timer adds minor battery/CPU overhead** → 10s interval with a simple DB query is negligible. Timer is cancelled on dispose.
- **Changing `_send()` return type is a minor API change** → Only 4 internal callers (`sendMessage`, `sendMarkRead`, `sendMarkDelivered`, auth). Low blast radius.
