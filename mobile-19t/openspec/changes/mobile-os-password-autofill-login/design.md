## Context

The current mobile authentication flow uses a plain email/password login form, sends credentials to `POST /auth/login`, and persists only access and refresh tokens in `flutter_secure_storage`. This is a good base for security because the app does not currently store raw passwords, but it also means users must manually re-enter credentials whenever they are logged out or move to a new device state where tokens are unavailable.

This change introduces operating-system-managed credential autofill for the existing login form. The key constraint is preserving the current security model: the app should not add its own password vault or biometric secret store. Instead, the login screen should advertise username/password semantics to iOS Keychain and Android password managers, then let those platform services handle saved credentials and biometric unlock when available.

## Goals / Non-Goals

**Goals:**
- Let the existing Flutter login form participate in native credential autofill flows.
- Ensure successful logins can trigger OS-managed save/update credential prompts.
- Preserve the current `/auth/login` API contract and secure token bootstrap behavior.
- Define the platform readiness required for iOS and Android to deliver a reliable autofill experience.

**Non-Goals:**
- Storing raw passwords in app-managed storage.
- Building a custom Face ID or fingerprint gate inside the app before login.
- Replacing token-based auto-login with a biometric-only authentication flow.
- Changing backend authentication endpoints, token rotation, or session semantics.

## Decisions

### 1. Use OS-managed autofill instead of app-managed password storage
The login form should integrate with iOS Keychain and Android password managers through Flutter autofill APIs rather than storing credentials locally in app code.

Why:
- It keeps password handling inside platform-managed secure systems.
- It aligns with the desired UX: users can unlock saved credentials with Face ID, Touch ID, or Android biometrics when their device/password manager supports it.
- It avoids introducing a second secret-storage path beyond the existing token storage.

Alternatives considered:
- Save email/password in `flutter_secure_storage`: rejected because it makes the app responsible for raw credential protection and lifecycle management.
- Build custom biometric encryption around stored passwords: rejected because it adds security-sensitive complexity without improving the backend contract.

### 2. Treat autofill as an enhancement to the existing login form, not a new auth mode
The login screen should keep the same email/password submission flow while advertising autofill metadata for the fields and finishing the autofill context after a successful login.

Why:
- The login API already expects email and password, so autofill can layer onto the current UX cleanly.
- The backend and auth notifier logic do not need to distinguish typed credentials from autofilled ones.

Alternatives considered:
- Add a separate “Login with Face ID” button: rejected because the app has no biometric credential exchange with the server, so the actual login still depends on email/password.
- Create a dedicated re-auth sheet just for autofill: rejected because it duplicates the existing login form.

### 3. Scope platform work to readiness for native password managers
Implementation should include the Flutter login form changes plus any required iOS project configuration so password autofill can associate saved credentials correctly. Android should rely on Autofill Framework compatibility through Flutter field metadata unless testing reveals a platform-specific blocker.

Why:
- iOS often needs explicit project capability setup for the strongest password-manager behavior.
- Android usually works through standard autofill hints and the user’s installed password manager, so the design should not assume extra custom plumbing unless verification proves it necessary.

Alternatives considered:
- Define a custom mobile-only credential provider integration: rejected because OS password managers are already the intended source of truth.
- Require equal platform configuration depth up front on both platforms: rejected because the native requirements differ.

### 4. Keep token storage and post-login bootstrap unchanged
This change should stop at credential entry and save/update flows. After login succeeds, the current token storage, refresh flow, and authenticated bootstrap behavior should continue exactly as they do today.

Why:
- Credential autofill and token lifecycle solve different problems.
- Keeping those concerns separate minimizes regression risk in auth bootstrap and session management.

Alternatives considered:
- Refactor auth bootstrap together with autofill: rejected because it broadens the blast radius without product need.

## Risks / Trade-offs

- [Platform behavior differs across devices and password managers] → Mitigation: define manual verification on iOS and Android separately, including first-save and re-use flows.
- [iOS autofill may require missing entitlements or associated-domain configuration] → Mitigation: include explicit platform readiness work and verify on a physical iPhone.
- [Users may expect a dedicated “Face ID login” button] → Mitigation: keep product copy focused on saved-password autofill rather than promising a new authentication method.
- [Autofill UI may not appear when the user has no saved credentials] → Mitigation: preserve the existing manual login path with no dependency on autofill availability.

## Migration Plan

1. Update the proposal-linked specs for login autofill behavior and the adjusted auth-flow requirement.
2. Add Flutter login-form autofill semantics and successful autofill-context completion.
3. Add any required iOS project configuration for credential autofill readiness.
4. Verify first-time save, subsequent autofill, failed login, and manual-entry fallback flows on supported devices.

Rollback:
- Remove the autofill metadata and autofill-context completion from the login screen.
- Revert any iOS project configuration added specifically for password autofill.
- Leave token storage and backend auth untouched.

## Open Questions

- Does the deployed iOS app bundle already have the associated-domain configuration needed for the desired Keychain autofill experience?
- Should the product copy explicitly mention password-manager autofill availability on the login screen, or should the experience remain implicit?
- Do we want to support password-manager save/update prompts only after successful login, or also after a known credential-change flow in the future?
