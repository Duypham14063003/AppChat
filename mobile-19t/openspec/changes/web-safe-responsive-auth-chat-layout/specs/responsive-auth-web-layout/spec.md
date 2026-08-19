## ADDED Requirements

### Requirement: Login screen uses a bounded wide-layout frame
The mobile app SHALL render the login experience inside a centered, bounded content frame when the authentication viewport is wide enough for desktop-style presentation. The frame SHALL keep the form readable on web and desktop-sized canvases instead of stretching the fields and primary action across the full viewport width.

#### Scenario: Open login on a desktop-sized viewport
- **WHEN** the user opens the login screen on a wide web or desktop viewport
- **THEN** the app renders the login title, fields, and primary action inside a centered container with a bounded maximum width

#### Scenario: Preserve full-screen background treatment
- **WHEN** the login screen enters the wide-layout mode
- **THEN** the screen background may remain full-width while the interactive authentication content stays visually centered inside the bounded frame

### Requirement: Login screen preserves narrow/mobile behavior
The mobile app SHALL preserve the current mobile and narrow-tablet login behavior when the available viewport is not wide enough for the bounded desktop frame.

#### Scenario: Open login on a phone-sized viewport
- **WHEN** the user opens the login screen on a phone-sized viewport
- **THEN** the app keeps the current single-column mobile login layout without introducing new desktop framing behavior

#### Scenario: Validation and loading behavior remain unchanged
- **WHEN** the user validates or submits the login form after the responsive layout update
- **THEN** the app keeps the same validation, loading, and error presentation behavior regardless of viewport width
