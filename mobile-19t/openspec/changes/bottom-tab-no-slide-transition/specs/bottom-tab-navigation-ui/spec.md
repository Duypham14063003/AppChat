## ADDED Requirements

### Requirement: Bottom navigation root tabs do not use push-style slide transitions
The system SHALL switch between the root bottom-navigation tabs without a horizontal push-style page transition when the user selects Chat, HR, Tasks, or Profile.

#### Scenario: Switch from one root tab to another
- **WHEN** the user taps a different destination in the bottom navigation bar
- **THEN** the app changes to the selected root tab without a left-to-right or right-to-left push-style slide animation

#### Scenario: Switch root destination on wide layout
- **WHEN** the user selects a different destination in the wide-layout navigation rail
- **THEN** the app changes the root section without a push-style horizontal page transition

### Requirement: Root tab switching preserves normal detail-page navigation semantics
The system SHALL keep standard push navigation behavior for detail pages opened from within a root tab while applying the non-sliding behavior only to root-tab changes.

#### Scenario: Open detail page from a root tab
- **WHEN** the user opens a nested screen such as chat detail, HR history, payroll config, or task detail from within a tab
- **THEN** the app may continue using normal push-style navigation for that nested screen

#### Scenario: Return from detail page to tab root
- **WHEN** the user pops a nested detail page
- **THEN** the user returns to the existing root tab context rather than triggering a root-tab transition

### Requirement: Bottom navigation selection remains route-driven
The system SHALL keep the selected bottom-navigation destination synchronized with the active root route after non-sliding tab switches.

#### Scenario: Route change updates selected tab
- **WHEN** the active root route changes to `/chat`, `/hr`, `/tasks`, or `/profile`
- **THEN** the bottom navigation highlights the matching destination

#### Scenario: Re-select current tab
- **WHEN** the user taps the currently selected bottom-navigation destination
- **THEN** the app does not trigger an unnecessary route transition animation
