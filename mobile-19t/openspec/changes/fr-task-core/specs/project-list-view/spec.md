## ADDED Requirements

### Requirement: Project list screen
The system SHALL provide a ProjectListScreen showing all Odoo projects in a scrollable list. Each project item SHALL display: project name, manager name, task count. Tapping a project SHALL navigate to the TaskListScreen for that project.

#### Scenario: View project list
- **WHEN** the user opens the Tasks tab
- **THEN** the ProjectListScreen shows all projects from Odoo

#### Scenario: Tap project
- **WHEN** the user taps "Internal App" project
- **THEN** the app navigates to the task list for that project

### Requirement: Pull-to-refresh on project list
The system SHALL support pull-to-refresh on the ProjectListScreen to force-refresh the project list from Odoo (invalidate Redis cache).

#### Scenario: Pull to refresh
- **WHEN** the user pulls down on the project list
- **THEN** the cache is invalidated and fresh data is fetched from Odoo

### Requirement: Responsive project list on web
On wide screens (≥768px), the ProjectListScreen SHALL be displayed as a sidebar panel (300px width) on the left side, with the task list or task detail filling the remaining space.

#### Scenario: Wide screen layout
- **WHEN** the user views projects on a ≥768px screen
- **THEN** projects appear as a left sidebar with tasks in the main area

