## Context

The mobile app currently treats authentication as complete once tokens are stored and the authenticated shell is entered. The codebase already has a secure token bootstrap flow in `AuthNotifier`, a login screen that only collects email and password, and a profile editing flow that can update the current user. The new requirement adds an authenticated bootstrap check against `GET /api/v1/config`, which returns `phone_number` for the current user and must gate access when the value is missing.

This change crosses multiple areas: auth bootstrap, app entry UX, and profile update flows. It also depends on a backend endpoint that is distinct from the existing `/users/me` profile payload, so the mobile app must treat config bootstrap as a separate concern from login response parsing.

## Goals / Non-Goals

**Goals:**
- Ensure the app calls authenticated bootstrap config immediately after interactive login and refresh-based auto-login.
- Prevent normal app use when the backend reports `phone_number == null`.
- Provide a mandatory modal flow that lets the user add a phone number and resume app use without logging out.
- Keep the stored authenticated session intact while the phone-number requirement is being completed.
- Reflect the saved phone number in the in-app profile model so the user sees the current value after completing the flow.

**Non-Goals:**
- Changing backend authentication contracts or token semantics.
- Implementing biometric login, OTP verification, or phone verification ownership checks.
- Reworking all profile editing UX beyond what is required to collect and display the phone number.
- Supporting partial app access while the phone number is missing.

## Decisions

### 1. Add a dedicated authenticated bootstrap config fetch after auth success
The app should treat `GET /api/v1/config` as a post-auth bootstrap dependency rather than bundling it into login form code.

Why:
- The requirement applies both after interactive login and after silent refresh on app start.
- `AuthNotifier` already centralizes session establishment and is the narrowest place to ensure both entry paths behave the same way.

Alternatives considered:
- Fetch only inside `LoginScreen`: rejected because silent auto-login would bypass the requirement.
- Fetch lazily inside profile or home screens: rejected because the user could use the app before completing required data.

### 2. Represent missing-phone bootstrap as authenticated-but-blocked state
The app should keep the session authenticated while exposing a state that requires phone-number completion before main navigation is usable.

Why:
- Missing phone number is not an auth failure; logging out would be misleading.
- Keeping auth alive avoids unnecessary re-login and preserves refresh-token semantics.

Alternatives considered:
- Force logout when `phone_number` is missing: rejected as poor UX and semantically incorrect.
- Navigate to the normal home shell and show a dismissible reminder: rejected because the requirement is mandatory.

### 3. Use a mandatory modal completion flow at app-entry level
The phone-number prompt should be presented as a blocking modal/sheet owned by the authenticated shell layer, not embedded inside `LoginScreen`.

Why:
- The prompt may appear after auto-login as well as manual login.
- Central ownership avoids duplicated logic and prevents multiple screens from racing to show the same dialog.

Alternatives considered:
- Push a standalone route before home: workable, but heavier navigation state for a small completion task.
- Embed the prompt in the profile screen: rejected because the user must complete it before normal use.

### 4. Update phone number through the existing profile update path
The mobile app should extend the existing current-user profile update API usage to send `phone_number`, then merge the saved value back into the in-memory auth user model.

Why:
- The codebase already has `updateMe` semantics and profile editing UI patterns.
- This avoids introducing a second update endpoint unless backend forces one.

Alternatives considered:
- Add a dedicated phone-number-only endpoint on mobile: rejected unless backend requires it.
- Store phone number only in a config cache without updating auth user state: rejected because profile UI would become stale.

### 5. Fail closed for missing config only when the backend explicitly reports null
If the config request succeeds and returns `phone_number: null`, the app must block entry. Transport errors should not silently mark the requirement as satisfied.

Why:
- Product intent is to enforce a known missing value.
- Treating network failure the same as “phone number missing” could trap users without actionable feedback, so bootstrap errors need distinct handling.

Alternatives considered:
- Always block on config fetch failure: too aggressive without an offline/error strategy.
- Always allow through on config fetch failure: risks bypassing the requirement indefinitely.

Chosen approach:
- Block on explicit `null`.
- Surface retry/error state if config cannot be loaded, with no false “complete” path until a successful fetch resolves the requirement.

## Risks / Trade-offs

- **Bootstrap complexity increases** → Mitigation: keep config fetch and phone-completion state isolated inside auth/bootstrap concerns instead of scattering checks across feature screens.
- **App-entry modal can feel abrupt** → Mitigation: explain why the phone number is required and focus the modal on one short action.
- **Profile model drift between config and `/users/me` responses** → Mitigation: normalize `phone_number` into the shared `UserInfo` model and update it after successful save.
- **Retry loops or duplicate dialogs during auth refresh** → Mitigation: present the completion modal from a single shell-level coordinator and make bootstrap checks idempotent.
- **Backend update-path mismatch** → Mitigation: confirm whether `/users/me` accepts `phone_number`; if not, adapt the mobile repository to the actual update endpoint before implementation.

## Migration Plan

1. Extend auth repository/model types to fetch bootstrap config and carry `phoneNumber`.
2. Add authenticated bootstrap logic that resolves one of three outcomes: ready, phone required, or retryable error.
3. Add a shell-level blocking modal for missing phone number with validation and submit/retry states.
4. Extend profile update flow to save `phone_number` and refresh auth user state after success.
5. Verify manual login, auto-login, logout, refresh failure, and missing-phone recovery paths on both mobile platforms.

Rollback:
- Remove the bootstrap config gate and phone-required state while keeping login/token handling unchanged.
- The profile phone field can remain harmlessly hidden or ignored if the requirement is rolled back.

## Open Questions

- Does `PATCH /users/me` already accept `phone_number` in the deployed backend, or is a separate update endpoint required?
- Should the blocking modal allow logout as an escape hatch, or must it only allow save/retry?
- What validation format is required for phone numbers beyond non-empty input?
