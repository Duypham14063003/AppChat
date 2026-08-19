## ADDED Requirements

### Requirement: Chat and group management surfaces SHALL adapt to the active theme palette
The system SHALL render neutral chat and group-management UI surfaces with colors that follow the active theme palette in both light mode and dark mode.

#### Scenario: User opens a group-management dialog in light mode
- **WHEN** the active preset uses a light palette and the user opens a group-management dialog such as rename, add member, remove member, or delete member
- **THEN** the dialog SHALL render palette-appropriate background, text, hint, and icon colors instead of dark-only neutral colors

### Requirement: Chat and group search fields SHALL remain readable in light mode
The system SHALL render search inputs in chat/group flows with palette-aware text, hint, icon, and surface colors so search remains readable in light mode.

#### Scenario: User opens search in a chat/group flow under a light preset
- **WHEN** the user opens search in chat search, new chat, new group, or add-member flows while a light preset is active
- **THEN** the search field SHALL show readable text and hint contrast against a palette-appropriate input surface

### Requirement: Chat and group empty/loading states SHALL avoid dark-only overlays in light mode
The system SHALL render empty states and loading overlays in the affected chat/group flows with theme-aware neutral styling so they do not appear as dark-mode leftovers in light mode.

#### Scenario: User sees a loading or empty state in a reported chat/group flow
- **WHEN** a reported chat/group flow shows an empty state or loading overlay while a light preset is active
- **THEN** the UI SHALL use palette-consistent neutral colors and SHALL NOT rely on dark-only scrims or typography colors
