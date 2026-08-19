## 1. Room Entry Realtime Recovery

- [x] 1.1 Trigger authenticated websocket `ensureConnected` when an active `ChatScreen` opens a room with an unavailable realtime session.
- [x] 1.2 Keep room entry non-blocking so cached room messages still render while transport recovery is in progress.

## 2. Reconnect-Driven Room Resynchronization

- [x] 2.1 Detect meaningful websocket transitions back to `connected` while a room is open and trigger room-scoped synchronization for that conversation.
- [x] 2.2 Guard room synchronization so room-open refresh and reconnect refresh remain idempotent and do not create loops or duplicate churn.

## 3. Truthful Outbound Recovery

- [x] 3.1 Keep websocket-dispatch failures for room text sends in deterministic retryable `pending` state and immediately trigger authenticated transport recovery.
- [x] 3.2 Ensure post-reconnect ACK and status handling converges pending room messages to `sent` without requiring the user to leave and reopen the room.

## 4. Verification

- [x] 4.1 Add automated coverage for entering a room while websocket is disconnected and recovering realtime transport without blocking cached rendering.
- [x] 4.2 Add automated coverage for websocket reconnect while a room remains open, including room-scoped synchronization of missed inbound messages.
- [x] 4.3 Add automated or focused integration coverage for outbound dispatch failure preserving pending state until acknowledgement after recovery.
- [ ] 4.4 Manually verify two active clients can exchange messages continuously after reconnect disruptions without leaving and reopening the room.
