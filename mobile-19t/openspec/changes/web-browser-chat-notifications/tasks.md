## 1. Web Notification Service

- [x] 1.1 Add a web-capable notification service abstraction for browser permission checks and browser notification display.
- [x] 1.2 Keep the existing native local notification behavior unchanged while routing web to the browser-specific implementation.

## 2. Foreground Chat Routing

- [x] 2.1 Wire incoming foreground chat events on web to the browser notification service from the existing app-level notification flow.
- [x] 2.2 Reuse active-conversation suppression and recent-message de-duplication so web notifications follow the same eligibility rules as native foreground alerts.

## 3. Verification

- [x] 3.1 Add automated coverage for web permission handling, notification suppression, and foreground de-duplication decisions.
- [ ] 3.2 Run manual web QA for permission-granted, permission-denied, active-conversation suppression, and different-conversation notification display.
