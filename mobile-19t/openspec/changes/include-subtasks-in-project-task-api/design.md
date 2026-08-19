## Context

`GET /api/v1/tasks/projects/:projectId/tasks` currently returns only top-level Odoo tasks. The backend calls `OdooService.fetchTasks(projectId)`, which filters `project.task` records by `project_id` and `parent_id = false`. Existing task records already include hierarchy metadata (`parent_id`, `child_ids`, `subtask_count`), and a separate `GET /api/v1/tasks/:taskId/subtasks` endpoint fetches children for a single parent task.

The mobile task feature uses the project task list for the main task screen and is also reused by HR morning/OT task selectors. Those consumers expect a flat `List<Task>` and already parse `parent_id`, `child_ids`, and `subtask_count`.

## Goals / Non-Goals

**Goals:**
- Allow callers to request project tasks with subtasks in one API response.
- Keep the existing parent-only response as the default for backward compatibility.
- Reuse the current Odoo task shape so existing mobile model parsing remains valid.
- Keep parent-only and include-subtasks Redis caches separate.
- Update the mobile project task list to request subtasks where the product needs a complete project work breakdown.

**Non-Goals:**
- Do not remove `GET /api/v1/tasks/:taskId/subtasks`.
- Do not introduce a new nested response contract in this change.
- Do not change Odoo data ownership or create local task persistence.
- Do not change task creation, editing, daily report submission, or stage semantics.

## Decisions

1. Add an opt-in `include_subtasks=true` query parameter.

   Default behavior remains parent-only so current integrations and HR selectors do not unexpectedly receive child tasks. The controller will parse `include_subtasks` similarly to the existing `refresh=true` flag and pass it through to the service layer.

   Alternative considered: always include subtasks. This is simpler but risks changing task counts and selector behavior for existing mobile flows.

2. Return a flat list when subtasks are included.

   The response will contain both parent tasks and child tasks as normal task objects. Child tasks are identifiable by `parent_id` being set. This matches the current mobile `Task` model and avoids adding a nested `subtasks` field across backend and mobile.

   Alternative considered: nested `subtasks` arrays under each parent. This is clearer structurally, but it requires a larger response contract and UI model change.

3. Fetch project tasks from Odoo without the `parent_id = false` filter when subtasks are requested.

   Odoo `project.task` records for subtasks still belong to the project and include `parent_id`, so a single `search_read` with `project_id = projectId` can retrieve the full flat set. The existing parent-only query remains unchanged for default calls.

   Alternative considered: fetch parents first, then call `fetchSubtasks` per parent. This preserves current helper behavior but creates N+1 Odoo requests and performs worse for projects with many parent tasks.

4. Separate cache entries by include-subtasks mode.

   The backend should use a distinct Redis key such as `tasks:project:<projectId>:with-subtasks` when `include_subtasks=true`. This prevents a parent-only response from poisoning an include-subtasks request, or vice versa.

5. Mobile task list opt-in must be explicit.

   `TaskRepository.getTasks` should accept an `includeSubtasks` option and send `include_subtasks=true` only where needed. This avoids forcing all existing consumers of `taskListProvider` to receive subtasks until each UI flow is reviewed.

## Risks / Trade-offs

- More tasks in one response may increase payload size for large projects -> mitigate by making inclusion opt-in and keeping default parent-only behavior.
- Flat subtasks can look like normal tasks if the UI does not distinguish them -> mitigate by using existing `parent_id` metadata to indent or badge subtasks in project task lists.
- Stage filters may include child tasks whose stages differ from parent tasks -> mitigate by applying existing stage filtering to the final flat list, so behavior is predictable per returned item.
- Existing cache may hide fresh subtask data -> mitigate by honoring `refresh=true` for both parent-only and include-subtasks cache keys.
