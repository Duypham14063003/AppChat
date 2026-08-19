## Context

The current chat notification badge flow is broken in two places. On the backend, chat pushes are sent with `badge: 1` hardcoded in the APNs payload, so iOS never receives the real unread total. On the client, there is no clear badge synchronization flow that applies the unread total consistently or clears it when unread state returns to zero.

The codebase already has the building blocks for a correct badge source of truth:
- the backend can calculate unread counts per conversation when building chat list responses
- the mobile app stores unread counts locally per conversation in Drift
- opening a conversation already resets local unread state for that conversation

What is missing is an explicit contract for total unread badge count and a lifecycle that keeps server push payloads and mobile badge state aligned. This change is intentionally focused on chat unread badge correctness and does not include notification center, user preferences, or desktop tray badges.

## Goals / Non-Goals

**Goals:**
- Make chat push payloads include the real total unread chat count instead of a fixed `1`.
- Keep the mobile app icon badge aligned with unread chat state after new notifications and after messages are read.
- Define clear badge reset behavior when unread count reaches zero.
- Add verification coverage for both payload generation and badge sync/clear behavior.

**Non-Goals:**
- Add notification center UI or in-app notification bell badges.
- Change notification grouping, quiet hours, or preference behavior.
- Introduce desktop tray badge support.
- Redesign chat unread-count semantics beyond what is required for correct badge totals.

## Decisions

### D1: Treat the backend as the source of truth for total unread badge count

**Decision:** The backend will calculate the recipient user's total unread chat count at push-send time and include that count in the outbound payload.

**Why:** The server already owns authoritative unread state through conversation membership read markers. Calculating badge totals on the client from partial local state would drift whenever local caches are stale, the app is terminated, or cross-device reads happen.

**Alternatives considered:**
- Let the client sum local unread counts and infer the badge total. Rejected because local caches can be stale and do not help when the app is not running.
- Keep a separate persisted badge counter. Rejected because it duplicates unread state and creates reconciliation problems.

### D2: Send the same unread total through both APNs badge and data payload

**Decision:** For chat pushes, include the computed unread total in `apns.payload.aps.badge` and also include a string `data.badge_count` payload field.

**Why:** iOS needs the APNs badge field for system-level badge updates, while the data payload provides a consistent cross-platform value the client can inspect for foreground handling and Android badge updates.

**Alternatives considered:**
- Only set APNs badge and skip data payload. Rejected because Android and foreground handlers still need the unread total.
- Only send `data.badge_count`. Rejected because iOS badge updates should work even when the app is not actively processing foreground code.

### D3: Clear badge from mobile lifecycle using unread-total checks, not blind app-open resets

**Decision:** The mobile app will clear or update the app icon badge only when it can determine the current unread total, and it will reset to zero only when unread conversations are actually exhausted.

**Why:** Blindly clearing badge on app open would hide unread messages that still exist. Badge clearing should be tied to real unread state transitions, such as after chat-list refresh or after marking conversations read.

**Alternatives considered:**
- Always clear badge when app enters foreground. Rejected because it breaks trust in the badge as an unread indicator.
- Never clear locally and rely only on the next server push. Rejected because badge would remain stale after the user reads messages.

### D4: Scope the client badge implementation to mobile app icon badges

**Decision:** This change targets iOS and Android mobile badge correctness only.

**Why:** The reported bug is mobile-specific, and the current codebase does not yet show a mature desktop tray-badge path. Keeping scope tight reduces cross-platform complexity and gets the broken user experience fixed sooner.

**Alternatives considered:**
- Include Windows/macOS tray badge support now. Rejected because it expands scope into notification-surface work not needed for the current bug.

## Risks / Trade-offs

- [Risk] Push-time unread aggregation could duplicate logic already used in chat list responses. → Mitigation: reuse or extract a shared unread-total calculation path where possible.
- [Risk] Badge may still momentarily lag after read actions until refresh/sync completes. → Mitigation: trigger badge recalculation from existing read/open flows and verify post-read refresh behavior.
- [Risk] Android badge support may vary by launcher/device. → Mitigation: define the expected app-managed behavior in the change and verify on the supported device matrix during implementation.

## Migration Plan

1. Replace hardcoded chat push badge values with computed unread totals on the backend.
2. Include the same unread total in chat notification data payloads for client-side handling.
3. Update mobile notification/read flows to apply and clear app icon badge counts from real unread totals.
4. Add tests for push payload badge generation and mobile badge reset logic.
5. Manually verify badge increment and clear behavior on supported mobile platforms.

**Rollback:** Restore the old fixed badge payload and disable client badge updates if the unread-total synchronization causes severe regressions, though that would reintroduce the current incorrect badge behavior.

## Open Questions

None. The immediate gap is well-defined: badge count must reflect actual unread chat state and clear correctly after reads.
