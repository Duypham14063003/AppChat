## ADDED Requirements

### Requirement: Message bubble max-width is capped
The `MessageBubble` widget SHALL constrain its max-width to `min(screenWidth * 0.75, 480)` instead of the current `screenWidth * 0.75`. This ensures bubbles remain readable on wide screens.

#### Scenario: Narrow screen bubble width unchanged
- **GIVEN** the app is on a 375px wide screen
- **WHEN** a message bubble renders
- **THEN** its max-width is 281px (375 * 0.75), same as current behavior

#### Scenario: Wide screen bubble width capped
- **GIVEN** the app is on a 1440px wide screen
- **WHEN** a message bubble renders
- **THEN** its max-width is 480px (capped), not 1080px (1440 * 0.75)
