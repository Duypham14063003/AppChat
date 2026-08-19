## Why

The Task module is a core pillar alongside Chat and HR. The `TaskModule` exists as an empty shell. The SRS defines project/task management synced from Odoo. Employees need to view their projects, browse tasks by stage, see task details (description, deadline, assignees), and communicate via log notes — all pulled from Odoo as source of truth. This change implements the essential P0 MUST requirements minus timesheet and subtasks.

## What Changes

Backend (NestJS — build from empty TaskModule):
- Extend `OdooService` with methods: `fetchProjects()`, `fetchTasks(projectId)`, `fetchTaskStages()`, `fetchTaskLogNotes(taskId)`, `writeTaskLogNote(taskId, body)`
- `TaskService`: proxy Odoo data through Redis cache (projects 15min, tasks 5min, stages 15min), log note write-through
- `TaskSyncProcessor`: BullMQ cron job every 15 minutes to warm Redis cache for projects and stages
- `TaskController`: REST endpoints — GET /tasks/projects, GET /tasks/projects/:id/tasks, GET /tasks/:id, GET /tasks/:id/log-notes, POST /tasks/:id/log-notes
- No PostgreSQL tables — Odoo is source of truth, Redis is cache layer

Frontend (Flutter — build from empty task/ directory):
- Task feature screens: ProjectListScreen, TaskListScreen (filter by stage, sort by deadline/priority/assignee), TaskDetailScreen (description, deadline, stage, assignees, log notes list, log note input)
- Task providers: projectListProvider, taskListProvider, taskDetailProvider, logNotesProvider
- Task repository: REST calls to /tasks/* endpoints
- Responsive: mobile (full-screen push navigation) + web/desktop (master-detail split at ≥768px)
- Navigation: Tasks tab in bottom navigation bar

## Capabilities

### New Capabilities
- `odoo-project-task-sync`: Pull projects, tasks, and stages from Odoo via JSON-RPC — BullMQ cron every 15 min to warm Redis cache, REST API proxy to Flutter
- `task-list-view`: Task list within a project — filter by stage, sort by deadline/priority/assignee, responsive layout (mobile list + web master-detail)
- `task-detail-view`: Task detail screen — description, deadline, stage badge, assignees, log notes list with input to write new log notes back to Odoo
- `project-list-view`: Project list screen — browse all Odoo projects, tap to see tasks

### Modified Capabilities
<!-- No existing spec-level requirements are changing. -->

## Impact

- **Database**: No new PostgreSQL tables. Redis cache keys for projects, tasks, stages.
- **API**: New endpoints under `/tasks/*`. No changes to existing endpoints.
- **Backend**: `TaskModule` populated with service, controller, BullMQ processor. `OdooService` extended with 5 new methods.
- **Flutter**: New `features/task/` directory with screens, providers, repository, widgets. No new packages needed (existing Dio, Riverpod, go_router sufficient).
- **Navigation**: Tasks tab in bottom navigation bar (index 2, already registered in MainShell route).
- **Odoo**: Read operations on `project.project`, `project.task`, `project.task.type`, `mail.message`. Write operation on `mail.message` for log notes.

