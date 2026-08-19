## ADDED Requirements

### Requirement: Chat push payload includes the real unread badge total
The system SHALL calculate the recipient user's total unread chat count and include that total in chat push notifications instead of sending a fixed badge value.

#### Scenario: iOS chat push carries unread total
- **WHEN** a chat push notification is sent to a user who has 7 total unread chat messages
- **THEN** the APNs payload includes `badge: 7` instead of a fixed `1`

#### Scenario: Android chat push carries unread total in data payload
- **WHEN** a chat push notification is sent to a user who has 3 total unread chat messages
- **THEN** the push data payload includes `badge_count: "3"`

### Requirement: Mobile badge state stays aligned with unread chat state
The system SHALL update the mobile app icon badge to reflect the current unread chat total after notification delivery and after unread state changes caused by reading messages.

#### Scenario: Badge updates on incoming unread message
- **WHEN** a new unread chat notification arrives
- **THEN** the mobile app icon badge updates to the unread total provided by the notification flow

#### Scenario: Badge decreases after messages are read
- **WHEN** the user reads messages and the unread chat total becomes lower than the current badge
- **THEN** the app icon badge is updated to the lower unread total

### Requirement: Badge clears only when unread chat total reaches zero
The system SHALL clear the mobile app icon badge only when the user has no remaining unread chat messages.

#### Scenario: All unread messages have been read
- **WHEN** the user's unread chat total becomes `0`
- **THEN** the app icon badge is set to `0`

#### Scenario: App opens while unread messages still exist
- **WHEN** the user opens the app but still has unread chat messages
- **THEN** the app icon badge remains aligned to the non-zero unread total instead of being cleared blindly
