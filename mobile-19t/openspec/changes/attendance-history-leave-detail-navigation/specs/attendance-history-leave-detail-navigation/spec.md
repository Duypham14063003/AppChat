## ADDED Requirements

### Requirement: Attendance history leave entries SHALL open leave request details
The system SHALL allow users to navigate from a leave-derived entry in attendance history to the existing leave request detail screen.

#### Scenario: User taps a leave-derived row in attendance history
- **WHEN** the attendance history day list shows a leave-derived entry and the user taps that row
- **THEN** the app SHALL navigate to the leave detail route for that leave request

### Requirement: Attendance history SHALL provide leave detail payload during navigation
The system SHALL pass the selected leave request data when routing from attendance history so the leave detail screen can render the chosen request immediately.

#### Scenario: Leave detail opens from attendance history
- **WHEN** the user opens leave detail from a leave-derived attendance-history row
- **THEN** the app SHALL pass the selected `LeaveRequest` as navigation payload and the detail screen SHALL render that request without a missing-data empty state

### Requirement: Attendance history attendance rows SHALL keep their existing non-navigation behavior
The system SHALL keep regular attendance check-in/out rows informational only when adding leave-detail navigation.

#### Scenario: User taps a check-in or check-out row
- **WHEN** the attendance history day list shows a regular attendance record row
- **THEN** the app SHALL NOT navigate to the leave detail route for that row
