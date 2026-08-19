# Typing State Management

## Overview

Manages typing state on client side. Listens for WebSocket "typing" events, updates state map with user IDs and timestamps, runs cleanup timer to remove stale entries (>5 seconds old).

## Requirements

### Functional

- **TSM-001**: System listens for WebSocket "typing" events
- **TSM-002**: System stores typing users in Map<userId, timestamp>
- **TSM-003**: System updates timestamp when receiving typing event for existing user
- **TSM-004**: System filters out current user's ID (don't show own typing)
- **TSM-005**: System runs cleanup timer every 1 second
- **TSM-006**: System removes users with timestamp >5 seconds old
- **TSM-007**: System triggers UI rebuild when typing state changes
- **TSM-008**: System unsubscribes from typing events on dispose
- **TSM-009**: System cancels cleanup timer on dispose

### Non-Functional

- **TSM-NFR-001**: Cleanup timer runs every 1 second (low overhead)
- **TSM-NFR-002**: State updates trigger UI rebuild within 16ms (60fps)
- **TSM-NFR-003**: Memory usage is minimal (Map with <10 entries typically)

## User Flow

```
ChatScreen initializes
    ↓
Subscribe to WebSocket "typing" event
    ↓
Start cleanup timer (periodic, 1 second)
    ↓
[Typing event received]
    ↓
Extract user_id, conv_id, timestamp
    ↓
[conv_id != current conversation] → Ignore
[user_id == current user] → Ignore
[Valid] → Update typingUsers[user_id] = timestamp
    ↓
Trigger UI rebuild
    ↓
[Cleanup timer fires every 1 second]
    ↓
Check each user in typingUsers
    ↓
[now - timestamp > 5000ms] → Remove user
    ↓
[Any removed] → Trigger UI rebuild
    ↓
[ChatScreen disposed]
    ↓
Unsubscribe from typing event
    ↓
Cancel cleanup timer
```

## Technical Details

### Flutter Implementation

**Location**: `apps/mobile/lib/features/chat/screens/chat_screen.dart`

**State additions**:
```dart
class _ChatScreenState extends ConsumerState<ChatScreen> {
  final Map<String, int> _typingUsers = {};
  Timer? _typingCleanupTimer;
  
  // Existing state...
}
```

**initState additions**:
```dart
@override
void initState() {
  super.initState();
  
  // Existing initialization...
  
  // Subscribe to typing events
  final wsManager = ref.read(webSocketManagerProvider);
  wsManager.on('typing', _handleTyping);
  
  // Start cleanup timer
  _typingCleanupTimer = Timer.periodic(
    Duration(seconds: 1),
    (_) => _cleanupTypingUsers(),
  );
}
```

**Typing event handler**:
```dart
void _handleTyping(Map<String, dynamic> data) {
  final userId = data['user_id'] as String?;
  final convId = data['conv_id'] as String?;
  final timestamp = data['timestamp'] as int?;
  
  if (userId == null || convId == null || timestamp == null) return;
  
  // Ignore if not for current conversation
  if (convId != widget.conversationId) return;
  
  // Ignore own typing
  final authState = ref.read(authNotifierProvider);
  if (userId == authState.valueOrNull?.user?.id) return;
  
  setState(() {
    _typingUsers[userId] = timestamp;
  });
}
```

**Cleanup method**:
```dart
void _cleanupTypingUsers() {
  final now = DateTime.now().millisecondsSinceEpoch;
  final toRemove = <String>[];
  
  _typingUsers.forEach((userId, timestamp) {
    if (now - timestamp > 5000) {
      toRemove.add(userId);
    }
  });
  
  if (toRemove.isNotEmpty) {
    setState(() {
      toRemove.forEach(_typingUsers.remove);
    });
  }
}
```

**dispose additions**:
```dart
@override
void dispose() {
  // Unsubscribe from typing events
  final wsManager = ref.read(webSocketManagerProvider);
  wsManager.off('typing', _handleTyping);
  
  // Cancel cleanup timer
  _typingCleanupTimer?.cancel();
  
  // Existing dispose...
  super.dispose();
}
```

**UI integration** (in build method, before MessageInputBar):
```dart
if (_typingUsers.isNotEmpty)
  TypingIndicator(
    typingUserIds: _typingUsers.keys.toList(),
    isGroup: conv?.type == 'GROUP',
    currentUserId: authState.valueOrNull?.user?.id,
  ),
```

## Testing

### Unit Tests

- Test _handleTyping() updates typingUsers map
- Test _handleTyping() ignores wrong conversation
- Test _handleTyping() ignores current user
- Test _cleanupTypingUsers() removes stale entries
- Test _cleanupTypingUsers() keeps recent entries
- Test cleanup timer runs every 1 second

### Widget Tests

- Test typing state updates trigger UI rebuild
- Test TypingIndicator appears when typingUsers not empty
- Test TypingIndicator hidden when typingUsers empty

### Integration Tests

- Test full flow: receive typing event → update state → display indicator
- Test cleanup: receive event → wait 6 seconds → indicator disappears
- Test multiple users: receive events from 3 users → all displayed

## Acceptance Criteria

- [ ] WebSocket "typing" events received and processed
- [ ] Typing users stored in Map<userId, timestamp>
- [ ] Current user's typing events ignored
- [ ] Wrong conversation's typing events ignored
- [ ] Cleanup timer runs every 1 second
- [ ] Users with timestamp >5 seconds removed
- [ ] UI rebuilds when typing state changes
- [ ] Cleanup timer cancelled on dispose
- [ ] WebSocket handler unsubscribed on dispose

