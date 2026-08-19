## Why

HR staff currently have to leave the employee directory to review an employee's attendance, even though the system already exposes payroll-cycle attendance details. Employee payment profiles also store only free-text bank details, so they cannot reliably produce or manage a scannable transfer QR.

## What Changes

- Replace the unused employee-detail history placeholder with a payroll-cycle attendance tab for authorized HR users.
- Reuse the existing employee payroll summary and attendance audit data to show actual working days, check-in/check-out sessions, excluded sessions, and related leave orders without introducing a second working-day calculation.
- Add normalized bank code and account-holder data to employee payment profiles while retaining the existing bank name and account number fields for compatibility.
- Generate a VietQR-compatible transfer QR preview when a supported bank and account number are present.
- Allow employees to edit their own bank payment details and upload, replace, remove, or stop using a custom QR image; allow authorized HR users to manage the same data on an employee's behalf.
- Prefer the selected custom QR image for display while retaining an explicit way to return to the generated QR.
- Validate and store uploaded QR images through authenticated employee-profile endpoints with bounded image types and file sizes.
- Align employee attendance and bank-profile authorization across admin, manager, and configured HR-manager roles.

## Capabilities

### New Capabilities

- `employee-attendance-view`: Authorized HR users can review an individual employee's payroll-cycle working-day summary and attendance audit from the employee detail screen.
- `employee-bank-qr`: Employees and authorized HR users can maintain normalized bank payment details, receive a generated transfer QR, and manage an optional uploaded QR image.

### Modified Capabilities

<!-- No baseline capabilities currently exist under openspec/specs. -->

## Impact

- Flutter employee detail, employee profile editor, routing, Riverpod providers, HR repository/models, responsive attendance calendar reuse, image selection/upload, and widget/provider/repository tests under `mobile-19t/apps/mobile`.
- NestJS employee profile entity, DTOs, authorization helpers, employee controller/service, static upload handling, migrations, and HR service/controller tests under `backend-mobile-19t`.
- Reuses `GET /hr/reports/payroll-summary` and the completed-attendance behavior from the active `fix-employee-dropdown-and-working-days` change; the conflicting `hr-working-days-display` rule must not be used for this view.
- Adds persistent employee bank metadata and uploaded QR image metadata, plus a QR rendering/generation dependency or an equivalent project-owned encoder.
- Existing employee profiles and API clients remain compatible because all new fields are nullable and additive.
