# Typing Emission

## Overview

Emits WebSocket "typing" events when user types in MessageInputBar. Throttles events to max 1 per 3 seconds to reduce server load. Handles backend WebSocket event processing and Redis Pub/Sub fan-out.

## Requirements

### Functional

- **TE-001**: System emits "typing" event when user types in TextField
- **TE-002**: System throttles typing events to max 1 per 3 seconds
- **TE-003**: System cancels previous throttle timer on each keystroke
- **TE-004**: System does NOT emit typing event when TextField is empty
- **TE-005**: Backend receives "typing" event via WebSocket
- **TE-006**: Backend validates user is authenticated
- **TE-007**: Backend publishes typing event to Redis Pub/Sub conversation channel
- **TE-008**: Backend fans out typing event to all conversation members except sender
- **TE-009**: Backend does NOT persist typing event to database
- **TE-010**: Backend does NOT rate limit typing events

### Non-Functional

- **TE-NFR-001**: Typing event emission has max 3-second delay (throttle period)
- **TE-NFR-002**: Backend processes typing event within 10ms
- **TE-NFR-003**: Typing event payload is minimal (<100 bytes)

## User Flow

```
User types in MessageInputBar
    ↓
TextField onChange triggered
    ↓
Cancel previous throttle timer
    ↓
[Text is empty] → Don't emit, return
[Text is not empty] → Start new throttle timer (3 seconds)
    ↓
[User continues typing] → Cancel timer, restart
[Timer fires after 3 seconds] → Emit typing event
    ↓
WebSocket: { event: "typing", data: { conv_id: "xxx" } }
    ↓
Backend receives event
    ↓
Validate user is authenticated
    ↓
Publish to Redis Pub/Sub: conversation:xxx
    ↓
Fan-out to all members except sender
    ↓
Recipients receive: { event: "typing", user_id: "yyy", conv_id: "xxx", timestamp: 123 }
```

## Technical Details

### Flutter Implementation

**Location**: `apps/mobile/lib/features/chat/widgets/message_input_bar.dart`

**State additions**:
```dart
class _MessageInputBarState extends State<MessageInputBar> {
  Timer? _typingThrottleTimer;
  
  // Existing state...
}
```

**TextField onChange update**:
```dart
void _onTextChanged(String text) {
  setState(() => _hasText = text.trim().isNotEmpty);
  
  // Typing indicator throttle
  _typingThrottleTimer?.cancel();
  
  if (text.trim().isNotEmpty) {
    _typingThrottleTimer = Timer(Duration(seconds: 3), () {
      widget.onTyping?.call();
    });
  }
}
```

**Callback parameter**:
```dart
class MessageInputBar extends StatefulWidget {
  final void Function(String text) onSend;
  final void Function(List<XFile> images)? onAttachImages;
  final VoidCallback? onTyping; // NEW
  
  const MessageInputBar({
    super.key,
    required this.onSend,
    this.onAttachImages,
    this.onTyping, // NEW
  });
}
```

**Dispose**:
```dart
@override
void dispose() {
  _typingThrottleTimer?.cancel();
  _controller.dispose();
  _focusNode.dispose();
  super.dispose();
}
```

**Location**: `apps/mobile/lib/core/network/websocket_manager.dart`

**Add method**:
```dart
bool sendTyping(String convId) {
  return _send('typing', {'conv_id': convId});
}
```

**Location**: `apps/mobile/lib/features/chat/screens/chat_screen.dart`

**Pass callback to MessageInputBar**:
```dart
MessageInputBar(
  onSend: (text) => _sendMessage(text),
  onAttachImages: (images) => _onAttachImages(images),
  onTyping: () {
    final wsManager = ref.read(webSocketManagerProvider);
    wsManager.sendTyping(widget.conversationId);
  },
)
```

### Backend Implementation

**Location**: `apps/api/src/modules/chat/chat.gateway.ts`

**Add case in handleRawMessage()**:
```typescript
switch (envelope.event) {
  case 'send_message':
    await this.handleSendMessage(socket, userId, envelope);
    break;
  case 'mark_read':
    await this.handleMarkRead(userId, envelope);
    break;
  case 'mark_delivered':
    await this.handleMarkDelivered(userId, envelope);
    break;
  case 'sync':
    await this.handleSync(socket, userId, envelope);
    break;
  case 'typing': // NEW
    await this.handleTyping(userId, envelope);
    break;
  default:
    this.sendEvent(
      socket,
      'error',
      {
        code: 'UNKNOWN_EVENT',
        message: `Unknown event: ${envelope.event}`,
      },
      envelope.id,
    );
}
```

**Add handler method**:
```typescript
private async handleTyping(
  userId: string,
  envelope: WsEnvelope,
): Promise<void> {
  const convId = envelope.data?.conv_id as string;
  if (!convId) {
    this.logger.warn(`Typing event missing conv_id from user ${userId}`);
    return;
  }

  // Publish to Redis Pub/Sub
  await this.redisPubSub.publishToConversation(convId, {
    event: 'typing',
    user_id: userId,
    conv_id: convId,
    timestamp: Date.now(),
  });
}
```

**Note**: No validation of conversation membership. Trust client. No database write. No rate limiting.

## Testing

### Frontend Unit Tests

- Test throttle timer cancels on each keystroke
- Test typing event emitted after 3 seconds
- Test no event emitted when text is empty
- Test timer cancelled on dispose

### Frontend Widget Tests

- Test TextField onChange triggers throttle
- Test onTyping callback called after 3 seconds
- Test no callback when text cleared

### Backend Unit Tests

- Test handleTyping() publishes to Redis Pub/Sub
- Test handleTyping() includes user_id, conv_id, timestamp
- Test handleTyping() handles missing conv_id gracefully

### Backend Integration Tests

- Test WebSocket "typing" event received and published
- Test typing event fans out to conversation members
- Test sender does not receive own typing event

## Acceptance Criteria

- [ ] Typing event emitted when user types
- [ ] Typing events throttled to max 1 per 3 seconds
- [ ] No event emitted when TextField is empty
- [ ] Throttle timer cancelled on each keystroke
- [ ] Throttle timer cancelled on dispose
- [ ] Backend receives and processes typing event
- [ ] Backend publishes to Redis Pub/Sub
- [ ] Backend fans out to all members except sender
- [ ] No database persistence
- [ ] No rate limiting on backend

