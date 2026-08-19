## Context

The mobile chat room is already built around a cache-first room model: `ChatNotifier` loads conversation messages from Drift, binds websocket listeners for room-level events, and refreshes room state from the API when the room opens. The room also supports optimistic sends, retry-safe pending text replay, and websocket-based reconciliation via `new_message`, `message_ack`, `message_status`, and `sync_response`.

Despite those pieces, users can still hit a high-friction failure mode: while actively viewing a room, cross-device messages stop appearing in real time until they leave and reopen the conversation. That symptom strongly suggests the room is depending on a websocket session that can be disconnected, stalled, or mid-reconnect without a strong room-scoped recovery path. The current app does recover websocket state on app resume and notification tap, but conversation entry itself does not explicitly guarantee transport recovery before depending on room-level realtime listeners.

This change needs to preserve the current websocket transport, local-cache-first rendering, and offline queue architecture. The goal is not to redesign chat transport, but to make the currently opened room self-healing when websocket health drifts during an active session.

## Goals / Non-Goals

**Goals:**
- Ensure opening a chat room verifies or restores websocket connectivity for authenticated sessions.
- Ensure an already-open room deterministically resynchronizes after websocket reconnect so missed inbound messages become visible without leaving the room.
- Ensure outbound text sends that fail websocket dispatch are clearly treated as pending realtime recovery, not silently assumed to be delivered.
- Keep local Drift-backed room rendering, optimistic sends, and existing websocket contracts intact.
- Add focused verification for room-open reconnect, reconnect-driven room resync, and active-room realtime recovery.

**Non-Goals:**
- Replacing websocket transport with SSE, polling, or a new backend protocol.
- Redesigning chat list synchronization; this change is room-scoped.
- Changing media upload architecture beyond whatever room recovery touches indirectly.
- Reworking the entire offline queue model or introducing a new global chat state system.
- Guaranteeing delivery while the app process is fully dead; this scope is about active-session room correctness.

## Decisions

### D1: Treat chat room entry as an authenticated websocket recovery point

**Decision:** When `ChatScreen` becomes active for a conversation, the mobile client will explicitly verify websocket connectivity through the existing manager instead of assuming the app-level lifecycle already recovered it.

**Why:** Users can enter a room from ordinary in-app navigation while the websocket is disconnected or stuck. Room-level realtime cannot be trusted unless transport health is checked at room entry.

**Alternatives considered:**
- Only rely on app resume and notification-tap recovery. Rejected because ordinary room entry can still happen with a stale websocket session.
- Always block room rendering until websocket is connected. Rejected because cached messages should still render immediately and the user should not wait on transport handshake to open the room.

### D2: Treat websocket reconnection as a deterministic room resync trigger

**Decision:** If websocket state transitions back to `connected` while a room is open, the room will trigger a fresh conversation synchronization path using the same room-scoped source of truth used on entry.

**Why:** A reconnect alone does not guarantee that missed `new_message` events are replayed into the room state. An explicit room resync removes the need for the user to leave and re-enter the room to see missed messages.

**Alternatives considered:**
- Depend only on websocket `sync_response` opportunistically. Rejected because the room should not assume replay timing is sufficient or always visible through current UI state.
- Invalidate all chat providers on reconnect. Rejected because the bug is room-scoped and broad invalidation adds noise and extra churn.

### D3: Keep Drift as the visible room source of truth, but require reconvergence after reconnect

**Decision:** The room UI will continue rendering from local Drift-backed message state, while reconnect and room-open recovery paths must refresh that persisted state before the room settles.

**Why:** The current architecture already depends on Drift for room rendering, pagination, search, offline queue, and optimistic send state. Keeping Drift as the durable source of truth avoids introducing a second rendering model.

**Alternatives considered:**
- Render reconnect recovery directly from raw API responses in memory. Rejected because that would diverge from existing room architecture and complicate pagination/search consistency.

### D4: Outbound dispatch failure shall be treated as transport recovery, not silent success

**Decision:** When a room send cannot be dispatched to websocket immediately, the client will keep the optimistic message in a deterministic pending state and actively attempt transport recovery rather than letting the message appear indistinguishable from healthy realtime flow.

**Why:** The current UX can mislead users into believing cross-device realtime worked because the local optimistic bubble appears immediately. The room must surface transport truth through message state and recovery behavior.

**Alternatives considered:**
- Leave behavior as pending-only with background retry. Rejected because it does not actively repair the realtime session and contributes to the “message appears only after reload” symptom.
- Remove optimistic sends entirely. Rejected because that would degrade responsiveness and is unnecessary for this fix.

### D5: Keep room recovery scoped to active-room context

**Decision:** Reconnect-driven room resync and websocket recovery behavior will be scoped to the currently visible room instead of globally forcing every conversation provider to refresh.

**Why:** The observed bug is that the active room becomes stale. Scoping recovery to the visible room keeps behavior predictable and limits unnecessary traffic or state churn across unrelated conversations.

**Alternatives considered:**
- Global refresh of all rooms/messages on reconnect. Rejected because it is broad, expensive, and unnecessary to restore the visible room correctly.

## Risks / Trade-offs

- [Risk] Room entry and websocket reconnect can trigger duplicate refresh work. -> Mitigation: keep room synchronization idempotent and guard against overlapping in-flight room sync operations.
- [Risk] Extra room sync after reconnect may increase API traffic during unstable network periods. -> Mitigation: scope reconnect resync to the active room only and reuse existing room synchronization paths.
- [Risk] Optimistic messages may remain visible longer in pending state during reconnect. -> Mitigation: make recovery deterministic and keep ACK/status transitions authoritative once transport returns.
- [Risk] Websocket state transitions may fire frequently on flaky networks. -> Mitigation: react only to meaningful `connected` transitions and avoid repeated room refresh loops while already synchronizing.
- [Risk] Room-scoped recovery could still miss bugs that live purely in backend websocket fanout. -> Mitigation: verify both reconnect-driven resync and healthy-session inbound updates in tests and manual cross-device validation.

## Migration Plan

1. Add a room-scoped websocket recovery hook that runs when `ChatScreen` becomes active for an authenticated session.
2. Add reconnect-aware room synchronization so an active room refreshes its message source of truth when websocket returns to `connected`.
3. Tighten outbound text send failure handling so failed dispatch triggers transport recovery while preserving retryable pending state.
4. Add focused tests for room-open recovery, reconnect-driven room resync, and cross-device realtime recovery expectations.
5. Manually verify that two active clients can exchange messages continuously without leaving and reopening the room after reconnect disruptions.

Rollback: remove the room-entry websocket recovery and reconnect-triggered room resync hooks, returning to the prior room-open-only synchronization model if regressions appear.

## Open Questions

None. The current requirement is clear: an actively opened mobile chat room must recover realtime correctness without forcing the user to leave and reopen the conversation.
