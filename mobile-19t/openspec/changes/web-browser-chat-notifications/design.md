## Context

The app already has a foreground notification entry point in `app.dart` that listens for incoming chat events from both Firebase foreground messages and the authenticated WebSocket `new_message` event. On native platforms, those events are shown through `LocalNotificationService`, which wraps `flutter_local_notifications`.

Web is only partially covered today. Background push delivery has a Firebase messaging service worker, so a browser notification can appear when the page is not actively executing app Dart code. However, the foreground in-app path still uses the same local notification service abstraction that is primarily configured for Android, iOS, and macOS. There is no explicit browser Notification API layer, no browser-specific permission state handling, and no web-focused fallback when foreground chat events arrive while the app is open.

## Goals / Non-Goals

**Goals:**
- Show visible browser notifications for incoming chat messages on web when notification permission has been granted.
- Preserve the current suppression behavior so notifications do not appear for the conversation the user is already viewing.
- Keep foreground notification formatting aligned with existing helpers in `app.dart`.
- Avoid duplicate alerts when the same chat message is observed through both WebSocket and FCM foreground streams.
- Keep native platform notification behavior unchanged.

**Non-Goals:**
- Reworking backend push payload contracts.
- Replacing the existing Firebase service worker for web background notifications.
- Adding non-chat browser notifications in this change.
- Redesigning mobile notification UX.

## Decisions

### D1: Introduce a dedicated browser notification service for web
**Choice:** Add a service abstraction for browser notifications instead of trying to force `flutter_local_notifications` to cover web foreground alerts.
**Rationale:** The browser Notification API has its own permission model and runtime behavior. A dedicated service makes web behavior explicit and avoids mixing native-only initialization assumptions into the web path.
**Alternatives considered:** Continue routing all platforms through `LocalNotificationService`. Rejected because the current abstraction is centered on native platform implementations and does not clearly expose browser permission or browser notification lifecycle.

### D2: Keep notification routing centralized in `app.dart`
**Choice:** Reuse the existing foreground routing logic in `app.dart` and swap only the final display mechanism on web.
**Rationale:** The current app-level notification flow already contains suppression, de-duplication, and navigation formatting helpers. Reusing it avoids splitting message eligibility rules between platform-specific modules.
**Alternatives considered:** Trigger browser notifications directly from chat providers or the WebSocket manager. Rejected because it would duplicate suppression and message formatting logic.

### D3: Reuse the existing foreground chat de-duplication key strategy
**Choice:** Continue using `foregroundNotificationEventIdForData(...)` and the tracked message ID queue to suppress duplicate browser notifications.
**Rationale:** Incoming chat messages may reach the app through WebSocket and Firebase foreground streams. The app already has a cross-source dedupe concept, so web should plug into the same mechanism.
**Alternatives considered:** Separate dedupe for web only. Rejected because it risks source-specific drift and inconsistent notification counts across platforms.

### D4: Request browser notification permission during authenticated notification bootstrap
**Choice:** Web permission checks and requests should happen inside the authenticated notification bootstrap flow alongside existing push initialization.
**Rationale:** This keeps notification readiness tied to the same session lifecycle as FCM token setup and foreground listener registration. It also avoids prompting anonymous users unnecessarily.
**Alternatives considered:** Prompt only when the first foreground chat message arrives. Rejected because browser permission prompts are better handled intentionally, not reactively during message delivery.

### D5: Keep background web notifications on the service worker path
**Choice:** Do not replace the existing `firebase-messaging-sw.js` background behavior in this change.
**Rationale:** The missing feature is browser notification display while the app is active on web. Background web notification handling already has a dedicated service worker path and should remain stable.
**Alternatives considered:** Merge foreground and background web notification handling into one new layer. Rejected because it broadens scope without addressing the immediate gap.

## Risks / Trade-offs

- `[Browser permission may be denied or dismissed]` → Treat permission state as first-class and fail gracefully without breaking chat delivery.
- `[WebSocket and FCM foreground events may duplicate the same message]` → Keep the shared recent-message dedupe strategy in front of the display call.
- `[Browser notification APIs differ across platforms and tab states]` → Isolate browser-specific checks behind a service and keep the app routing logic platform-neutral.
- `[Prompting for permission too early may reduce opt-in]` → Limit permission requests to authenticated notification bootstrap and avoid repeated prompting once denied.

## Migration Plan

This is a client-only rollout. Deployment can happen with the web app release and does not require backend or database migration.

Rollback is straightforward: disable the web browser notification service call path and continue using the existing native notification path plus the current Firebase service worker for background web delivery.

## Open Questions

- Whether denied browser notification permission should surface a subtle in-app setting hint is out of scope for this change and can be deferred.
