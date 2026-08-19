## Why

The mobile chat client currently treats `GET /conversations/:convId/messages/:messageId/seen-by` as a snapshot API and reuses stale Riverpod state without any realtime invalidation. As a result, seen-by avatars and seen-by detail sheets can lag behind actual read activity and appear cached while a conversation is open.

## What Changes

- Add mobile-side realtime refresh for message seen-by state while a conversation is open.
- Invalidate and rebuild seen-by state when read-receipt websocket activity changes who has read up to which message.
- Keep seen-by rendering fetch-on-demand for detail views, but ensure visible message-level seen markers are refreshed from current backend state instead of stale cached provider results.
- Scope seen-by placement so each member appears only on the newest message they have read up to, excluding the currently signed-in account from the displayed avatar row.

## Capabilities

### New Capabilities
- `chat-message-seen-by-realtime-ui`: Realtime mobile behavior for message seen-by indicators and detail views backed by the existing seen-by API and websocket read-receipt events.

### Modified Capabilities
- None.

## Impact

- Affected mobile chat state management in `apps/mobile/lib/features/chat/providers/chat_providers.dart`.
- Affected mobile chat screen rendering in `apps/mobile/lib/features/chat/screens/chat_screen.dart` and `apps/mobile/lib/features/chat/widgets/message_item.dart`.
- Affected websocket event handling in `apps/mobile/lib/core/network/websocket_manager.dart` consumers.
- No new backend API is introduced in this change; the mobile app continues using the existing seen-by endpoint and read-receipt websocket flow.
