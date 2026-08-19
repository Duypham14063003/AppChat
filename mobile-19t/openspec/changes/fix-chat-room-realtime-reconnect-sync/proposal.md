## Why

Mobile chat rooms can stop updating in real time while the user is actively viewing a conversation. In that state, newly sent messages only appear after leaving and reopening the room, which breaks trust in chat delivery and makes the room feel disconnected even when the screen is still open.

This needs to be fixed now because the current room experience depends too heavily on a healthy websocket session without a strong room-level recovery path. When the socket drops, stalls, or reconnects mid-session, the room can miss inbound events and keep showing optimistic local state without converging quickly.

## What Changes

- Ensure opening a chat room verifies or restores websocket connectivity for authenticated sessions before relying on room-level realtime updates.
- Add deterministic room resynchronization when the websocket reconnects while a chat room is already open.
- Strengthen room-level recovery so missed inbound messages are reconciled without requiring the user to leave and reopen the conversation.
- Tighten outbound message handling so failed websocket dispatch does not silently look like successful realtime delivery.
- Add focused verification coverage for room-open reconnect, reconnect-driven resync, and active-room inbound message recovery.

## Capabilities

### New Capabilities
- `chat-room-realtime-reconnect-sync`: Keeps an actively opened mobile chat room in sync across websocket disconnects, reconnects, and missed realtime events.

### Modified Capabilities
<!-- No existing capability requirements are being modified. -->

## Impact

- Mobile chat room state management in `apps/mobile/lib/features/chat/providers/chat_providers.dart`
- Chat room lifecycle and entry flow in `apps/mobile/lib/features/chat/screens/chat_screen.dart`
- Websocket connection recovery in `apps/mobile/lib/core/network/websocket_manager.dart`
- App-level websocket recovery hooks in `apps/mobile/lib/app.dart`
- Message pending/retry behavior in `apps/mobile/lib/features/chat/data/offline_queue_service.dart`
- Mobile tests covering room-level realtime recovery and reconnect behavior
