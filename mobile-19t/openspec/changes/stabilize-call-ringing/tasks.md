## 1. Backend: premature-end guard & idempotency

- [x] 1.1 In `call.service.ts endCall`, make ending an already-`ended` call a no-op that returns the existing call state without emitting notifications
- [x] 1.2 Add a minimum-end guard: if call is `ringing`, not yet accepted, and created less than 1s ago, return current `ringing` state without changing status (no-op, no error)
- [x] 1.3 Ensure ending an `accepted` call is never blocked by the guard

## 2. Backend: backend-owned ringing timeout

- [x] 2.1 Implement a 45s ringing timeout that transitions a still-`ringing` call to `missed` if not accepted/rejected/ended
- [x] 2.2 On timeout, emit the existing call-ended/missed notifications to both caller and receiver so their UI clears
- [x] 2.3 Reconcile the 45s authoritative ring duration with existing stale-call cleanup (currently 60s) so checks do not contradict each other

## 3. Backend: disconnect must not kill ringing calls

- [x] 3.1 In `handleUserDisconnect`, exclude `ringing` calls from auto-end; only auto-end calls that have progressed past ringing (e.g. `accepted`)

## 4. Backend: reconcile endpoint

- [x] 4.1 Confirm `getActiveIncomingCall` returns the newest non-stale `ringing` call where the user is receiver (filter stale > ring window)
- [x] 4.2 Confirm `GET /calls/active` endpoint is wired in `call.controller.ts`
- [x] 4.3 Type-check backend (`npm run build` / tsc) and run `npm run lint`

## 5. Mobile: stop client auto-ending outgoing calls

- [x] 5.1 Remove the native CallKit outgoing-call presentation on the caller's device (no `showOutgoingCall` in `startCall`)
- [x] 5.2 Make native CallKit `onEnded` observational — it MUST NOT call the backend end for an outgoing call
- [x] 5.3 Guard `endCall` so an `outgoing` call is only ended when `userInitiated` is true
- [x] 5.4 Ensure hangup controls on outgoing and active call screens pass explicit user intent

## 6. Mobile: reconcile-on-connect

- [x] 6.1 Confirm `getActiveIncomingCall` exists in `call_api_service.dart`
- [x] 6.2 Confirm `syncPendingIncomingCall` in `call_notifier.dart` presents a pending call and dedups already-processed call ids
- [x] 6.3 Trigger `syncPendingIncomingCall` on WebSocket `connected` transition and on app resume in `app.dart`

## 7. Verification

- [x] 7.1 Run `flutter analyze` on changed mobile files
- [x] 7.2 Run `flutter test test/features/call/` (add/adjust unit tests for the end-guard and observational onEnded logic)
- [ ] 7.3 Manual check: a call stays `ringing` for the real ring duration (SQL `ringing_seconds` is seconds, not ~0.05s)
- [ ] 7.4 Manual check: receiver with app open sees the incoming call; caller hangup ends both sides; receiver reconnect within window recovers a pending call
