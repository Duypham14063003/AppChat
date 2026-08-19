## Context

The mobile app uses `geolocator` inside the HR attendance flow to capture the device's current position during check-in and check-out. On iOS, App Store Connect inspects both linked privacy-sensitive APIs and the app bundle metadata, and the current `Runner/Info.plist` does not include the required location usage description strings. The result is an `ITMS-90683` submission warning for both `NSLocationWhenInUseUsageDescription` and `NSLocationAlwaysAndWhenInUseUsageDescription`.

The implementation is expected to stay local to iOS packaging and permission declarations. The attendance feature already uses foreground position capture only, so this change should avoid introducing broader location scope unless required by the linked plugin configuration.

## Goals / Non-Goals

**Goals:**
- Add the iOS privacy purpose strings required for the app's current location access behavior.
- Make the declared reason match the attendance GPS use case that already exists in the app.
- Review iOS geolocator configuration so the binary does not imply a wider location permission scope than necessary.
- Provide a clear verification path for future App Store uploads.

**Non-Goals:**
- Redesign the attendance UX or change how GPS coordinates are captured in the HR flow.
- Add background location tracking or geofencing behavior.
- Change Android permission handling.
- Refactor unrelated iOS privacy declarations outside the location issue reported by App Store Connect.

## Decisions

### D1: Add explicit iOS location purpose strings in `Runner/Info.plist`

**Decision:** Add both missing location usage description keys to `apps/mobile/ios/Runner/Info.plist` with copy that explicitly references attendance check-in and check-out.

**Why:** App Store Connect validates the presence of human-readable privacy purpose strings for sensitive APIs referenced by the app bundle. Since the app already asks for location during attendance actions, the most direct and compliant fix is to declare that reason in the plist.

**Alternatives considered:**
- Remove `geolocator` usage from the attendance flow. Rejected because it changes product behavior and is outside the bug scope.
- Add generic privacy text unrelated to attendance. Rejected because App Review copy should match the actual feature behavior.

### D2: Treat foreground attendance capture as the intended permission scope

**Decision:** Preserve the current foreground-only GPS behavior as the design baseline and inspect iOS configuration for any unnecessary `Always` scope exposure.

**Why:** The current Dart implementation uses `getCurrentPosition()` on user action and does not implement background location features. The iOS metadata and pod configuration should reflect that narrow scope where possible.

**Alternatives considered:**
- Intentionally keep broad iOS location scope without review. Rejected because it increases review risk and mismatches the current feature set.
- Introduce a new background-location requirement. Rejected because no existing behavior needs it.

### D3: Verify compliance through artifact-level and bundle-level checks

**Decision:** Verify the fix by checking the plist keys, reviewing any relevant iOS plugin configuration, and confirming the resulting binary metadata is ready for the next upload.

**Why:** This issue comes from packaging metadata rather than application logic alone, so verification should include both source changes and the iOS configuration path that feeds the shipped app bundle.

**Alternatives considered:**
- Rely only on code review without checking final iOS metadata inputs. Rejected because this class of bug often survives unless the bundle-facing files are explicitly verified.

## Risks / Trade-offs

- [Risk] Adding the plist strings alone may satisfy upload validation but still leave the app declaring broader location scope than intended. → Mitigation: review `geolocator` iOS configuration and narrow it if the plugin setup currently implies `Always` access.
- [Risk] Permission copy may be too vague for App Review. → Mitigation: keep the text specific to attendance check-in and check-out.
- [Risk] Future developers may reintroduce the issue when changing iOS permissions or plugins. → Mitigation: add implementation tasks and verification notes that call out the exact files and expected keys.

## Migration Plan

1. Add the missing location usage descriptions to the iOS `Info.plist`.
2. Review and, if needed, tighten iOS plugin or pod configuration so the app reflects foreground attendance GPS usage only.
3. Rebuild the iOS app and verify the bundle inputs used for App Store submission.
4. Re-upload the next binary to App Store Connect.

**Rollback:** Revert the plist and iOS configuration changes if they cause unexpected permission regressions, then restore a compliant submission path with revised copy or configuration in a follow-up change.

## Open Questions

None. The required iOS metadata gap and the app's current foreground attendance GPS usage are already clear from the codebase and App Store warning.
