## ADDED Requirements

### Requirement: iOS attendance location usage is declared for App Store submission
The system SHALL declare the iOS privacy purpose strings required for the app's attendance-related location access so that builds referencing location APIs remain eligible for App Store submission.

#### Scenario: iOS bundle references foreground location access
- **WHEN** the mobile app includes the attendance GPS flow that requests the device's current location on iOS
- **THEN** `Runner/Info.plist` includes `NSLocationWhenInUseUsageDescription` with text that explains the attendance check-in and check-out purpose to the user

#### Scenario: App Store validation inspects linked location APIs
- **WHEN** App Store Connect analyzes an uploaded iOS build that links the current location-access dependency stack
- **THEN** the app bundle includes the location usage description keys required for that linked iOS location access

### Requirement: iOS location declaration stays aligned with the current attendance scope
The system SHALL keep iOS location permission metadata and configuration aligned with the app's current foreground attendance GPS behavior and SHALL NOT imply broader background-tracking intent without an explicit feature change.

#### Scenario: Attendance captures location on user action
- **WHEN** the app captures GPS coordinates only during user-initiated attendance actions
- **THEN** the iOS permission declaration and related configuration describe that foreground attendance use case rather than unrelated background tracking behavior

#### Scenario: iOS location configuration is reviewed during the fix
- **WHEN** the location permission submission issue is resolved
- **THEN** the implementation verifies whether additional iOS location scope configuration is necessary and narrows it when the app does not require broader access
