## ADDED Requirements

### Requirement: Fetch projects from Odoo
The system SHALL extend `OdooService` with a `fetchProjects()` method that calls Odoo JSON-RPC `project.project` `search_read` with fields: `name`, `user_id`, `date_start`, `date`, `task_count`. The method SHALL return a typed array of project records.

#### Scenario: Fetch all projects
- **WHEN** fetchProjects is called
- **THEN** all active projects are returned from Odoo with name, manager, dates, and task count

### Requirement: Fetch tasks from Odoo by project
The system SHALL extend `OdooService` with a `fetchTasks(projectId)` method that calls Odoo JSON-RPC `project.task` `search_read` with domain `[["project_id", "=", projectId]]` and fields: `name`, `user_ids`, `stage_id`, `date_deadline`, `priority`, `description`.

#### Scenario: Fetch tasks for a project
- **WHEN** fetchTasks is called with projectId 5
- **THEN** all tasks belonging to project 5 are returned with full details

### Requirement: Fetch task stages from Odoo
The system SHALL extend `OdooService` with a `fetchTaskStages()` method that calls Odoo JSON-RPC `project.task.type` `search_read` with fields: `name`, `sequence`. Stages SHALL be ordered by sequence ascending.

#### Scenario: Fetch stages
- **WHEN** fetchTaskStages is called
- **THEN** all task stages are returned ordered by sequence (e.g., Backlog=1, In Progress=2, Review=3, Done=4)

### Requirement: Fetch log notes for a task from Odoo
The system SHALL extend `OdooService` with a `fetchTaskLogNotes(taskId)` method that calls Odoo JSON-RPC `mail.message` `search_read` with domain `[["model", "=", "project.task"], ["res_id", "=", taskId], ["message_type", "in", ["comment", "notification"]]]` and fields: `body`, `author_id`, `date`, `message_type`. Results SHALL be ordered by date DESC.

#### Scenario: Fetch log notes
- **WHEN** fetchTaskLogNotes is called with taskId 42
- **THEN** all comments and notifications for that task are returned with author, body (HTML), and date

### Requirement: Write log note to Odoo
The system SHALL extend `OdooService` with a `writeTaskLogNote(taskId, body, authorEmployeeId)` method that calls Odoo JSON-RPC `mail.message` `create` with `{ model: "project.task", res_id: taskId, body: body, message_type: "comment" }`.

#### Scenario: Write log note
- **WHEN** writeTaskLogNote is called with taskId 42 and body "Đã hoàn thành phần API"
- **THEN** a new comment is created on the task in Odoo's chatter

### Requirement: Redis cache for projects and stages
The system SHALL cache projects in Redis key `tasks:projects` with 15 minute TTL. Stages SHALL be cached in Redis key `tasks:stages` with 15 minute TTL. On cache miss, the system SHALL fetch from Odoo and populate the cache.

#### Scenario: Cache hit
- **WHEN** GET /tasks/projects is called and Redis has cached data
- **THEN** cached data is returned without calling Odoo

#### Scenario: Cache miss
- **WHEN** GET /tasks/projects is called and Redis cache has expired
- **THEN** the system fetches from Odoo, caches the result, and returns it

### Requirement: Redis cache for tasks per project
The system SHALL cache tasks per project in Redis key `tasks:project:{projectId}` with 5 minute TTL. On cache miss, the system SHALL fetch from Odoo and populate the cache. Pull-to-refresh from the client SHALL invalidate the cache.

#### Scenario: Task cache with 5 min TTL
- **WHEN** tasks for project 5 are fetched and cached
- **THEN** subsequent requests within 5 minutes return cached data

#### Scenario: Force refresh
- **WHEN** the client sends GET /tasks/projects/:id/tasks?refresh=true
- **THEN** the cache is invalidated and fresh data is fetched from Odoo

### Requirement: BullMQ cron job to warm cache
The system SHALL register a BullMQ repeatable job every 15 minutes that calls `fetchProjects()` and `fetchTaskStages()` to warm the Redis cache. The job SHALL retry 3 times with exponential backoff on failure.

#### Scenario: Cache warming
- **WHEN** the cron job runs every 15 minutes
- **THEN** projects and stages are fetched from Odoo and cached in Redis

### Requirement: REST API endpoints for tasks
The system SHALL expose: `GET /tasks/projects` (list projects), `GET /tasks/projects/:id/tasks` (list tasks for project, optional `?stage_id` filter, `?sort` param), `GET /tasks/:id` (task detail), `GET /tasks/:id/log-notes` (log notes), `POST /tasks/:id/log-notes` (write log note with `{ body }` in request).

#### Scenario: List projects
- **WHEN** a user sends GET /tasks/projects
- **THEN** all projects are returned from cache or Odoo

#### Scenario: List tasks with stage filter
- **WHEN** a user sends GET /tasks/projects/5/tasks?stage_id=3
- **THEN** only tasks in stage 3 for project 5 are returned

#### Scenario: Post log note
- **WHEN** a user sends POST /tasks/42/log-notes with body "Done API"
- **THEN** the log note is written to Odoo and 201 is returned

