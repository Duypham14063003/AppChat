## Context

The current mobile call flow uses two recovery paths when the app resumes or receives native call callbacks:

1. Backend reconcile through `syncPendingIncomingCall()`
2. Native restore through `FlutterCallkitIncoming.activeCalls()` and CallKit event callbacks

The backend reconcile path is scoped to the app's own business calls and is safe. The native restore path is not. `checkInitialCall()` and `_restoreIncomingStateFromNativeCall()` currently trust generic native call payloads and may fall back to the first active native call even when no app-owned match exists. This can cause the app to navigate to its own incoming/active call screens for foreign calls created by other apps or the system call surface.

This change is mobile-only and cross-cuts the CallKit wrapper plus the Flutter call state restore logic.

## Goals / Non-Goals

**Goals:**
- Ensure only app-owned native CallKit calls can restore Flutter call state.
- Prevent navigation to in-app call screens for foreign/native system calls.
- Preserve legitimate recovery for app-created incoming calls across app resume and native CallKit actions.
- Keep backend reconcile as the fallback recovery path when native ownership is missing or uncertain.

**Non-Goals:**
- Reworking the broader ringing lifecycle or Agora media behavior.
- Changing backend signaling or call APIs.
- Supporting interoperability with third-party call providers through the app's own UI.

## Decisions

### Decision 1: Mark every app-created native call with an explicit ownership marker

All incoming native CallKit payloads created by the app will include a stable app-specific marker such as `appSource`, alongside the business `callId` and `callDirection`.

- **Why**: The current payload already carries `callId` and `callDirection`, but the restore path does not require them and generic native payloads may still be interpreted as app calls. An explicit ownership marker gives a strict allow-list signal.
- **Alternative considered**: Rely only on `callId`. Rejected because native payloads can expose `id`/`uuid` values that are not app business identifiers, and current restore code falls back too broadly.

### Decision 2: Filter active native calls before any state restoration

`checkInitialCall()` and `_restoreIncomingStateFromNativeCall()` will only consider active calls whose payload passes an `isAppOwnedCall` validation helper. The fallback that adopts `calls.first` when no match is found will be removed.

- **Why**: The existing first-call fallback is the direct path that can misclassify unrelated native calls as app calls.
- **Alternative considered**: Keep fallback but only on iOS/Android-specific branches. Rejected because the ownership problem is conceptual, not platform-specific.

### Decision 3: Ignore foreign native CallKit events at the service boundary

`CallKitService` will normalize native event payloads and refuse to invoke higher-level callbacks when an event cannot be proven app-owned.

- **Why**: Filtering at the boundary reduces accidental state changes in `CallNotifier` and keeps the contract simpler.
- **Alternative considered**: Filter only in `CallNotifier`. Rejected because downstream code would still need to defend against invalid events everywhere.

### Decision 4: Backend reconcile remains the authoritative recovery path

If there is no validated app-owned native call on resume or native callback, the client will not guess. Instead, normal recovery continues through `syncPendingIncomingCall()`, which queries the backend for a real pending incoming call.

- **Why**: The backend has business-level ownership and participant context; native call state does not.
- **Alternative considered**: Reconstruct incoming state entirely from native payloads. Rejected because it cannot guarantee ownership or business correctness.

## Risks / Trade-offs

- **[False negatives for older/native payload variants]** → Acceptable if backend reconcile still surfaces real pending incoming calls; add the ownership marker everywhere the app creates CallKit payloads.
- **[Resume path may appear “less aggressive” in restoring UI]** → This is intentional; avoiding a false incoming-call UI is more important than guessing from ambiguous native state.
- **[Event filtering may hide malformed app-generated payloads]** → Add focused logs for ignored native events so dev mode can diagnose missing markers quickly.

## Migration Plan

1. Add the app-owned marker to all app-created CallKit payloads in the service layer, including foreground and background incoming call presentation.
2. Introduce a shared validation helper for app-owned native calls/events.
3. Update restore paths in `CallNotifier` to require validated native ownership and remove fallback-to-first-active-call behavior.
4. Verify manual flows: app-originated incoming call still restores correctly; foreign/native calls no longer open app call UI; backend reconcile still restores legitimate pending incoming calls after reconnect/resume.
5. Rollback is mobile-only: revert the client changes and rebuild the app. No backend or schema rollback is required.

## Open Questions

- Do we want the ownership marker value to be a simple constant string or a versioned marker for future payload migrations? A simple constant is likely sufficient for this change.
