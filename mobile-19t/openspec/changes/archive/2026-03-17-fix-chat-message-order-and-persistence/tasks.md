## 1. Fix Message Display Order

- [x] 1.1 In `chat_screen.dart`, remove the double-reversal index mapping at line 142 — change `messages[messages.length - 1 - index]` to `messages[index]`
- [x] 1.2 Verify the loading indicator item still renders correctly at the end of the reversed list

## 2. WebSocket Send Feedback

- [x] 2.1 Change `WebSocketManager._send()` return type from `void` to `bool` — return `false` when `_channel` is null, `true` on successful sink write
- [x] 2.2 Update `sendMessage()` to return `bool` from `_send()`
- [x] 2.3 Update `sendMarkRead()` and `sendMarkDelivered()` to return `bool` from `_send()`

## 3. WebSocket Diagnostic Logging

- [x] 3.1 Add `[WS]` prefixed `debugPrint` in `_setState()` logging old → new state transition
- [x] 3.2 Add `[WS]` prefixed `debugPrint` in `connect()` logging the target URL
- [x] 3.3 Add `[WS]` prefixed `debugPrint` in `_onMessage()` for `auth_success` and `auth_error`
- [x] 3.4 Add `[WS]` prefixed `debugPrint` in `_send()` when message is dropped (channel null), including the event name
- [x] 3.5 Add `[WS]` prefixed `debugPrint` in `_scheduleReconnect()` logging the delay

## 4. Server Error Event Handling

- [x] 4.1 In `ChatNotifier.build()`, register a handler for `send_error` WS event
- [x] 4.2 On `send_error`, log the error with `[WS]` prefix and increment retry count via `dao.incrementRetryCount()`
- [x] 4.3 Dispose the `send_error` handler in `ref.onDispose`

## 5. Periodic Pending Message Retry

- [x] 5.1 Add a 10-second periodic `Timer` in `OfflineQueueService` constructor
- [x] 5.2 Timer callback calls `_flushQueue()` only when `_wsManager.state == WsConnectionState.connected`
- [x] 5.3 Cancel the periodic timer in `dispose()`

## 6. Offline Banner Enhancement

- [x] 6.1 In `chat_screen.dart`, update the offline banner condition to show for both `disconnected` and `connecting` states
- [x] 6.2 Display "Đang kết nối..." text when state is `connecting`
- [x] 6.3 Keep existing "Không có kết nối" text when state is `disconnected`
