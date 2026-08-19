## Context

Text messaging is complete with real-time delivery via WebSocket. The WebSocket gateway already handles auth, message sending, read receipts, and delivery receipts. Redis Pub/Sub is used for fan-out to conversation members. No typing indicator exists yet.

This change implements CHAT-FR-022 (Typing Indicator, P1 SHOULD). It follows Telegram's UX pattern: client-side throttling (3 seconds), automatic timeout (5 seconds), group-aware display, and ephemeral state (no database).

Key constraints: No database persistence (typing is transient), no rate limiting (client throttles), lightweight implementation (minimal server logic), automatic cleanup (timeout-based).

## Goals / Non-Goals

**Goals:**
- Emit typing event from MessageInputBar when user types
- Throttle typing events to max 1 per 3 seconds (client-side)
- Backend handler for "typing" event in ChatGateway
- Publish typing event to Redis Pub/Sub conversation channel
- Fan-out to all conversation members except sender
- Display TypingIndicator widget above MessageInputBar
- Animated dots (3 dots with fade in/out animation)
- Group-aware display: show names (1-3 users) or count (4+ users)
- Automatic cleanup: remove typing users after 5 seconds of inactivity
- Client-side state management: Map<userId, timestamp>
- Cleanup timer runs every 1 second to remove stale entries

**Non-Goals:**
- Database persistence of typing state
- "Stop typing" event (timeout handles this automatically)
- Rate limiting on backend (client throttling is sufficient)
- Typing history or analytics
- Typing indicator in conversation list (only in chat screen)
- Custom typing messages or animations
- Server-side timeout management (client handles cleanup)

## Decisions

### D1: Throttling — Client-side, 3 seconds
**Choice**: Throttle typing events on client side. Max 1 event per 3 seconds per user.
**Rationale**: Reduces server load and network traffic. 3 seconds is fast enough for good UX but slow enough to avoid excessive events. Matches Telegram behavior. Client-side throttling is simpler than server-side rate limiting.
**Implementation**: Use `Timer` in Flutter. Cancel previous timer on each keystroke, start new 3-second timer. Only emit event when timer fires.

### D2: Timeout — 5 seconds, client-side cleanup
**Choice**: Remove typing users from state after 5 seconds of inactivity. Cleanup runs every 1 second on client.
**Rationale**: Prevents stale indicators. 5 seconds is long enough to avoid flicker but short enough to feel responsive. Client-side cleanup is simpler than server-side timeout. Matches Telegram behavior.
**Implementation**: Store timestamp with each typing user. Cleanup timer checks `(now - timestamp) > 5000ms` and removes stale entries.

### D3: State management — Client-side Map
**Choice**: Store typing state in `Map<String, int>` on client (userId → timestamp). No server-side state.
**Rationale**: Typing is ephemeral and doesn't need persistence. Client-side state is simpler and more efficient. Each client manages its own view of who's typing.
**Structure**: `{ "user-id-1": 1234567890, "user-id-2": 1234567895 }`

### D4: Backend handling — Publish-only, no validation
**Choice**: Backend receives typing event, publishes to Redis Pub/Sub, fans out to members. No validation of conversation membership (trust client).
**Rationale**: Typing is low-stakes (no security risk). Validation adds latency. Client already knows conversation membership. Simpler implementation.
**Alternative considered**: Validate user is member of conversation — rejected due to added complexity and latency for minimal benefit.

### D5: No rate limiting on backend
**Choice**: No rate limiting for typing events on backend.
**Rationale**: Client already throttles (max 1 per 3s). Typing events are lightweight (no database writes). Rate limiting adds complexity for minimal benefit. Existing rate limiting (for send_message) doesn't apply to typing.

### D6: Group display logic — Names or count
**Choice**: 
- Direct chat: "typing..." (no name, obvious who)
- Group, 1 user: "Name is typing..."
- Group, 2-3 users: "Name1, Name2 are typing..."
- Group, 4+ users: "N people are typing..."
**Rationale**: Matches Telegram behavior. Names are useful for small groups. Count is cleaner for large groups. Direct chat doesn't need name (only 2 people).

### D7: Animation — 3 dots with fade
**Choice**: Animated dots (3 dots, fade in/out with 0.5s interval, looping).
**Rationale**: Standard typing indicator pattern. Simple to implement with `AnimationController`. Visually indicates activity without being distracting.

### D8: UI placement — Above MessageInputBar
**Choice**: Display TypingIndicator widget above MessageInputBar, below message list.
**Rationale**: Matches Telegram placement. Doesn't obscure messages. Close to input area (contextually relevant). Easy to implement (add to Column in ChatScreen).

### D9: Exclude self from display
**Choice**: Filter out current user's ID from typing indicator display.
**Rationale**: User doesn't need to see their own typing indicator. Prevents confusion in multi-device scenarios. Standard behavior in all messaging apps.

### D10: No "stop typing" event
**Choice**: Don't emit explicit "stop typing" event. Rely on timeout.
**Rationale**: Simpler implementation. Timeout handles all cases (stopped typing, sent message, closed app, network disconnect). No need for explicit stop event.

### D11: Emit on text change, not on send
**Choice**: Emit typing event on TextField onChange, not when message is sent.
**Rationale**: Typing indicator should show while user is typing, not after sending. Timeout will clear indicator after send. Simpler logic.

### D12: WebSocket event structure
**Choice**: 
```json
{
  "event": "typing",
  "data": {
    "conv_id": "conversation-uuid"
  }
}
```
Backend publishes:
```json
{
  "event": "typing",
  "user_id": "user-uuid",
  "conv_id": "conversation-uuid",
  "timestamp": 1234567890
}
```
**Rationale**: Minimal payload. Backend adds user_id and timestamp. Recipients need user_id to display name and timestamp for cleanup.

## Risks / Trade-offs

- **[Typing indicator may lag by up to 3 seconds]** → Throttling means indicator appears 0-3 seconds after user starts typing. Mitigated by: 3 seconds is acceptable for UX, matches Telegram.
- **[Indicator may persist briefly after user stops]** → 5-second timeout means indicator may show for up to 5 seconds after user stops. Mitigated by: 5 seconds is acceptable, prevents flicker from brief pauses.
- **[No validation of conversation membership]** → Malicious user could emit typing events for conversations they're not in. Mitigated by: Low-stakes (no data leak), client already knows membership, can add validation later if needed.
- **[Multiple devices, same user]** → User typing on device A sees own typing on device B. Mitigated by: Filter out current user's ID in display logic.
- **[Network latency]** → Typing events may arrive late on slow networks. Mitigated by: Timeout handles stale indicators, acceptable for non-critical feature.

## Open Questions

- None — all decisions made during exploration phase.

