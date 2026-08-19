## Why

Chat currently updates in real time for other participants when a user sends a message, but the sender's other active devices can remain stale until they manually refresh or reopen the conversation. This breaks cross-device continuity for the same account and makes chat feel unreliable when users switch between phone and desktop.

This needs to be fixed now because the current backend fan-out logic skips realtime message delivery for the sender at the user level instead of only skipping the exact socket that initiated the send. As a result, multi-device sessions for the same user are not kept in sync during normal message sending.

## What Changes

- Change chat realtime fan-out so a newly sent message is still delivered to the sender's other active devices.
- Keep duplicate suppression on the exact sending socket so the device that originated the message does not receive a redundant realtime insert on top of its optimistic local state.
- Preserve current realtime behavior for other conversation members.
- Add focused verification coverage for sender multi-device sync across mobile and desktop sessions.

## Capabilities

### New Capabilities
- `chat-multi-device-self-sync`: Keeps a sender's concurrent devices synchronized in real time when the sender posts a message from one device.

### Modified Capabilities
<!-- No existing capability requirements are being modified. -->

## Impact

- Backend chat realtime fan-out in `backend-mobile-19t/src/modules/chat/services/redis-pubsub.service.ts`
- Backend websocket connection tracking in `backend-mobile-19t/src/modules/chat/services/connection-manager.service.ts`
- Backend chat gateway and message send flow in `backend-mobile-19t/src/modules/chat/chat.gateway.ts` and `backend-mobile-19t/src/modules/chat/services/chat.service.ts`
- Mobile chat realtime state handling in `apps/mobile/lib/features/chat/providers/chat_providers.dart`
- Chat realtime automated coverage for sender multi-device sync
