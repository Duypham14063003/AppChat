## ADDED Requirements

### Requirement: Project task API can include subtasks on request
The system SHALL allow callers of the project task listing API to request subtasks together with top-level project tasks by passing an explicit include-subtasks query parameter.

#### Scenario: Default project task list remains parent-only
- **WHEN** a caller requests `GET /api/v1/tasks/projects/:projectId/tasks` without `include_subtasks=true`
- **THEN** the response SHALL contain only top-level tasks whose `parent_id` is false

#### Scenario: Include-subtasks project task list returns child tasks
- **WHEN** a caller requests `GET /api/v1/tasks/projects/:projectId/tasks?include_subtasks=true`
- **THEN** the response SHALL include both top-level tasks and subtasks for the requested project

#### Scenario: Subtask hierarchy metadata is preserved
- **WHEN** the project task list includes a subtask
- **THEN** the subtask item SHALL preserve its `parent_id`, `child_ids`, and `subtask_count` fields in the same task shape used by existing task responses

### Requirement: Project task filtering and sorting applies to included subtasks
The system SHALL apply existing project task list filters and sorting consistently to any subtasks included in the response.

#### Scenario: Stage filter includes matching subtasks
- **WHEN** a caller requests project tasks with `include_subtasks=true` and a stage filter
- **THEN** the response SHALL include only parent tasks and subtasks whose own stage matches the requested stage filter

#### Scenario: Sort orders the full returned list
- **WHEN** a caller requests project tasks with `include_subtasks=true` and a supported sort option
- **THEN** the response SHALL sort the complete returned list, including subtasks, using the same sort behavior as parent-only task lists

### Requirement: Project task caches distinguish subtask inclusion
The system SHALL store and invalidate parent-only and include-subtasks project task lists independently.

#### Scenario: Parent-only cache does not satisfy include-subtasks request
- **WHEN** a parent-only project task list has been cached
- **THEN** a later request with `include_subtasks=true` SHALL not return the parent-only cached payload

#### Scenario: Refresh clears the relevant include-subtasks cache
- **WHEN** a caller requests project tasks with `refresh=true` and `include_subtasks=true`
- **THEN** the system SHALL invalidate and refetch the include-subtasks project task list before responding

### Requirement: Mobile project task list can display subtasks
The mobile app SHALL be able to request and render subtasks in project task lists without breaking task detail navigation.

#### Scenario: Mobile requests subtasks for project task browsing
- **WHEN** the mobile project task list loads tasks for a project that should show the full work breakdown
- **THEN** it SHALL request the project task API with `include_subtasks=true`

#### Scenario: Mobile distinguishes subtasks in a flat list
- **WHEN** a returned task has a non-false `parent_id`
- **THEN** the mobile task list SHALL visually distinguish it from a top-level task

#### Scenario: Tapping a subtask opens task detail
- **WHEN** a user taps a subtask in the mobile project task list
- **THEN** the app SHALL open the existing task detail flow for that subtask id
