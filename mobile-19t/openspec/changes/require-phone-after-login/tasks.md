## 1. Auth Bootstrap

- [x] 1.1 Add authenticated bootstrap config fetching for `/api/v1/config` in the auth data layer.
- [x] 1.2 Extend the auth user/bootstrap state to track phone-number readiness separately from authenticated status.
- [x] 1.3 Run the bootstrap config check after interactive login and after refresh-based startup.

## 2. Blocking Phone Completion Flow

- [x] 2.1 Add a shell-level blocking modal or equivalent gated UI for the missing-phone state.
- [x] 2.2 Validate phone-number input and show retryable error states without logging the user out.
- [x] 2.3 Resume normal app use only after the phone number has been saved successfully.

## 3. Profile Update and Display

- [x] 3.1 Extend the current-user profile update flow to submit `phone_number`.
- [x] 3.2 Merge the saved phone number back into authenticated user state after a successful update.
- [x] 3.3 Surface the saved phone number in the profile UI so users can review it later.

## 4. Verification

- [ ] 4.1 Verify manual login with existing phone number skips the blocking prompt.
- [ ] 4.2 Verify manual login and auto-login with missing phone number both block until completion succeeds.
- [ ] 4.3 Verify update failure, retry behavior, and logout/restart flows remain correct.
