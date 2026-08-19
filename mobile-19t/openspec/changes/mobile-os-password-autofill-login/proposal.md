## Why

The mobile login flow currently requires users to type their email and password manually every time they need to re-authenticate. Supporting operating-system password managers lets users reuse saved credentials with Face ID, Touch ID, or Android biometrics without the app storing raw passwords itself.

## What Changes

- Update the Flutter login form so the email and password fields participate in OS-managed autofill flows.
- Finish the autofill context after successful login so iOS Keychain and Android password managers can offer to save or update credentials.
- Define platform integration expectations for iOS and Android so biometric-protected credential filling works when the device supports it.
- Keep the existing backend login API and secure token storage flow unchanged.

## Capabilities

### New Capabilities
- `flutter-login-credential-autofill`: Allow the mobile login experience to integrate with OS password managers so users can select saved credentials and unlock them with device biometrics when available.

### Modified Capabilities
- `flutter-auth-flow`: Extend the login screen requirements so the primary email/password form supports credential autofill without changing the existing login API contract.

## Impact

- Affected Flutter login UI in `apps/mobile/lib/features/auth/screens/login_screen.dart`.
- Affected mobile platform configuration for iOS password autofill readiness and Android autofill compatibility.
- No backend API changes; existing `/auth/login`, token persistence, and refresh-based auto-login remain in place.
