## Context

The attendance history screen combines attendance session records with leave-derived records. It currently builds leave-derived calendar markers and list entries from all leave records returned by `/hr/leaves` as long as they overlap the selected month, regardless of whether each leave or OT request is approved.

That behavior makes the history screen inaccurate for historical tracking because pending, rejected, or draft leave requests appear alongside actual attendance outcomes. The code already distinguishes leave-derived records from attendance-derived records, so the change can stay scoped to the leave-record preparation path.

## Goals / Non-Goals

**Goals:**
- Ensure leave-derived calendar markers in attendance history only reflect approved leave and approved OT requests.
- Ensure leave-derived entries in the attendance history detail list only reflect approved leave and approved OT requests.
- Preserve attendance session records and OT-hours chips derived from attendance records.

**Non-Goals:**
- Changing the leave list screen or leave detail screen status behavior.
- Modifying backend leave approval workflows or API contracts.
- Reinterpreting attendance-record OT hours as leave requests.

## Decisions

### Decision: Filter leave records at the provider layer

The `attendanceCalendarProvider` should filter monthly leave records by both date overlap and `status == approved` before passing them to the screen. This keeps the calendar marker builder and day-entry builder aligned because they both consume the same filtered `leaveRecords` collection.

Why this over UI-only filtering:
- One filtering rule at the data-preparation layer avoids duplicated status checks in multiple widget helpers.
- It guarantees consistent behavior between the calendar and the list panel.

Alternatives considered:
- Filter only in `_buildLeaveDays()`. Rejected because list entries would still show non-approved items.
- Filter only in `_buildDayEntries()`. Rejected because calendar markers would still show non-approved items.

### Decision: Treat approved OT requests the same as approved leave records in attendance history

The attendance history screen already renders OT requests from `leaveRecords` using the leave-type branch. This change should keep that behavior, but only for approved OT requests.

Why this over a separate OT-only rule:
- The current screen model already groups leave and OT requests under the same leave-derived dataset.
- The user requirement explicitly targets both leave days and OT requests by approval status.

## Risks / Trade-offs

- [Filtering only on exact string `approved`] → Mitigation: rely on the existing status labels and colors already keyed by `approved`; if backend status values change, the same issue would affect multiple HR screens and should be handled consistently.
- [Future requirements may want pending requests visible in a different style] → Mitigation: keep the filter isolated in the provider so the rule can be adjusted centrally later.
- [Confusion between OT requests and attendance-record OT hours] → Mitigation: leave attendance-derived OT-hour rendering untouched and document that only leave-derived OT requests are filtered here.

## Migration Plan

No migration is required. The change is client-side only:
- update leave-record filtering for the attendance history provider
- verify calendar markers no longer show non-approved leave/OT requests
- verify the day detail list no longer shows non-approved leave/OT requests

Rollback is a standard client rollback to the previous mobile build if needed.

## Open Questions

- None for implementation, assuming the leave API continues to return the existing `status` field values such as `approved`, `submitted`, `draft`, and `rejected`.
