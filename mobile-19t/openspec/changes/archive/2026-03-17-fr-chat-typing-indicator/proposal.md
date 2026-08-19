## Why

Text messaging (CHAT-FR-001) is complete and working well. Users can send and receive messages in real-time. However, there's no indication when someone is typing a response. This creates uncertainty — users don't know if the other person is composing a reply or has left the conversation.

Typing indicator (CHAT-FR-022, P1 SHOULD) enhances the messaging experience by showing when someone is actively typing. This provides immediate feedback, makes conversations feel more alive, and reduces uncertainty about whether the other person is engaged.

The feature follows Telegram's UX pattern: throttled typing events (max 1 per 3 seconds), automatic timeout (5 seconds of inactivity), group-aware display (show names or count), and ephemeral state (no database persistence).

## What Changes

Frontend (Flutter):
- Add typing event throttling in `MessageInputBar` — emit WebSocket event max once per 3 seconds
- Add `sendTyping()` method to `WebSocketManager`
- Create `TypingIndicator` widget with animated dots
- Update `ChatScreen` to listen for typing events and manage typing state
- Implement cleanup timer (runs every 1 second) to remove stale typing users (>5 seconds old)
- Display typing indicator above `MessageInputBar`
- Group-aware display: "typing..." (direct), "Name is typing..." (group, 1 user), "Name1, Name2 are typing..." (group, 2-3 users), "N people are typing..." (group, 4+ users)

Backend (NestJS):
- Add `typing` event handler in `ChatGateway`
- Validate user is authenticated (already done by gateway)
- Publish typing event to Redis Pub/Sub conversation channel
- Fan-out to all conversation members except sender
- No database persistence (ephemeral state only)
- No rate limiting (client already throttles)

## Capabilities

### New Capabilities
- `typing-emission`: Throttled typing event emission from MessageInputBar (3-second throttle)
- `typing-display`: TypingIndicator widget with animated dots and group-aware text
- `typing-state-management`: Client-side typing state with automatic cleanup (5-second timeout)

### Modified Capabilities
- `websocket-events`: Extend ChatGateway to handle "typing" event
- `flutter-chat-ui`: Update ChatScreen to display typing indicator

## Impact

- **Database**: No changes — typing state is ephemeral, not persisted
- **API endpoints**: No new endpoints — uses existing WebSocket connection
- **Packages (Flutter)**: None (use built-in Timer and animation)
- **Packages (API)**: None (use existing Redis Pub/Sub)
- **Redis**: Pub/Sub only (no persistence, no caching)
- **Performance**: Minimal impact — throttled events (max 1 per 3s per user), lightweight payloads, no database writes
- **WebSocket traffic**: ~0.33 events/second per active typer (throttled to 1 per 3s)

