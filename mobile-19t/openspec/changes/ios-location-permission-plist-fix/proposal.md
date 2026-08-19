## Why

The iOS app currently requests location access for attendance check-in and check-out through `geolocator`, but the shipped `Info.plist` does not include the required Apple privacy purpose strings. App Store Connect therefore flags the build with `ITMS-90683`, blocking a clean release path until the privacy metadata matches the app's runtime permission usage.

## What Changes

- Add the missing iOS location usage description coverage required for App Store submission.
- Align the permission copy with the existing attendance GPS flow so the declared reason matches the real user-facing behavior.
- Review iOS location permission configuration to avoid declaring broader location intent than the app currently needs.
- Add verification for the plist keys and any iOS configuration needed to keep the submission compliant.

## Capabilities

### New Capabilities
- `ios-location-permission-compliance`: Ensure iOS builds that request attendance-related location access declare the required privacy purpose strings and configuration for App Store submission.

### Modified Capabilities
<!-- None. -->

## Impact

- iOS app metadata: `apps/mobile/ios/Runner/Info.plist`
- iOS build configuration: `apps/mobile/ios/Podfile` and generated pod setup if location scope needs narrowing
- HR attendance GPS flow reference: `apps/mobile/lib/features/hr/providers/hr_providers.dart`
- Flutter dependency behavior: `apps/mobile/pubspec.yaml` (`geolocator`)
