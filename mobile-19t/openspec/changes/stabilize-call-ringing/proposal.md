## Why

One-to-one calls are effectively broken in production. The receiver (B) almost never sees an incoming call, and when they do it appears only at the moment the caller (A) hangs up, then immediately disappears. Root cause is verified from the production database: a call record is created with `status = 'ringing'` but is moved to `'ended'` only **53 milliseconds** later because the caller's device auto-fires `endCall` right after `startCall`. With a ringing window of ~53ms, the receiver has no chance to receive the `incoming_call` signal, the reconcile lookup finds nothing, and the call is unusable.

This is a stop-the-bleeding fix to make calls work again, not a full rebuild of the calling subsystem.

## What Changes

- **Client stops auto-ending outgoing calls.** Remove the native CallKit outgoing-call presentation on the caller's device, treat native CallKit `onEnded` events as observational (never trigger a backend end), and guard `endCall` so an `outgoing` call is only ended on explicit user intent.
- **Backend owns the ringing lifecycle.** The backend keeps a call in `ringing` for a fixed timeout (45s) independent of the client, transitioning it to `missed` if neither accepted nor explicitly ended. The client no longer drives ringing teardown via its own timer.
- **Backend rejects premature end (53ms guard).** A request to end a `ringing`, not-yet-accepted call within a minimum window (~1s) of creation is treated as a no-op (returns current call state, does not write `ended`). This is a server-side defense independent of client behavior.
- **Disconnect no longer kills ringing calls.** `handleUserDisconnect` must not end a `ringing` call merely because a WebSocket dropped (common when an iOS app briefly backgrounds).
- **Reconcile-on-connect becomes effective.** The existing `GET /calls/active` endpoint and client sync-on-(re)connect/resume now have a real ringing window to catch, so the receiver can recover a pending incoming call after WebSocket reconnect or app resume.

Out of scope (deferred to later phases): rewriting the 926-line `CallNotifier` into a clean state machine, fixing FCM `SenderId mismatch` (server credential/config task), APNs VoIP reliability, and group calls.

## Capabilities

### New Capabilities
- `call-ringing-lifecycle`: Defines who owns the ringing state of a one-to-one call, how long it lives, when it may be ended, what happens on disconnect, and how a receiver reconciles a pending incoming call after reconnect.

### Modified Capabilities
<!-- No existing call capability spec exists; all behavior is captured in the new capability above. -->

## Impact

- **Backend** (`apps/api` / backend-mobile-19t): `modules/call/services/call.service.ts` (ringing timeout, premature-end guard, `endCall` idempotency, `handleUserDisconnect`, `getActiveIncomingCall`), `modules/call/call.controller.ts` (`GET /calls/active`).
- **Mobile** (`apps/mobile`): `features/call/providers/call_notifier.dart` (remove auto-end paths, `syncPendingIncomingCall`), `features/call/services/call_api_service.dart` (`getActiveIncomingCall`), `features/call/screens/*` (hangup buttons pass explicit user intent), `app.dart` (sync on WS connected + app resume).
- **Deployment**: requires deploying backend AND rebuilding the mobile app together; either side alone does not fix the bug.
- **No DB schema change**: uses existing `calls` table and statuses (`ringing`, `accepted`, `ended`, `missed`, `rejected`, `busy`).
