## Why

The project task API currently returns only top-level Odoo tasks because the backend filters `project.task` records with `parent_id = false`. Mobile task lists and task selection flows need a way to load subtasks together with project tasks so users can see and select the full work breakdown without opening each parent task individually.

## What Changes

- Add opt-in support for returning subtasks from `GET /api/v1/tasks/projects/:projectId/tasks`.
- Preserve the existing default behavior so callers that do not request subtasks continue receiving only top-level tasks.
- Add a query parameter such as `include_subtasks=true` for callers that need parent tasks and subtasks in one response.
- Return subtasks in the same task shape already used by mobile, with `parent_id`, `child_ids`, and `subtask_count` preserved so clients can distinguish hierarchy.
- Ensure cache keys separate parent-only task lists from include-subtasks task lists.
- Update mobile task fetching where the project task list should include subtasks.

## Capabilities

### New Capabilities
- `project-task-subtask-listing`: Covers optional subtask inclusion for project task listing APIs and mobile consumption.

### Modified Capabilities

## Impact

- Backend task API: `src/modules/task/task.controller.ts`, `src/modules/task/services/task.service.ts`.
- Odoo integration: `src/modules/auth/services/odoo.service.ts`.
- Redis task-list caching keys for project tasks.
- Mobile task repository/provider/model/list rendering under `apps/mobile/lib/features/task`.
- HR task selectors that reuse the project task provider may need explicit opt-in or parent-only behavior depending on product intent.
