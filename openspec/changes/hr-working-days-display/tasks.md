## 1. Backend - Add working days calculation

- [x] 1.1 Add `working_days` field calculation to `getSummary()` method in `apps/api/src/modules/hr/services/attendance.service.ts`
- [x] 1.2 Filter attendance records to exclude Sunday (weekday === 0) before counting unique dates
- [x] 1.3 Keep existing `total_days` field for backward compatibility
- [x] 1.4 Add unit tests for working days calculation covering Monday-Saturday and Sunday exclusion scenarios
- [x] 1.5 Verify API response includes `working_days` field via manual testing or API tests

## 2. Frontend - Update data models

- [x] 2.1 Add `workingDays`, `otHours`, `leaveDays`, and `wfhDays` fields to `AttendanceCalendarData` class in `apps/mobile/lib/features/hr/data/hr_models.dart`
- [x] 2.2 Update `AttendanceCalendarData` constructor to accept new fields

## 3. Frontend - Update provider to calculate summary

- [x] 3.1 In `attendanceCalendarProvider` (apps/mobile/lib/features/hr/providers/hr_providers.dart), calculate working days from attendance records by counting unique dates excluding Sundays
- [x] 3.2 Calculate total OT hours by summing `ot_time` from approved leave records with type 'ot'
- [x] 3.3 Calculate leave days by summing `requested_days` from approved leave records with types 'annual', 'sick', 'personal'
- [x] 3.4 Calculate WFH days by summing `requested_days` from approved leave records with type 'wfh'
- [x] 3.5 Return updated `AttendanceCalendarData` with all calculated fields

## 4. Frontend - Add summary cards UI

- [x] 4.1 Create `_buildSummaryCards()` method in `attendance_history_screen.dart` that displays horizontal scrollable summary cards
- [x] 4.2 Add summary card for "Tổng giờ OT" displaying `otHours` value
- [x] 4.3 Add summary card for "Tổng ngày nghỉ" displaying `leaveDays` value
- [x] 4.4 Add summary card for "Tổng WFH" displaying `wfhDays` value
- [x] 4.5 Add summary card for "Ngày công thực tế" displaying `workingDays` value
- [x] 4.6 Integrate summary cards section above the calendar/list split in the build method

## 5. Testing and verification

- [ ] 5.1 Run backend tests: `cd apps/api && npm test`
- [ ] 5.2 Run backend linter: `cd apps/api && npm run lint`
- [ ] 5.3 Run Flutter analyzer: `cd apps/mobile && flutter analyze`
- [ ] 5.4 Run build_runner if data models changed: `cd apps/mobile && dart run build_runner build --delete-conflicting-outputs`
- [ ] 5.5 Manual test: verify working days count matches expected value for a sample month (excluding Sundays)
- [ ] 5.6 Manual test: verify summary cards display correctly on both mobile and web layouts
- [ ] 5.7 Manual test: verify summary updates when navigating between months
