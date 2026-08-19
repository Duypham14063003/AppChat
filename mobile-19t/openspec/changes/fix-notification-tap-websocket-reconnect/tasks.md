## 1. WebSocket Recovery Semantics

- [x] 1.1 Add a safe WebSocket recovery entry point that connects only when the manager is disconnected and leaves connecting/connected states alone.
- [x] 1.2 Separate intentional disconnect/logout behavior from recoverable disconnect behavior so logout cancels reconnect but unexpected socket loss can reconnect.
- [x] 1.3 Harden WebSocket auth-error handling so a recoverable stale-token auth failure does not leave the manager permanently disconnected.

## 2. Token Refresh Coordination

- [x] 2.1 Update successful HTTP access-token refresh handling to synchronize the WebSocket auth token cache.
- [x] 2.2 Ensure future WebSocket reconnect handshakes use the refreshed access token without requiring an app restart.

## 3. Notification Tap and Lifecycle Wiring

- [x] 3.1 Add an authenticated app-level helper that triggers WebSocket recovery only for authenticated sessions.
- [x] 3.2 Call the recovery helper when the app resumes while preserving existing chat list and badge refresh behavior.
- [x] 3.3 Call the recovery helper for chat notification taps while preserving existing notification route navigation.
- [x] 3.4 Ensure unauthenticated or unresolved auth states do not create unauthenticated WebSocket connections.

## 4. Verification

- [x] 4.1 Add tests for notification tap reconnect decisions across disconnected, connecting, connected, and unauthenticated states.
- [x] 4.2 Add tests for app resume reconnect behavior while preserving existing resume sync expectations.
- [x] 4.3 Add tests for token refresh updating the WebSocket token cache or equivalent reconnect auth source.
- [x] 4.4 Run the relevant Flutter test suite for app routing/lifecycle, auth refresh, and WebSocket reconnect behavior.
- [ ] 4.5 Manually verify on device: lock screen, receive chat notification, tap it, confirm the chat opens and the connection recovers without force-closing the app.
