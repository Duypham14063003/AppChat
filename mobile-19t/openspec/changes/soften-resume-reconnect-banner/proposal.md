## Why

When users return to the app or web client after some idle time, the realtime socket can briefly move through disconnected or reconnecting states before recovering. The current UI exposes that transient transport state too aggressively, showing a prominent red connection-loss banner even when recovery completes quickly.

This needs to be fixed now because the current behavior makes the product feel slow and unreliable during a common resume flow, even when cached content is available and realtime recovers on its own a moment later.

## What Changes

- Add a resume-aware connection-status presentation policy that suppresses or softens transient reconnect banners immediately after app foreground, web tab visibility regain, notification-driven entry, and similar focus-return moments.
- Distinguish short reconnect recovery from sustained connectivity loss so transient websocket recovery does not immediately present as a hard offline failure.
- Narrow the severe red error presentation to cases where reconnect exceeds a grace period or transport loss is confirmed to be persistent.
- Preserve existing cache-first rendering and websocket recovery behavior while changing when and how connection status is surfaced to users.
- Add focused tests for resume/refocus banner suppression, reconnect-state messaging, and persistent-disconnect fallback behavior.

## Capabilities

### New Capabilities
- `resume-reconnect-banner`: User-facing connection feedback that suppresses or softens transient reconnect banners after resume/refocus and escalates only for sustained disconnects.

### Modified Capabilities
<!-- No existing capability requirements are being modified. -->

## Impact

- App-level connection banner logic in `apps/mobile/lib/app.dart`.
- Chat-scoped offline banner behavior in `apps/mobile/lib/features/chat/widgets/offline_banner.dart`.
- Websocket state presentation and any shared reconnect timing helpers in `apps/mobile/lib/core/network/websocket_manager.dart` and adjacent UI helpers.
- App lifecycle and route/notification entry hooks that define the recent-resume window.
- Mobile and web-facing tests covering resume, reconnect, and persistent-offline presentation behavior.
