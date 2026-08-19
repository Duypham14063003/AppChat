## 1. Flutter Login Autofill Semantics

- [x] 1.1 Wrap the mobile login form in an autofill context group and add appropriate autofill hints for the email/username and password fields.
- [x] 1.2 Preserve the existing manual validation and submit behavior while allowing autofilled credentials to use the same login flow.
- [x] 1.3 Finalize the autofill context after successful login so the OS password manager can offer save/update actions.

## 2. Platform Readiness

- [x] 2.1 Review and add any required iOS project configuration for Password AutoFill / associated-domain readiness.
- [x] 2.2 Confirm the Android login form remains compatible with standard Autofill Framework behavior without introducing app-managed password storage.
- [x] 2.3 Document any environment or entitlement assumptions needed for QA to verify password-manager autofill behavior.

## 3. Verification

- [x] 3.1 Verify manual login still works when autofill is unavailable or disabled.
- [ ] 3.2 Verify a successful login can trigger save/update credential prompts on supported devices.
- [ ] 3.3 Verify a saved credential can be selected and used to log in through the existing `/auth/login` flow.
