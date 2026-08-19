## ADDED Requirements

### Requirement: Resume-triggered reconnect churn SHALL be suppressed before showing severe offline UI
The system SHALL suppress severe connection-loss presentation for a short grace period immediately after the client returns to foreground, regains focus/visibility, or enters chat through a path that commonly triggers websocket recovery.

#### Scenario: App resumes and websocket reconnects quickly
- **WHEN** an authenticated user returns to the app and the websocket is temporarily disconnected or connecting
- **THEN** the system SHALL avoid showing a severe offline banner during the defined grace period

#### Scenario: Web tab regains visibility and reconnect completes within the grace period
- **WHEN** the user returns to a previously hidden web tab and realtime reconnect completes within the grace period
- **THEN** the system SHALL not present a hard connection-loss error to the user

### Requirement: Connection-status presentation SHALL escalate by severity over time
The system SHALL distinguish transient reconnect recovery from sustained disconnect by escalating user-facing connection feedback only when the reconnect state persists beyond the grace period.

#### Scenario: Reconnect remains unresolved beyond the grace period
- **WHEN** the websocket remains disconnected or reconnecting after the grace period expires
- **THEN** the system SHALL present a visible reconnect or offline status message

#### Scenario: Disconnect becomes sustained
- **WHEN** the connection problem continues past the transient recovery stage
- **THEN** the system SHALL escalate to a stronger offline/error presentation

### Requirement: Transient websocket recovery SHALL NOT be labeled as confirmed internet loss
The system SHALL use reconnect-specific or softened messaging for transient websocket recovery states and SHALL reserve hard network-loss wording for sustained or confirmed failure states.

#### Scenario: Brief reconnect after notification-driven chat entry
- **WHEN** the user opens chat from a notification and websocket recovery starts immediately
- **THEN** the system SHALL avoid presenting that transient state as confirmed internet loss

#### Scenario: Persistent disconnect after recovery attempts
- **WHEN** reconnect does not recover within the sustained-failure threshold
- **THEN** the system MAY present hard offline wording consistent with a persistent connection problem

### Requirement: App-level and chat-level connection banners SHALL follow the same resume-aware severity policy
The system SHALL apply the same recent-resume suppression and escalation rules to app-shell and chat-room connection feedback so users do not receive contradictory severity signals.

#### Scenario: App shell and chat room both observe a transient reconnect
- **WHEN** both app-level and room-level banners are eligible to react to the same transient websocket state after resume
- **THEN** both surfaces SHALL follow the same suppression and escalation rules

#### Scenario: Sustained disconnect while user is inside chat
- **WHEN** the user remains in a conversation and the disconnect persists beyond the grace period
- **THEN** any room-scoped connection feedback SHALL reflect the same severity policy as the app shell
