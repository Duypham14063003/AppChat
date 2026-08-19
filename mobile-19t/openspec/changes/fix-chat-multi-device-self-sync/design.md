## Context

Chat message send currently goes through `ChatGateway.handleSendMessage()`, `ChatService.sendMessage()`, and Redis-backed fan-out in `RedisPubSubService`. The backend tracks websocket connections per `userId`, allowing one account to have multiple active sockets across phone, desktop, and other sessions. However, the conversation fan-out path currently skips `new_message` delivery for the sender by comparing `member.user_id === senderId`, which suppresses delivery to every active socket owned by the sender.

The mobile chat client already handles two separate send paths correctly for the origin device: it inserts an optimistic local message immediately, then converges through `message_ack`, `message_status`, and persisted message reloads. The missing behavior is realtime delivery to the sender's *other* devices, which do not have optimistic local state and therefore stay stale until a manual refresh or API sync occurs.

This change must preserve the current websocket contract, Redis pubsub topology, optimistic send behavior, and room-level `new_message` handling. The goal is to narrow duplicate suppression from "skip the sender user" to "skip only the exact socket that originated the send" for realtime events where self-echo is undesirable.

## Goals / Non-Goals

**Goals:**
- Deliver `new_message` events to the sender's other active sockets for the same account.
- Continue suppressing redundant `new_message` fan-out to the exact websocket that initiated the send.
- Preserve existing realtime behavior for all other conversation members.
- Keep the current optimistic-send and ACK/status flow unchanged for the sending device.
- Add verification coverage for multi-device sender sync across concurrent sessions.

**Non-Goals:**
- Redesigning chat transport, room synchronization, or websocket authentication.
- Changing message persistence, ordering, or idempotent insert semantics.
- Altering typing-indicator behavior unless required to keep socket-level duplicate suppression consistent.
- Introducing a new device registry or session-specific datastore outside the current connection manager.

## Decisions

### D1: Duplicate suppression SHALL be scoped to the originating socket, not the sender user

**Decision:** Realtime fan-out will stop skipping `new_message` events by `senderId` alone. Instead, it will compare each target socket with the exact websocket instance that initiated the send and suppress self-echo only for that socket.

**Why:** Connections are stored per `userId`, so a user-level skip unintentionally excludes every concurrent device owned by the sender. Socket-level suppression preserves the original intent of avoiding duplicate self-insert on the origin device without breaking same-account multi-device sync.

**Alternatives considered:**
- Remove sender suppression entirely. Rejected because the origin socket already has optimistic local state and would receive a redundant `new_message`, increasing duplicate-handling complexity.
- Keep user-level skip and rely on manual/API sync for the sender's other devices. Rejected because it preserves the current bug and delays visible consistency.

### D2: The existing websocket object is the authoritative origin identifier

**Decision:** The backend will use the websocket instance already available in the send flow as the authoritative origin marker for duplicate suppression rather than introducing a new device ID concept.

**Why:** `ChatGateway.handleSendMessage()` already passes the sender socket through the send path, and `ConnectionManager` already exposes the active sockets per user. Reusing the existing websocket instance keeps the fix small and avoids new client/server contracts.

**Alternatives considered:**
- Add a client-provided device ID to message sends. Rejected because it expands the public protocol and adds new trust/validation requirements for a problem already solvable with current server state.
- Store per-send temporary socket IDs in Redis payloads. Rejected because local process memory already has the required socket identity at fan-out time.

### D3: `new_message` behavior changes, but optimistic-send convergence remains the same

**Decision:** The origin device will continue to rely on optimistic local insert plus ACK/status updates. Secondary devices owned by the same user will rely on normal `new_message` processing and local persistence, just like any other conversation member.

**Why:** The client already distinguishes these two paths cleanly. Changing only the server fan-out behavior minimizes client risk while delivering the missing cross-device synchronization.

**Alternatives considered:**
- Add special client-side reconciliation for same-user messages on secondary devices. Rejected because those devices can already consume `new_message` events normally once the backend fan-out is corrected.

### D4: Verification must cover concurrent same-user sessions explicitly

**Decision:** Automated coverage will assert that a sender's secondary active session receives `new_message`, while the origin socket does not receive a duplicate self-echo beyond its existing ACK/status path.

**Why:** The regression vector is subtle: realtime delivery already works for other users, so tests must explicitly model multiple sockets for the same `userId` to prove the fix.

**Alternatives considered:**
- Rely only on manual cross-device testing. Rejected because this bug is easy to reintroduce during future realtime changes.

## Risks / Trade-offs

- [Risk] Socket-level comparison could be applied inconsistently across event types. -> Mitigation: scope the change explicitly to events where self-echo suppression is intentional and document behavior in tests.
- [Risk] The origin device may receive both optimistic local state and `new_message` if socket identity is not preserved through fan-out. -> Mitigation: keep the exact websocket instance threaded through the current send path and validate origin-socket suppression in tests.
- [Risk] Multi-process or Redis-backed fan-out paths may obscure origin identity if implementation assumes only user-level context. -> Mitigation: keep suppression logic at the local socket fan-out boundary where the connection manager still has concrete socket instances.
- [Risk] Secondary sender devices may surface ordering issues if they receive `new_message` before list refresh state catches up. -> Mitigation: preserve existing `new_message` upsert flow, which already handles inbound message persistence and UI reload.

## Migration Plan

1. Update backend conversation fan-out to compare against the originating websocket instead of suppressing all sockets owned by `senderId`.
2. Preserve the current origin-device send path of optimistic local insert followed by `message_ack` and `message_status`.
3. Add automated coverage for two active sockets on the same `userId`, validating that only the non-origin socket receives `new_message`.
4. Manually verify sending from phone updates desktop for the same account, and sending from desktop updates phone, without duplicate bubbles on the origin device.

Rollback: restore the previous sender-level suppression logic if the change causes duplicate self-echo on the originating device, then re-evaluate socket identity handling before reattempting.

## Open Questions

None. The required behavior is clear: same-account secondary devices must receive realtime message updates, while the exact sending socket remains protected from redundant self-echo.
