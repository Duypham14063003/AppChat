## 1. Resume-Aware Reconnect Policy

- [x] 1.1 Add a shared recent-resume / refocus timing helper that records when severe offline presentation should be suppressed after foreground, visibility regain, or notification/chat entry.
- [x] 1.2 Wire the relevant lifecycle and entry events in the app shell so the reconnect grace window starts during normal resume/refocus flows without changing existing reconnect triggers.
- [x] 1.3 Keep the policy deterministic and testable so banner decisions do not depend on ad hoc widget-local timers alone.

## 2. Connection Banner Presentation

- [x] 2.1 Update the app-level connection banner in `apps/mobile/lib/app.dart` to suppress immediate hard-failure UI during the reconnect grace window.
- [x] 2.2 Introduce staged messaging/severity so transient reconnect states use softened presentation and sustained failures escalate to stronger offline feedback.
- [x] 2.3 Align the chat-scoped offline banner with the same resume-aware suppression and escalation policy so app-shell and room-level feedback remain consistent.
- [x] 2.4 Ensure transient websocket recovery is not labeled as confirmed internet loss in banner copy or state mapping.

## 3. Verification

- [x] 3.1 Add automated coverage for recent-resume suppression and for sustained disconnect escalation after the grace period.
- [x] 3.2 Add automated coverage proving app-level and chat-level banner decisions stay aligned for the same transient reconnect state.
- [x] 3.3 Run the relevant Flutter test suite for app lifecycle, websocket banner presentation, and chat offline-banner behavior.
- [ ] 3.4 Manually verify on mobile and web: background/foreground return, tab visibility regain, and notification/chat re-entry no longer flash a severe red disconnect banner during short reconnect recovery.
