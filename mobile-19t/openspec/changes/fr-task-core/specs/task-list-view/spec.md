## ADDED Requirements

### Requirement: Task list within a project
The system SHALL provide a TaskListScreen showing all tasks for a selected project. Each task item SHALL display: task name, stage badge (colored by stage sequence), deadline (red if overdue), priority indicator, assignee avatar(s).

#### Scenario: View task list
- **WHEN** the user selects project "Internal App"
- **THEN** all tasks for that project are displayed in a scrollable list

### Requirement: Filter tasks by stage
The system SHALL display filter chips at the top of the TaskListScreen for each stage (e.g., "Tất cả", "Backlog", "In Progress", "Review", "Done"). Tapping a chip SHALL filter the list to show only tasks in that stage. "Tất cả" shows all tasks.

#### Scenario: Filter by In Progress
- **WHEN** the user taps the "In Progress" filter chip
- **THEN** only tasks with stage "In Progress" are shown

#### Scenario: Show all tasks
- **WHEN** the user taps "Tất cả"
- **THEN** all tasks regardless of stage are shown

### Requirement: Sort tasks
The system SHALL provide a sort dropdown with options: "Deadline" (ascending, nulls last), "Ưu tiên" (priority descending), "Người phụ trách" (assignee name alphabetical). Default sort SHALL be by deadline.

#### Scenario: Sort by deadline
- **WHEN** the user selects sort by "Deadline"
- **THEN** tasks are ordered by deadline ascending, tasks without deadline at the end

#### Scenario: Sort by priority
- **WHEN** the user selects sort by "Ưu tiên"
- **THEN** high priority tasks appear first

### Requirement: Pull-to-refresh on task list
The system SHALL support pull-to-refresh on the TaskListScreen to force-refresh tasks from Odoo (invalidate per-project Redis cache).

#### Scenario: Pull to refresh tasks
- **WHEN** the user pulls down on the task list
- **THEN** the task cache for this project is invalidated and fresh data is fetched

### Requirement: Overdue visual indicator
Tasks with a deadline in the past SHALL display the deadline in `AppColors.danger` (red) with a warning icon. Tasks with deadline within 3 days SHALL display in `AppColors.warning` (amber).

#### Scenario: Overdue task
- **WHEN** a task has deadline 2026-03-15 and today is 2026-03-17
- **THEN** the deadline text is red with a ⚠️ icon

### Requirement: Responsive task list on web
On wide screens (≥768px), the TaskListScreen SHALL be displayed in the center panel between the project sidebar and the task detail panel. Tapping a task SHALL show its detail in the right panel without navigating away.

#### Scenario: Wide screen task selection
- **WHEN** the user taps a task on a wide screen
- **THEN** the task detail appears in the right panel while the task list remains visible

