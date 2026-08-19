# Mobile OS Password Autofill QA Notes

- iOS Password AutoFill readiness assumes the app will use `webcredentials:api-mobile.19t.vn`.
- The `api-mobile.19t.vn` host must serve a valid `apple-app-site-association` file for the production bundle identifier `vn.19t.nineteenTechApp`.
- If the real credential-sharing domain differs from `api-mobile.19t.vn`, update `apps/mobile/ios/Runner/Runner.entitlements` before release testing.
- Android does not require app-managed password storage for this change; QA should verify autofill with the device's configured password manager and standard Autofill Framework support enabled.
- Expected manual QA coverage:
  - Manual login still succeeds when autofill is disabled.
  - Successful login can offer save or update in the device password manager.
  - A saved credential can be selected and submitted through the existing login form.
