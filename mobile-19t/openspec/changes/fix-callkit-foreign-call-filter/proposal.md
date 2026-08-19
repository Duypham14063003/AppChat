## Why

The mobile app can incorrectly open its in-app incoming call UI when the device has an unrelated native call event, such as a call from another app or the OS call surface. This happens because the current CallKit restore path trusts generic native active-call/event data without verifying that the call belongs to this app.

## What Changes

- Add strict ownership markers to app-created CallKit payloads so native call state can be identified as app-owned.
- Filter native active calls and CallKit events before restoring Flutter call state or navigating to call screens.
- Stop fallback behavior that adopts the first native active call when no matching app-owned call is found.
- Keep backend reconcile (`syncPendingIncomingCall`) as the recovery path for real pending incoming calls when native ownership cannot be proven.

## Capabilities

### New Capabilities
- `mobile-callkit-owned-call-filter`: Defines how the mobile client marks, validates, and restores only app-owned native CallKit calls and ignores foreign/native system calls.

### Modified Capabilities
<!-- None -->

## Impact

- **Mobile app**: `apps/mobile/lib/features/call/services/callkit_service.dart`, `apps/mobile/lib/features/call/providers/call_notifier.dart`, and potentially `apps/mobile/lib/app.dart` for restore/reconcile boundaries.
- **Routing / UX**: prevents incorrect navigation to `/call/incoming` or `/call/active` when the device receives unrelated native call events.
- **Backend / APIs**: no API contract change expected; existing `GET /calls/active` reconcile path remains the source of truth for pending incoming calls.
