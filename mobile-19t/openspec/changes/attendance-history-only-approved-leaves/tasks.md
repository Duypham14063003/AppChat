## 1. Leave Record Filtering

- [x] 1.1 Update `attendanceCalendarProvider` so monthly `leaveRecords` only include leave and OT requests whose status is `approved`.
- [x] 1.2 Keep the existing month-overlap filter intact while applying the new approved-only rule in the same provider path.

## 2. Attendance History Consistency

- [x] 2.1 Verify calendar leave markers in `AttendanceHistoryScreen` are driven only by the filtered approved leave dataset.
- [x] 2.2 Verify the attendance history detail list shows leave-derived rows only for approved leave and approved OT requests.
- [x] 2.3 Preserve attendance-derived entries and OT-hour chips from attendance records without changing their current behavior.

## 3. Verification

- [x] 3.1 Add or update targeted verification for the approved-only leave filtering rule in the attendance history flow.
- [x] 3.2 Run project-appropriate analysis and tests for the affected HR files.
