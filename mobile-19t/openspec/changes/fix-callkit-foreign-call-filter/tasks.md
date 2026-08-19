## 1. CallKit payload ownership markers

- [x] 1.1 Add a shared app-owned marker constant and helper(s) in the mobile CallKit service layer for constructing and validating app-created native payloads.
- [x] 1.2 Ensure foreground incoming call presentation includes the ownership marker, business `callId`, and `callDirection`.
- [x] 1.3 Ensure background push-driven incoming call presentation includes the same ownership marker and preserves the business `callId`.

## 2. Filter native restore and events

- [x] 2.1 Update `CallKitService` to ignore accept/decline/end/timeout events that cannot be validated as app-owned.
- [x] 2.2 Update `checkInitialCall()` to restore state only from validated app-owned native calls instead of trusting the first active native call.
- [x] 2.3 Update `_restoreIncomingStateFromNativeCall()` to remove fallback-to-first-active-call behavior and exit when no validated app-owned match exists.

## 3. Preserve backend reconcile as fallback

- [x] 3.1 Confirm the app resume / reconnect flow continues to rely on `syncPendingIncomingCall()` when native ownership cannot be validated.
- [x] 3.2 Add focused logs or dev diagnostics for ignored foreign native calls/events so ownership-filter behavior is debuggable.

## 4. Verification

- [x] 4.1 Add or update unit tests for native payload ownership validation and foreign-event filtering.
- [x] 4.2 Add or update tests for `checkInitialCall()` / restore logic so foreign native calls do not navigate to app call screens.
- [x] 4.3 Run `flutter analyze` on the changed mobile call files.
- [ ] 4.4 Manual check: an app-originated incoming call still restores correctly after resume / native action.
- [ ] 4.5 Manual check: receiving a foreign/native-system call does not open the app's incoming or active call UI.
