## 1. Backend API Contract

- [x] 1.1 Add `include_subtasks` query parsing to `TaskController.getTasks`.
- [x] 1.2 Extend `TaskService.getTasks` to accept an `includeSubtasks` boolean while preserving the default parent-only behavior.
- [x] 1.3 Split Redis cache keys so parent-only and include-subtasks project task lists never share cached payloads.

## 2. Odoo Task Fetching

- [x] 2.1 Extend `OdooService.fetchTasks` to support fetching all project tasks when subtasks are requested.
- [x] 2.2 Keep the existing `parent_id = false` Odoo domain when subtasks are not requested.
- [x] 2.3 Ensure returned subtasks preserve `parent_id`, `child_ids`, `subtask_count`, stage, assignee, tag, deadline, priority, and description fields.

## 3. Filtering And Sorting

- [x] 3.1 Apply existing stage-name and stage-id filters to the full returned list when subtasks are included.
- [x] 3.2 Apply existing deadline, priority, and assignee sort modes to the full returned list when subtasks are included.
- [x] 3.3 Verify `refresh=true` invalidates the correct cache key for each include-subtasks mode.

## 4. Mobile Integration

- [x] 4.1 Add an `includeSubtasks` option to `TaskRepository.getTasks`.
- [x] 4.2 Add an explicit include-subtasks path for the mobile project task list without forcing every existing task selector to receive subtasks.
- [x] 4.3 Update task list rendering to visually distinguish tasks with non-false `parent_id`.
- [x] 4.4 Confirm tapping a subtask uses the existing task detail navigation for the subtask id.

## 5. Verification

- [x] 5.1 Add or update backend tests for default parent-only behavior, include-subtasks behavior, cache separation, refresh handling, filtering, and sorting.
- [x] 5.2 Add or update mobile tests/model coverage for sending `include_subtasks=true` and recognizing subtask items.
- [x] 5.3 Run backend build/tests relevant to task APIs.
- [x] 5.4 Run Flutter analyze/tests relevant to task repository, provider, model, and task list UI.
