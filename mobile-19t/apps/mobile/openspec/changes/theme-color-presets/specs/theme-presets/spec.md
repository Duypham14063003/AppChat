## ADDED Requirements

### Requirement: Theme preset selection
The system SHALL allow users to select a color preset from a predefined list via the Settings screen. The selected preset SHALL be stored locally per device using SharedPreferences and SHALL take effect immediately across the entire application UI.

#### Scenario: First launch with no saved preset
- **WHEN** the user opens the app for the first time (no saved preset in storage)
- **THEN** the app SHALL use the "gold_dark" preset as the default

#### Scenario: Returning user with saved preset
- **WHEN** the user opens the app with a previously saved preset
- **THEN** the app SHALL restore and apply the saved preset immediately

#### Scenario: User selects a new preset
- **WHEN** the user navigates to Settings and selects a different preset from the grid
- **THEN** the system SHALL save the selected preset ID to SharedPreferences
- **AND** the system SHALL immediately apply the new preset to the entire app with a smooth animated transition

#### Scenario: Preset selection persists across app restarts
- **WHEN** the user selects a preset and fully closes and reopens the app
- **THEN** the system SHALL restore the previously selected preset from SharedPreferences

### Requirement: Theme preset preview
The Settings screen SHALL display a live preview card that shows all color values of the currently selected preset, including primary, surface, background, and text colors.

#### Scenario: Preview updates on selection change
- **WHEN** the user selects a preset in the grid
- **THEN** the preview card SHALL update in real-time to reflect the colors of the newly selected preset

### Requirement: Animated theme transition
When the user changes the active preset, the system SHALL animate the color transition over at least 250ms to avoid a jarring instant swap.

#### Scenario: Animated transition on preset change
- **WHEN** the user selects a different preset
- **THEN** the theme colors SHALL transition smoothly over 300ms using Flutter's AnimatedTheme

### Requirement: Settings navigation from Profile
The Account screen SHALL provide a settings icon in the AppBar that navigates to the Settings screen.

#### Scenario: Navigate to Settings from Account screen
- **WHEN** the user taps the settings icon in the Account screen's AppBar
- **THEN** the system SHALL push the Settings screen onto the navigation stack

### Requirement: Dynamic accent color propagation
All components in the app SHALL use the active preset's primary/accent color instead of hardcoded values. The active accent color SHALL be accessible via `AppColors.primary` and SHALL update automatically when the preset changes.

#### Scenario: UI reflects active preset accent
- **WHEN** the active preset is "blue_dark" (blue primary)
- **THEN** the NavigationBar indicator, selected icons, and primary buttons SHALL all use blue
- **AND** when the preset changes to "green_dark" (green primary)
- **THEN** the same components SHALL all update to green without requiring a restart
