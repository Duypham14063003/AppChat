## Context

One-to-one calls are broken in production. The verified root cause: a call is created in `ringing` status but moved to `ended` only ~53ms later because the caller's device auto-fires `endCall` immediately after `startCall`. With a ~53ms ringing window, the receiver never receives the realtime `incoming_call` signal, the reconcile lookup finds nothing, and the call appears (if at all) only when the caller hangs up.

Current architecture spreads call state across four places with no single owner: the backend DB, the Flutter `CallNotifier` (926 lines of band-aid flags), native CallKit, and Agora RTC. Signaling uses fire-and-forget Redis pub/sub gated on a `isOnline()` check that only verifies a socket object exists, not that it is alive. The client drives the ringing timeout via its own 45s timer and reacts to spurious native CallKit `onEnded` events by calling the backend end endpoint.

The media layer (Agora) and the call UI screens work correctly. All observed bugs originate in the signaling and state-ownership layer.

This change is a targeted stop-the-bleeding fix, not the full rebuild. The full `CallNotifier` rewrite and signaling re-architecture are deferred.

## Goals / Non-Goals

**Goals:**
- Keep a call in `ringing` long enough (45s) for the receiver to be notified and answer.
- Make the backend the authority over ringing lifetime and over whether an end is valid.
- Stop the client from ending an outgoing call unless the user explicitly cancels.
- Make the existing reconcile-on-connect path effective by guaranteeing a real ringing window.
- Ship as a coordinated backend + mobile deploy with no DB schema change.

**Non-Goals:**
- Rewriting `CallNotifier` into a clean state machine (later phase).
- Fixing FCM `SenderId mismatch` (server credential task) or APNs VoIP reliability.
- Group calls.
- Changing the media (Agora) layer or call UI screens beyond passing explicit user intent on hangup.

## Decisions

### Decision 1: Two-layer defense against premature end (client guard + server guard)

The client is fixed to not emit spurious ends (remove native outgoing CallKit, treat `onEnded` as observational, require `userInitiated` to end an `outgoing` call). Independently, the backend rejects an end of a `ringing`, not-yet-accepted call within 1s of creation as a no-op.

- **Why two layers**: The client fix alone trusts the client. The 53ms event is machine-generated; a human cannot start+cancel under 1s, so a 1s server window blocks the bug without blocking real user cancels. Defense-in-depth matches the "backend is source of truth" principle.
- **Why no-op (not error)**: Spurious client events may retry. Returning the current `ringing` state avoids the client mishandling an error response.
- **Alternative considered**: Server-only guard. Rejected — leaves the client free to keep generating phantom ends that pollute logs and risk other races. Client-only guard. Rejected — trusts the client entirely, which is what caused the bug.

### Decision 2: Backend owns the ringing timeout (45s)

The backend transitions a `ringing` call to `missed` after 45s if it is not accepted/rejected/ended, independent of any client timer.

- **Why backend-owned**: The client timer is unreliable (app can background/suspend) and is part of the band-aid logic being reduced. A server-owned timeout guarantees the ringing window exists for reconcile and for the receiver to answer.
- **Implementation approach**: A scheduled transition keyed off the call's `started_at`/`created_at`. The simplest correct option is a lazy + active hybrid: (a) `getActiveIncomingCall` and `startCall` already treat ringing older than 60s as stale, and (b) add an explicit timeout that fires at 45s to emit the `missed`/ended notifications so both sides clear their UI. Reuse the existing stale-call cleanup logic rather than introducing a new scheduler dependency where possible.
- **Alternative considered**: Keep client-driven timeout. Rejected — it is exactly the unreliable mechanism causing UI/state divergence.

### Decision 3: Disconnect must not end ringing calls

`handleUserDisconnect` is scoped to only auto-end calls that have progressed past `ringing` (e.g. `accepted`). A dropped WebSocket while ringing leaves the call ringing toward its normal timeout.

- **Why**: iOS apps briefly background during dialing, dropping the socket; the current logic ends the call, compounding the failure. Ringing calls should be governed solely by the 45s timeout and explicit user actions.
- **Alternative considered**: Grace period before disconnect-end. Rejected for this phase — the 45s ringing timeout already bounds the call; simpler to just exclude ringing from disconnect teardown.

### Decision 4: Reconcile-on-connect stays as the receiver recovery path

Keep `GET /calls/active` (returns the newest non-stale `ringing` call where the user is receiver) and the client sync triggered on WS `connected` transition and on app resume. With Decisions 1–3 guaranteeing a real ringing window, this path now functions.

- **Why**: Realtime delivery (WS/push) is best-effort. A pull-on-connect reconcile is the reliable backstop and is independent of whether the `incoming_call` event arrived on time.
- **Dedup**: presentation is suppressed via the existing processed-call-id tracking so a reconciled call that also arrived via WS is not shown twice.

## Risks / Trade-offs

- **Realtime delivery still best-effort (FCM/APNs broken/flaky)** → Reconcile-on-connect catches missed calls when the receiver's app is open and (re)connects within the 45s window. Background/locked Android remains unreliable until FCM `SenderId mismatch` is fixed (out of scope, flagged separately).
- **45s server timeout vs. existing 60s stale cleanup** → Align the timeout so the active `missed` transition (45s) and the stale-call guards remain consistent; pick 45s as the authoritative ring duration and ensure stale checks do not contradict it.
- **1s guard could in theory block a genuine sub-second cancel** → Humans cannot tap cancel under 1s after the dial round-trip; acceptable. The guard only applies to not-yet-accepted ringing calls.
- **Partial deploy (only one side)** → No fix and possible new mismatch. Mitigation: deploy backend and mobile together; document as a release gate.
- **Reconcile races with a just-ended call** → `getActiveIncomingCall` filters to `ringing` and non-stale only, so an ended/missed call is never presented.

## Migration Plan

1. Land backend changes (premature-end guard, 45s ringing timeout + `missed` transition, `endCall` idempotency, `handleUserDisconnect` exclusion of ringing, `GET /calls/active`).
2. Land mobile changes (remove native outgoing CallKit, observational `onEnded`, `userInitiated` end guard, `syncPendingIncomingCall` on WS connected + resume).
3. Deploy backend, then release the rebuilt mobile app. Both are required together.
4. Verify with the SQL check: `ringing_seconds` for new calls should reflect real ring duration (seconds, not ~0.05s), and a receiver with the app open should see the incoming call.
5. Rollback: revert backend and mobile together to the prior release; no DB migration to undo.

## Open Questions

- Should the 45s `missed` transition be driven by an in-process timer per call, or by reusing the existing lazy stale-cleanup plus a lightweight scheduler? (Implementation detail to settle in tasks; prefer the least new infrastructure.)
- Exact minimum-end guard value: 1s is proposed; confirm it comfortably exceeds the real start→end round-trip so it never blocks a legitimate immediate cancel.
