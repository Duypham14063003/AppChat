## Why

Users can currently enter the app immediately after authentication even when their profile does not have a phone number. The product now requires a phone number to be collected at first entry so downstream communication and profile completeness rules are enforced consistently.

## What Changes

- Call `GET /api/v1/config` immediately after a successful authenticated app bootstrap and after interactive login completes.
- Block normal app entry when the config response returns `phone_number: null` and require the user to provide a phone number in a modal flow.
- Allow the required phone number prompt to update the current user profile and clear the block once the number is saved successfully.
- Surface the saved phone number in the profile experience so the user can verify and update it later.

## Capabilities

### New Capabilities
- `user-bootstrap-config`: Load authenticated bootstrap config for the current user and enforce required phone-number completion before normal app use.

### Modified Capabilities
- `flutter-auth-flow`: Extend post-login and post-refresh bootstrap so authenticated entry is not considered complete until required profile config has been checked.

## Impact

- Affected mobile auth bootstrap flow in Riverpod auth state handling and first-entry UX.
- Affected profile editing flow because phone number must be writable from the app.
- Relies on authenticated `GET /api/v1/config` and profile update support for `phone_number`.
