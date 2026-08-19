## Context

The attendance history screen (`attendance_history_screen.dart`) currently displays a calendar view with attendance records and leave requests, but lacks a summary of key metrics. Users must manually count days or calculate totals. The backend attendance service already provides a `getSummary()` method that returns `total_days` (unique dates with check-ins), but this needs enhancement to apply business rules and the frontend needs to display this metric.

Current state:
- Backend: `attendance.service.ts` has `getSummary()` that counts unique check-in dates
- Frontend: `attendanceCalendarProvider` fetches attendance and leave records but doesn't fetch or display summary metrics
- The existing `total_days` calculation doesn't distinguish weekdays and doesn't apply the Saturday business rule

Constraint: Saturday is considered a half-day work schedule (4 hours), but for attendance compliance purposes, it should count as a full working day (1.0 day).

## Goals / Non-Goals

**Goals:**
- Display working days count in attendance history screen alongside OT/leave/WFH metrics
- Apply business rule: Monday-Saturday = 1.0 day each, Sunday = 0 days
- Minimal changes to existing attendance calculation logic
- Consistent data structure between backend and frontend

**Non-Goals:**
- Changing how attendance check-in/check-out works
- Modifying leave request calculation or WFH day counting
- Adding admin-level employee comparison views (single user view only)
- Calculating expected vs actual working days (just show actual count)

## Decisions

### Decision 1: Enhance existing getSummary() method vs new endpoint
**Chosen:** Enhance existing `getSummary()` method to return `working_days` field.

**Rationale:** The method already calculates `total_days` (unique dates), and we need the same data with business rules applied. Adding a field is simpler than creating a new endpoint.

**Alternative considered:** Create `/hr/attendance/working-days` endpoint. Rejected because it would duplicate the date range logic and require an additional API call.

### Decision 2: Backend calculation approach
**Chosen:** Filter attendance records by weekday after fetching, count unique dates excluding Sunday.

**Rationale:**
- Simple logic: `weekday !== 0` (Sunday in JavaScript `Date.getDay()`)
- Reuses existing unique date counting pattern
- No database schema changes required

**Alternative considered:** Add weekday calculation in SQL query. Rejected because the performance benefit is negligible for month-range queries, and the logic is clearer in TypeScript.

### Decision 3: Frontend data model structure
**Chosen:** Add `workingDays` to `AttendanceCalendarData` model and aggregate in provider.

**Rationale:** The `attendanceCalendarProvider` already aggregates leave data (OT hours, leave days, WFH days) from the leave records. Working days should follow the same pattern for consistency.

**Data flow:**
```
attendanceCalendarProvider
  ├─ fetch attendance records (API: getHistory)
  ├─ fetch leave records (API: getLeaves)
  ├─ calculate working days from attendance records ← NEW
  └─ return AttendanceCalendarData { attendanceRecords, leaveRecords, workingDays, otHours, leaveDays, wfhDays }
```

**Alternative considered:** Create separate provider for summary metrics. Rejected because it would require duplicate API calls and complicate state management.

### Decision 4: UI placement
**Chosen:** Add summary cards section above the calendar/list split.

**Layout:**
```
┌────────────────────────────────────────────────┐
│  Summary Cards (horizontal scrollable)        │
│  [OT: 76.3h] [Leave: 7.5d] [WFH: 13.5d] [Work: 22d] │
├────────────────────────────────────────────────┤
│  Calendar (left) | List (right)               │
└────────────────────────────────────────────────┘
```

**Rationale:** Users need to see summary before diving into individual records. Placing it at the top provides immediate context.

**Alternative considered:** Summary in app bar or bottom sheet. Rejected because it would hide information or require extra taps.

## Risks / Trade-offs

**Risk:** Confusion between `total_days` (existing field) and `working_days` (new field) in backend response.
→ **Mitigation:** Keep `total_days` for backward compatibility, document clearly that `working_days` applies business rules.

**Risk:** Saturday business rule may change in the future (e.g., some employees work full Saturday, others don't).
→ **Mitigation:** Current implementation uses simple weekday check. If personalization is needed later, add employee-level config. For now, apply uniform rule as specified.

**Risk:** Frontend calculates summary client-side from raw records vs backend returns pre-calculated summary.
→ **Mitigation:** Frontend calculates from fetched data to avoid additional API call. If performance becomes an issue with large datasets, can move to backend endpoint later.

**Trade-off:** UI shows month-level summary only (not date range picker).
→ **Accepted:** Matches existing UI pattern where users navigate by month. Adding date range picker is out of scope.
