## Context

The mobile app already supports chat notification routing through Firebase Messaging. `PushNotificationService` calls the app-level notification tap handler for both `onMessageOpenedApp` and `getInitialMessage`, and `_handleNotificationTap` routes chat payloads to `/chat/<convId>`.

The chat screen renders its offline banner from `webSocketConnectionProvider`, which reflects the `WebSocketManager` state rather than the device's general internet connectivity. When the app is locked or backgrounded, the server heartbeat can terminate the socket or the mobile runtime can suspend the connection. If the user taps a notification immediately after that, the route can open before the app has restored the WebSocket session.

The current app resume handler refreshes chat list and badge state, but it does not explicitly recover the WebSocket connection. Separately, the WebSocket manager uses a synchronous cached token for auth. Dio refreshes access tokens in `AuthInterceptor`, but that refresh path does not update the WebSocket token cache. A reconnect after token refresh can therefore auth with a stale token, receive `auth_error`, call `disconnect()`, and cancel the reconnect timer.

## Goals / Non-Goals

**Goals:**
- Restore WebSocket connectivity when an authenticated user taps a chat notification from lock screen/background.
- Restore WebSocket connectivity when the app resumes and the session is authenticated but the socket is not connected.
- Keep notification chat routing behavior stable: chat notifications still open the target conversation route.
- Keep WebSocket reconnect resilient across token refresh and auth-error races.
- Add focused unit/widget-level coverage for lifecycle and notification-triggered reconnect decisions.

**Non-Goals:**
- Replace WebSocket transport or change backend WebSocket contracts.
- Add a general-purpose device connectivity package.
- Redesign the chat offline banner or message UI states.
- Change FCM payload schema, notification display behavior, or push token registration semantics.
- Guarantee delivery while the app process is killed; this change covers app resume/open flows that execute mobile code.

## Decisions

### D1: Centralize authenticated WebSocket recovery in a small app-level helper

**Decision:** Introduce an app-level recovery helper that checks the current auth state and WebSocket state, then calls the WebSocket manager when the user is authenticated and the socket is not connected.

**Why:** Both lifecycle resume and notification tap need the same behavior. Keeping the auth/state decision in one helper reduces duplicated conditional logic and makes the behavior straightforward to test.

**Alternatives considered:**
- Trigger reconnect only inside `ChatScreen.initState`. Rejected because notification tap is not the only resume path, and the app should restore realtime state even before a specific chat screen mounts.
- Trigger reconnect unconditionally on every resume. Rejected because unauthenticated sessions and already-connected sockets should not create unnecessary connection attempts.

### D2: Kick WebSocket recovery on chat notification tap without blocking navigation

**Decision:** For chat notification payloads, start WebSocket recovery immediately before or after routing, but do not block route navigation on the socket handshake.

**Why:** The target conversation should open promptly from the notification. The connection banner can transition from disconnected/connecting to connected as the socket recovers. Blocking navigation on network I/O risks making notification taps feel broken under slow or unstable network conditions.

**Alternatives considered:**
- Await WebSocket connection before navigating. Rejected because WebSocket auth can take longer than the UX path should wait, and failure would prevent the user from seeing cached chat content.
- Only rely on the existing reconnect timer. Rejected because the timer can be canceled by manual disconnect/auth-error paths and may not exist when the app resumes from lock screen.

### D3: Separate manual disconnect from recoverable socket loss

**Decision:** Keep a path for intentional disconnect on logout/dispose that cancels reconnect, but ensure recoverable socket loss and notification/resume recovery can schedule a reconnect.

**Why:** Logout must stop the socket. Network loss, app suspension, heartbeat termination, and notification entry are recoverable states. Treating all of them like a manual disconnect can strand the manager in `disconnected`.

**Alternatives considered:**
- Make `disconnect()` always reconnect later. Rejected because logout and provider disposal must not keep reconnecting in the background.
- Leave disconnect semantics unchanged and add more callers to `connect()`. Rejected because auth-error can still cancel reconnect permanently.

### D4: Keep WebSocket token cache synchronized after access-token refresh

**Decision:** When `AuthInterceptor` refreshes access tokens successfully, update the WebSocket token cache used by future handshakes. If a reconnect is needed, the manager should auth with the fresh token.

**Why:** The server validates WebSocket auth with the access token. A stale cached token can cause `auth_error`, especially after the device has been locked and the app wakes via notification.

**Alternatives considered:**
- Make the WebSocket token provider async and read secure storage during every connect. Rejected for this change because the current manager API is synchronous and a broader async refactor is unnecessary.
- Ignore token-cache sync and rely on app restart. Rejected because this is the failure mode users are currently hitting.

## Risks / Trade-offs

- [Risk] Reconnect calls from resume and notification tap can happen close together. -> Mitigation: keep `WebSocketManager.connect()` idempotent for `connecting` and `connected` states.
- [Risk] Auth-error handling can reconnect forever for truly invalid sessions. -> Mitigation: coordinate with auth failure behavior and avoid reconnecting after explicit logout/token clear.
- [Risk] Tests may need fake WebSocket managers with more observable state. -> Mitigation: keep new helper logic pure enough to test without real sockets.
- [Risk] Foreground/background timing differs between Android and iOS. -> Mitigation: cover both `onMessageOpenedApp` and `getInitialMessage` paths through shared notification tap handling, then manually verify lock-screen notification entry on device.

## Migration Plan

1. Add or expose a WebSocket recovery method that can safely connect when disconnected and avoid work when already connecting/connected.
2. Wire app resume handling to trigger authenticated WebSocket recovery alongside existing chat list and badge sync.
3. Wire chat notification tap handling to trigger authenticated WebSocket recovery while preserving route navigation.
4. Update token refresh handling to sync the WebSocket cached token after successful refresh.
5. Harden auth-error/disconnect semantics so recoverable failures do not permanently cancel reconnect.
6. Add tests and manually verify lock-screen notification tap into a chat conversation.

Rollback: remove the new recovery calls and token-cache sync if regressions appear. Existing notification routing and chat UI can continue to function with the previous reconnect limitations.

## Open Questions

None. The user-confirmed trigger is chat notification tap from the lock screen/background state, and the fix can remain mobile-client scoped.
