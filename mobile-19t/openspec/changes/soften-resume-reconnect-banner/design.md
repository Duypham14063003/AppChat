## Context

The app already attempts to recover websocket connectivity when an authenticated session resumes, when a chat room opens, and when a notification tap routes the user into chat. Those transport-recovery paths are important and should remain intact.

The user-facing problem is instead in presentation timing. The app-level connection banner in `apps/mobile/lib/app.dart` currently appears immediately whenever websocket state is not `connected`, while the chat-scoped `OfflineBanner` in `apps/mobile/lib/features/chat/widgets/offline_banner.dart` already applies a short grace period before showing a hard offline state. This mismatch exposes transient reconnect states too aggressively at the app shell layer.

Because the product is cache-first, users can usually keep reading existing content while realtime recovers. Showing a hard red failure banner during the first moments after app foreground, web tab visibility regain, or notification-driven entry makes the client feel unstable even when recovery completes normally.

## Goals / Non-Goals

**Goals:**
- Suppress severe connection-loss presentation during a short, expected reconnect window after app resume, focus regain, or notification/chat re-entry.
- Differentiate transient reconnect recovery from sustained disconnect so user messaging matches the actual severity of the state.
- Keep websocket recovery, cached rendering, and navigation behavior unchanged unless required to support the presentation policy.
- Align app-level and chat-level connection-status UX so users do not see contradictory or duplicated severity states.
- Add clear verification coverage for recent-resume suppression and sustained-disconnect escalation behavior.

**Non-Goals:**
- Rebuild websocket transport, heartbeat, or reconnect backoff logic.
- Introduce a new backend API or websocket protocol for this change.
- Block app or chat rendering until realtime reconnect completes.
- Replace the cache-first chat architecture with a hard online-only gating model.
- Solve every offline scenario in the product beyond the resume/refocus banner experience.

## Decisions

### D1: Treat resume/refocus as a temporary reconnect grace window

**Decision:** Add a small shared “recent reconnect recovery” window that starts when the app returns to foreground, the current client regains focus/visibility, or a notification/chat entry triggers likely websocket recovery.

**Why:** These are the exact moments where short websocket disruption is expected and should not immediately be presented as a user-visible error.

**Alternatives considered:**
- Keep banner behavior purely state-based from websocket status. Rejected because websocket state alone does not distinguish normal resume churn from persistent failure.
- Disable banners entirely during reconnect. Rejected because persistent failures still need a visible fallback.

### D2: Escalate banner severity in stages instead of immediately showing a hard failure

**Decision:** Use staged presentation:
- no banner during the initial grace period,
- optional soft reconnect messaging after the grace window while recovery is still in progress,
- hard offline/error messaging only after reconnect remains unresolved beyond the defined threshold.

**Why:** Most resume reconnects are brief. Staged escalation preserves signal for real failures without punishing the common fast-recovery path.

**Alternatives considered:**
- Show only a spinner/connecting banner immediately. Rejected because even “connecting” noise at every resume still makes the app feel laggy.
- Keep the current red banner but shorten copy. Rejected because the severity and timing, not just wording, are the main UX problem.

### D3: Separate transport-recovery messaging from confirmed internet-loss messaging

**Decision:** The UI should not label every websocket disconnect as “internet lost.” Persistent transport problems may still use connection-loss wording, but transient reconnect states must use softer, transport-specific language.

**Why:** A websocket reconnect during resume is not equivalent to proven device offline status. Mislabeling transport churn as network failure makes the app appear broken.

**Alternatives considered:**
- Continue using the current “Mất kết nối mạng” copy for all non-connected states. Rejected because it overstates the problem and trains users to distrust the app.

### D4: Centralize recent-resume presentation policy so app-shell and chat banners stay aligned

**Decision:** Introduce shared decision helpers or a small shared state source for whether severe offline presentation is allowed, then apply that consistently to the app-level banner and chat-level banner.

**Why:** The current inconsistency exists because app-shell and chat-shell banners implement different timing rules. Centralizing the policy reduces drift and duplicated heuristics.

**Alternatives considered:**
- Patch only `_ConnectionStatusBanner` in `app.dart`. Rejected because chat-level UX would still be governed by a separate policy and could diverge again.
- Remove the chat-level banner entirely. Rejected because room-scoped connection feedback can still be useful once severity rules are consistent.

### D5: Preserve existing reconnect triggers and cache-first interaction paths

**Decision:** Keep `ensureConnected()`, `onNetworkRestored()`, room-entry recovery, notification-tap recovery, and cache-first rendering as they are conceptually, layering the banner policy on top.

**Why:** The user complaint is primarily about perceived lag and false alarms, not a request to redesign reconnect mechanics that are already partially in place.

**Alternatives considered:**
- Solve the issue by aggressively reconnecting earlier and leaving UI unchanged. Rejected because even healthy reconnects will still flash visible failure states without a presentation fix.

## Risks / Trade-offs

- [Risk] A long grace window could hide a real outage for too long. -> Mitigation: keep the suppression window short and escalate deterministically once exceeded.
- [Risk] App-level and chat-level banners could still drift if each keeps custom timing. -> Mitigation: route both through shared recent-resume / severity decision helpers.
- [Risk] Platform lifecycle timing differs between mobile foregrounding and web visibility regain. -> Mitigation: define the policy around shared “focus returned / reconnect likely” semantics and cover both paths in tests where feasible.
- [Risk] Softer messaging may reduce urgency during true failures. -> Mitigation: reserve strong color/copy for sustained disconnect only, not remove it completely.
- [Risk] Duplicate reconnect triggers may overlap with the new grace window and complicate tests. -> Mitigation: keep reconnect triggering logic unchanged and test the banner policy as a separate decision layer where possible.

## Migration Plan

1. Introduce a shared recent-resume / reconnect-grace policy that can be driven by lifecycle and entry events.
2. Update the app-level connection banner to suppress immediate hard-failure UI during the grace window and escalate only after sustained failure.
3. Align the chat-level offline banner with the same presentation policy so room-scoped feedback follows the same severity thresholds.
4. Add focused tests for recent-resume suppression, staged reconnect messaging, and hard-failure fallback after the grace window.
5. Manually verify resume flows on mobile and web: foreground return, tab visibility regain, and notification/chat re-entry.

Rollback: revert to the previous immediate banner logic in the app shell and chat banner if the new grace policy hides important failures or causes confusing state transitions.

## Open Questions

None. The key product decision is already clear: short reconnect churn after resume/refocus should not immediately present as a severe offline error.
