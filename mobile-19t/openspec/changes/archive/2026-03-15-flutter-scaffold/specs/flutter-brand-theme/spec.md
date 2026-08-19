## ADDED Requirements

### Requirement: Dark theme with gold accent is the default
The application SHALL use a dark theme with background color #0A0A0A and primary accent color #C9A84C (Nineteen Tech gold). The ThemeData SHALL be configured as the app's default theme.

#### Scenario: App launches with dark theme
- **WHEN** the app starts
- **THEN** the background is dark (#0A0A0A family) and accent elements use gold (#C9A84C)

### Requirement: AppColors constants are defined
The application SHALL provide a static `AppColors` class with all brand colors: gold variants (#C9A84C, #E2C06A, #A8843A, #F5E4A8), dark background hierarchy (#0A0A0A through #28282F), text colors (primary #F2EDD8, secondary #9E9880, hint #5A5648), and semantic colors (online #2ECC71, danger #E74C3C).

#### Scenario: AppColors is importable and complete
- **WHEN** developer imports `AppColors` from the theme package
- **THEN** all brand color constants are available as static Color fields

### Requirement: Typography uses Plus Jakarta Sans
The application SHALL use Plus Jakarta Sans as the primary font family, loaded via the google_fonts package. Text styles SHALL be defined for headings, body, labels, and captions.

#### Scenario: Text renders in Plus Jakarta Sans
- **WHEN** the app displays text
- **THEN** the text is rendered in Plus Jakarta Sans font family

