# Employee Attendance and Bank QR Deployment

## Deployment order

1. Verify and deploy the completed-attendance payroll summary from `fix-employee-dropdown-and-working-days`. Do not deploy the superseded calculation from `hr-working-days-display` into the employee attendance tab.
2. Back up the database and run migration `1716800000000-EmployeeBankQr`. Its four new employee-profile columns are nullable and preserve legacy bank name/account values.
3. Deploy the NestJS API. Confirm the runtime can write `uploads/hr/payment-qr`, the authenticated image endpoint can read it, and persistent storage includes the deployment's configured uploads root.
4. Deploy the Flutter client with the versioned bank registry and local VietQR renderer.
5. Smoke-test admin, manager, configured HR manager, employee self-service, and denied cross-user access.

## Rollback

- Roll back the Flutter client first; the additive API and columns remain compatible with older clients.
- Roll back the API next. Keep the nullable columns while any new client remains active.
- Only run the migration `down` after new clients are retired and exported payment QR metadata is no longer needed. The down migration does not remove existing `bank_name` or `bank_account_number` values.
- Uploaded files are not removed by the database migration. Clean `uploads/hr/payment-qr` separately after confirming no profile references remain.

## Upload lifecycle

- Payment QR files are excluded from public static upload mounts. Clients load them through the authenticated self-or-HR employee image endpoint; legacy stored URLs are normalized to that protected endpoint in profile responses.
- Accepted formats: JPEG, PNG, WebP; maximum size: 5 MiB.
- Replacements and removals attempt to delete the superseded local file after the profile update succeeds.
- Cleanup failures are logged and do not roll back valid profile metadata. Deletion is restricted to the managed payment-QR directory.
- The uploads directory must use durable shared storage in multi-instance deployments.

## Bank registry maintenance

- The Flutter registry version is declared in `VietQrBanks.version`.
- Refresh supported bank code/BIN mappings from the VietQR bank registry, review transfer support, update the version date, and rerun deterministic payload tests.
- Generated QR payloads contain recipient bank/account only. They intentionally omit amount and transfer message and are rendered locally without sending account data to an image service.
