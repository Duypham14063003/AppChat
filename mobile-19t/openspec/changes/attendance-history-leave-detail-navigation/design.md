## Context

The HR attendance history screen combines attendance records and approved leave-derived records into a single day list. The leave rows already contain the `LeaveRequest` object needed to identify the underlying leave request, but the current UI renders them as static `ListTile`s with no tap handler.

The app already has a leave detail route at `/hr/leaves/:id`, and the leave list screen uses that route with `extra: leave` so the detail screen can render without issuing another fetch. This change should align attendance-history behavior with that established leave-list navigation pattern.

## Goals / Non-Goals

**Goals:**
- Let users open leave request details by tapping leave-derived entries in attendance history.
- Reuse the existing leave detail route and payload pattern already used elsewhere in HR flows.
- Keep the change scoped to leave-derived entries so attendance rows keep their current behavior.
- Add verification coverage for the new navigation behavior.

**Non-Goals:**
- Redesign the attendance history layout or introduce a new leave detail screen.
- Change which leave requests appear in attendance history.
- Add new APIs or background fetching logic for leave detail.

## Decisions

### D1: Reuse the existing leave detail route instead of creating a history-specific detail screen

**Decision:** Tapping a leave-derived attendance-history row will navigate to `/hr/leaves/:id`.

**Why:** The route already exists, is consistent with the leave list flow, and avoids duplicating leave detail UI.

**Alternatives considered:**
- Create a new detail screen under the attendance-history route tree. Rejected because it duplicates an existing destination for the same entity.
- Show a modal bottom sheet with leave details. Rejected because it introduces a second presentation pattern for the same leave request data.

### D2: Pass the selected `LeaveRequest` via router `extra`

**Decision:** Attendance history will pass the selected leave object as `extra` during navigation.

**Why:** `LeaveDetailScreen` currently expects `leaveData` to render immediately, and showing the empty-state fallback would be a regression when the row already has the full leave payload.

**Alternatives considered:**
- Navigate with only `leaveId` and let detail fetch data later. Rejected because the current detail screen does not fetch by id and would render "No leave data."
- Refactor leave detail to always fetch server data. Rejected because it broadens the scope beyond this navigation fix.

### D3: Keep non-leave rows unchanged

**Decision:** Only leave-derived rows become tappable; attendance check-in/out rows remain informational.

**Why:** The user request is specifically about leave request detail access, and attendance records do not map to the same detail entity.

**Alternatives considered:**
- Make every row interactive for consistency. Rejected because there is no corresponding attendance-detail destination in the current flow.

## Risks / Trade-offs

- [Risk] Users may not realize only leave rows are tappable if the visual affordance is too subtle. → Mitigation: add a standard interaction affordance such as ripple behavior and/or trailing chevron.
- [Risk] Future callers could navigate to leave detail without `extra`, causing the existing empty state. → Mitigation: keep this change aligned with the existing leave-list pattern and cover the new route usage in tests.
- [Risk] Leave data shown in history could be slightly stale compared with server state. → Mitigation: accept the existing cache-backed payload for immediate rendering and keep this change scoped to navigation, not data refresh architecture.

## Migration Plan

1. Update attendance-history leave row rendering to expose a tap action.
2. Route leave-row taps to the existing leave detail screen with the selected leave request payload.
3. Add tests covering leave-row navigation and unchanged attendance-row behavior.
4. Manually verify the leave entry opens the expected detail screen from the attendance history UI.

**Rollback:** Revert the attendance-history tap handler and visual affordance changes to return leave rows to read-only list items.

## Open Questions

None.
