## Context

The Flutter app already has a shared notification pipeline:

- `PushNotificationService` listens to `FirebaseMessaging.onMessage`
- `app.dart` decides whether a foreground notification should be shown
- `LocalNotificationService` is responsible for rendering a local notification banner
- chat-specific realtime notifications can also enter through the app-level websocket path

The reported bug is broader than chat. HR, leave, and reminder notifications also fail to appear while the app is already open, then start appearing again once the app is backgrounded or terminated. That symptom strongly suggests a fault in the shared foreground presentation layer rather than in feature-specific business logic.

The real backend implementation now lives outside this repository, so this change intentionally avoids relying on backend modifications. The mobile app should behave correctly whenever it receives a foreground event or an FCM message in-app.

## Goals / Non-Goals

**Goals:**
- Make foreground notifications visible while the mobile app is open for all supported in-app notification types already handled by the shared pipeline.
- Keep foreground chat suppression intact when the user is already viewing the exact matching conversation.
- Ensure Android and iOS foreground presentation is explicitly configured rather than depending on plugin defaults.
- Add logging/error visibility so failures in notification initialization or `show()` calls do not fail silently.

**Non-Goals:**
- Redesign notification payload schemas or backend delivery contracts.
- Add new notification center, preferences, or badge features.
- Change background / terminated notification behavior unless needed for safe compatibility with the foreground fix.
- Expand scope to desktop or web notification UX.

## Decisions

### D1: Treat this as a shared mobile notification-infrastructure fix

**Decision:** Implement the fix in the shared foreground notification path (`PushNotificationService`, `LocalNotificationService`, and app-level notification integration) rather than inside chat, HR, or leave feature modules.

**Why:** The same symptom appears across multiple notification types. The common layer is the only realistic place where one change can fix all foreground cases consistently.

**Alternatives considered:**
- Patch each feature independently. Rejected because it duplicates logic and misses the shared failure mode.
- Wait for backend-side changes. Rejected because the production backend is outside this repo and the visible bug is in client-side presentation behavior.

### D2: Use a single explicit foreground display owner per event

**Decision:** Foreground notifications should be shown through one clearly owned display path per event, with platform-specific configuration chosen to avoid duplicate banners while still allowing visible alerts.

**Why:** The app already mixes FCM-driven foreground handling and websocket-driven chat handling. Without a single display owner, fixes risk creating duplicate banners on one platform while still failing silently on another.

**Alternatives considered:**
- Let both system foreground presentation and local notifications display the same event. Rejected because it can double-notify users.
- Continue relying on implicit platform/plugin defaults. Rejected because the current behavior is already unreliable.

### D3: Harden platform-specific notification presentation prerequisites

**Decision:** Make foreground notification prerequisites explicit:
- Android should use a valid local-notification icon/resource strategy suitable for foreground local notifications.
- iOS should explicitly configure foreground notification presentation behavior instead of assuming the existing defaults are sufficient.

**Why:** Cross-platform notification libraries often appear to be initialized correctly while still failing at display time due to icon or presentation configuration gaps. The current bug profile matches that kind of infrastructure issue.

**Alternatives considered:**
- Only add more logging and hope the current config is enough. Rejected because the likely failure is configuration-related, not just observability-related.
- Rebuild the entire notification stack. Rejected as too large for a targeted bugfix.

### D4: Preserve existing routing, refresh, and suppression decisions

**Decision:** Keep current route-aware suppression for active chat conversations and preserve existing notification side effects such as attendance refresh and tap navigation.

**Why:** The current complaint is “no foreground notification appears,” not “notification routing is wrong.” The fix should repair visibility without regressing the logic that already prevents noisy alerts in the active conversation.

**Alternatives considered:**
- Remove suppression to simplify debugging. Rejected because it would knowingly reintroduce noisy chat behavior.

### D5: Add explicit failure visibility around initialization and display

**Decision:** Add targeted logging and error capture around notification initialization, permission state, and foreground `show()` calls.

**Why:** The current shared path can fail in a way that is difficult to distinguish from “message never arrived.” Better diagnostics reduce the cost of future notification regressions.

**Alternatives considered:**
- Rely only on manual QA. Rejected because notification issues are notoriously platform-specific and regress easily.

## Risks / Trade-offs

- [Risk] A platform-specific fix could accidentally create duplicate foreground banners on iOS if both system presentation and local notification display the same message.
  Mitigation: keep one explicit display owner per event and verify real-device behavior.

- [Risk] Tightening Android icon/resource requirements may require a new dedicated notification asset.
  Mitigation: scope the change to the shared local notification layer and document the required resource.

- [Risk] Chat foreground handling can still duplicate if websocket and FCM paths are not aligned around the same message identity.
  Mitigation: preserve existing message-id dedupe behavior and validate the shared policy during implementation.

- [Risk] Some test environments cannot fully emulate real OS foreground notification banners.
  Mitigation: keep tests focused on decision logic and initialization behavior, then require manual Android/iOS verification.

## Migration Plan

1. Audit and harden the shared foreground notification initialization path.
2. Make Android/iOS foreground display prerequisites explicit in the mobile notification infrastructure.
3. Route all eligible foreground display through the hardened shared path while preserving active-chat suppression and tap handling.
4. Add targeted logging and focused regression coverage.
5. Manually verify foreground notification behavior on real Android and iOS devices across chat, HR, leave, and reminder scenarios.

Rollback is low risk: revert the shared foreground presentation changes while preserving the existing notification routing and refresh hooks.

## Open Questions

None. The scope is intentionally constrained to the mobile foreground display path already present in this repository.
