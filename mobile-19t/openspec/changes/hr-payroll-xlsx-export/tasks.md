## 1. Backend Payroll Export Contract

- [x] 1.1 Add a dedicated HR payroll export endpoint in `/Users/phamngocduy/Documents/CTY/19t/mobile-19t/backend-mobile-19t/src/modules/hr` that accepts a payroll month and returns an `.xlsx` attachment.
- [x] 1.2 Align export authorization with HR approver behavior so `admin` and `manager` can access the export flow and supporting cross-user payroll aggregation.
- [x] 1.3 Add the backend workbook dependency and isolate `.xlsx` generation behind a payroll export service.

## 2. Payroll Cycle Aggregation

- [x] 2.1 Implement payroll-month-to-cycle range mapping from payroll configuration so a selected month uses the configured cross-month payroll boundaries.
- [x] 2.2 Build a server-side payroll row aggregation model for active employees only, combining attendance, approved paid leave, approved unpaid leave, approved WFH, approved OT, and absent-without-leave totals.
- [x] 2.3 Map `user.employment_status` to workbook display names, leave the employee note / confirmation / discrepancy columns blank, and keep payroll metric cells numeric.

## 3. Workbook Rendering

- [x] 3.1 Render the payroll aggregation model into a worksheet with the required HR salary-processing headers and deterministic row ordering.
- [x] 3.2 Ensure `TỔNG NGÀY CÔNG TÍNH LƯƠNG` is derived from `CÔNG THỰC TẾ + NGHỈ PHÉP CÓ LƯƠNG` and that decimal values remain numeric spreadsheet cells.
- [x] 3.3 Set workbook response headers so downloaded files use a stable `.xlsx` filename that reflects the selected payroll month.

## 4. Mobile Export Flow

- [x] 4.1 Add an export action to `apps/mobile/lib/features/hr/screens/leave_list_screen.dart` for HR approvers only.
- [x] 4.2 Extend `apps/mobile/lib/features/hr/data/hr_repository.dart` with a binary payroll export request and month parameter handling that matches the backend contract.
- [x] 4.3 Reuse existing platform-specific download/save behavior so web downloads the workbook directly and native platforms save or share the `.xlsx` file.

## 5. Verification

- [x] 5.1 Add backend tests for payroll-cycle date mapping, authorization, active-user filtering, and workbook row totals.
- [x] 5.2 Add mobile tests covering export action visibility and export request wiring for approver and non-approver roles.
- [ ] 5.3 Manually verify that selecting a payroll month such as `07/2026` exports the `.xlsx` workbook for the correct cycle (for example `2026-06-25` through `2026-07-24` when payroll start day is 25).
