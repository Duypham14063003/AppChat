## ADDED Requirements

### Requirement: Adaptive shell layout based on screen width
The `MainShell` SHALL render a `NavigationRail` on the left side when screen width is ≥768px, and a bottom `NavigationBar` when screen width is <768px. The navigation destinations (Chat, HR, Tasks, Profile) SHALL be identical in both layouts. The `NavigationRail` SHALL use `AppColors.surface` background, `AppColors.gold` for selected icons, and `AppColors.textSecondary` for unselected icons.

#### Scenario: Wide screen renders NavigationRail
- **GIVEN** the app is running on a screen ≥768px wide
- **WHEN** the MainShell renders
- **THEN** a NavigationRail appears on the left side and no bottom NavigationBar is shown

#### Scenario: Narrow screen renders NavigationBar
- **GIVEN** the app is running on a screen <768px wide
- **WHEN** the MainShell renders
- **THEN** a bottom NavigationBar appears and no NavigationRail is shown

#### Scenario: Layout adapts on window resize
- **GIVEN** the app is running in a browser window
- **WHEN** the user resizes the window across the 768px threshold
- **THEN** the navigation switches between NavigationRail and NavigationBar
