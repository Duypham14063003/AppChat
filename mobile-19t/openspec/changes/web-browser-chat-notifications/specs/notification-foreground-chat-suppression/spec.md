## MODIFIED Requirements

### Requirement: Foreground chat notifications respect active conversation context
The system SHALL suppress foreground chat notifications when the user is already focused on the conversation that produced the incoming message. This suppression behavior MUST apply consistently to native foreground notifications and web browser notifications.

#### Scenario: Active conversation suppresses matching chat notification
- **WHEN** an incoming chat message targets the conversation currently open in the app
- **THEN** the system MUST NOT display a foreground notification for that message

#### Scenario: Different conversation still shows a foreground notification
- **WHEN** an incoming chat message targets a different conversation from the one currently open in the app
- **THEN** the system MUST display a foreground notification through the active platform notification channel
