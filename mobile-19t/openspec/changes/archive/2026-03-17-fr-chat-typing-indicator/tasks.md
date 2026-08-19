# Implementation Tasks

## Phase 1: Backend Implementation

### Task 1.1: Add typing event handler
- [x] Open `apps/api/src/modules/chat/chat.gateway.ts`
- [x] Add `case 'typing':` in `handleRawMessage()` switch statement
- [x] Call `await this.handleTyping(userId, envelope);`

### Task 1.2: Implement handleTyping method
- [x] Add `handleTyping()` private method in `ChatGateway`
- [x] Extract `conv_id` from `envelope.data`
- [x] Validate `conv_id` is not null/undefined
- [x] Call `redisPubSub.publishToConversation()` with typing event
- [x] Include `event: 'typing'`, `user_id`, `conv_id`, `timestamp: Date.now()`
- [x] Add error logging if publish fails

## Phase 2: Flutter - WebSocket Manager

### Task 2.1: Add sendTyping method
- [x] Open `apps/mobile/lib/core/network/websocket_manager.dart`
- [x] Add `sendTyping(String convId)` method
- [x] Call `_send('typing', {'conv_id': convId})`
- [x] Return boolean (success/failure)

## Phase 3: Flutter - Typing Emission

### Task 3.1: Update MessageInputBar state
- [x] Open `apps/mobile/lib/features/chat/widgets/message_input_bar.dart`
- [x] Add state variable: `Timer? _typingThrottleTimer`

### Task 3.2: Add onTyping callback parameter
- [x] Add `final VoidCallback? onTyping;` to `MessageInputBar` widget
- [x] Add to constructor parameters
- [x] Update const constructor

### Task 3.3: Update _onTextChanged method
- [x] Cancel previous throttle timer: `_typingThrottleTimer?.cancel()`
- [x] Check if text is not empty
- [x] Start new timer: `Timer(Duration(seconds: 3), () => widget.onTyping?.call())`
- [x] Assign to `_typingThrottleTimer`

### Task 3.4: Update dispose method
- [x] Cancel throttle timer: `_typingThrottleTimer?.cancel()`

## Phase 4: Flutter - Typing State Management

### Task 4.1: Update ChatScreen state
- [x] Open `apps/mobile/lib/features/chat/screens/chat_screen.dart`
- [x] Add state variable: `final Map<String, int> _typingUsers = {}`
- [x] Add state variable: `Timer? _typingCleanupTimer`

### Task 4.2: Subscribe to typing events in initState
- [x] Get `webSocketManagerProvider`
- [x] Call `wsManager.on('typing', _handleTyping)`
- [x] Start cleanup timer: `Timer.periodic(Duration(seconds: 1), (_) => _cleanupTypingUsers())`
- [x] Assign to `_typingCleanupTimer`

### Task 4.3: Implement _handleTyping method
- [x] Extract `user_id`, `conv_id`, `timestamp` from data
- [x] Validate all fields are not null
- [x] Check if `conv_id` matches current conversation
- [x] Get current user ID from `authNotifierProvider`
- [x] Check if `user_id` is not current user
- [x] Update `_typingUsers[userId] = timestamp`
- [x] Call `setState()`

### Task 4.4: Implement _cleanupTypingUsers method
- [x] Get current timestamp: `DateTime.now().millisecondsSinceEpoch`
- [x] Create list: `final toRemove = <String>[]`
- [x] Iterate `_typingUsers.forEach((userId, timestamp) { ... })`
- [x] Check if `now - timestamp > 5000`
- [x] Add to `toRemove` list
- [x] If `toRemove.isNotEmpty`, call `setState()` and remove users

### Task 4.5: Update dispose method
- [x] Get `webSocketManagerProvider`
- [x] Call `wsManager.off('typing', _handleTyping)`
- [x] Cancel cleanup timer: `_typingCleanupTimer?.cancel()`

### Task 4.6: Pass onTyping callback to MessageInputBar
- [x] In `build()` method, find `MessageInputBar` widget
- [x] Add `onTyping: () { wsManager.sendTyping(widget.conversationId); }`

## Phase 5: Flutter - Typing Display

### Task 5.1: Create TypingIndicator widget
- [x] Create `apps/mobile/lib/features/chat/widgets/typing_indicator.dart`
- [x] Define `TypingIndicator` StatefulWidget
- [x] Add parameters: `typingUserIds`, `isGroup`, `currentUserId`
- [x] Create `_TypingIndicatorState` with `SingleTickerProviderStateMixin`

### Task 5.2: Implement animation controller
- [x] Add `late AnimationController _controller`
- [x] Initialize in `initState()`: `AnimationController(duration: Duration(milliseconds: 1500), vsync: this)..repeat()`
- [x] Dispose in `dispose()`: `_controller.dispose()`

### Task 5.3: Implement build method
- [x] Filter out current user from `typingUserIds`
- [x] Return `SizedBox.shrink()` if empty
- [x] Determine display text based on `isGroup` and user count
- [x] Return `Container` with `Row` containing text and `AnimatedDots`

### Task 5.4: Implement _getUserName method
- [x] Add placeholder implementation: `return 'User';`
- [x] TODO: Get user name from conversation members

### Task 5.5: Create AnimatedDots widget
- [x] Define `AnimatedDots` StatelessWidget
- [x] Add parameter: `AnimationController controller`
- [x] Implement `build()` with `AnimatedBuilder`
- [x] Create 3 dots with `_buildDot()` method
- [x] Calculate opacity based on animation progress with offset

### Task 5.6: Implement _buildDot method
- [x] Calculate adjusted progress: `(progress + offset) % 1.0`
- [x] Calculate opacity: fade in/out based on progress
- [x] Return `Container` with circle shape and animated opacity

### Task 5.7: Integrate TypingIndicator in ChatScreen
- [x] In `build()` method, find `Column` with message list and input
- [x] Add before `MessageInputBar`:
  ```dart
  if (_typingUsers.isNotEmpty)
    TypingIndicator(
      typingUserIds: _typingUsers.keys.toList(),
      isGroup: conv?.type == 'GROUP',
      currentUserId: authState.valueOrNull?.user?.id,
    ),
  ```

## Phase 6: Testing

### Task 6.1: Backend tests
- [ ] Test handleTyping() publishes to Redis Pub/Sub
- [ ] Test handleTyping() includes correct fields
- [ ] Test handleTyping() handles missing conv_id

### Task 6.2: Flutter unit tests
- [ ] Test throttle timer cancels on each keystroke
- [ ] Test typing event emitted after 3 seconds
- [ ] Test no event when text is empty
- [ ] Test _handleTyping() updates state
- [ ] Test _handleTyping() ignores wrong conversation
- [ ] Test _handleTyping() ignores current user
- [ ] Test _cleanupTypingUsers() removes stale entries

### Task 6.3: Flutter widget tests
- [ ] Test TypingIndicator renders with 1 user
- [ ] Test TypingIndicator renders with multiple users
- [ ] Test TypingIndicator hides when empty
- [ ] Test AnimatedDots animation

### Task 6.4: Integration tests
- [ ] Test full flow: type → emit → receive → display
- [ ] Test cleanup: wait 6 seconds → indicator disappears
- [ ] Test multiple users typing simultaneously

## Phase 7: Documentation

### Task 7.1: Update CLAUDE.md
- [ ] Document typing indicator feature
- [ ] Add WebSocket "typing" event to API
- [ ] Note throttling (3s) and timeout (5s) behavior

## Estimated Effort

- Phase 1: 0.5 hours
- Phase 2: 0.25 hours
- Phase 3: 0.5 hours
- Phase 4: 1.5 hours
- Phase 5: 2 hours
- Phase 6: 2 hours
- Phase 7: 0.25 hours

**Total: ~7 hours**

## Dependencies

- Phase 2 depends on Phase 1
- Phase 3 depends on Phase 2
- Phase 4 depends on Phase 2, 3
- Phase 5 depends on Phase 4
- Phase 6 depends on all previous phases
- Phase 7 depends on Phase 6

