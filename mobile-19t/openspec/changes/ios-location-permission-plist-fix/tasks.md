## 1. iOS privacy metadata

- [x] 1.1 Add the required iOS location usage description keys to `apps/mobile/ios/Runner/Info.plist` with attendance-specific copy.
- [x] 1.2 Verify the declared location-purpose text matches the current attendance check-in and check-out GPS flow.

## 2. iOS permission scope review

- [x] 2.1 Review the current `geolocator` iOS configuration and narrow any unnecessary broader location scope if the app only needs foreground attendance GPS access.
- [x] 2.2 Update iOS build configuration files if needed so the shipped app metadata stays aligned with the foreground-only attendance use case.

## 3. Verification

- [x] 3.1 Confirm the expected location usage keys are present in the iOS bundle inputs after the change.
- [ ] 3.2 Rebuild or validate the iOS submission path and verify the App Store Connect warning is resolved for the next upload.
