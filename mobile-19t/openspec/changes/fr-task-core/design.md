## Context

The 19T app has an empty `TaskModule` shell and empty Flutter `features/task/` directory. Odoo is the source of truth for projects and tasks — the app is a read-only viewer with the ability to write log notes. The `OdooService` already handles JSON-RPC authentication and has `fetchEmployees()` as a pattern. Redis is available (used for chat PubSub). BullMQ is used for cron jobs (user sync hourly, chat push). The Odoo integration spec defines JSON-RPC calls for `project.project`, `project.task`, and `project.task.type`.

The app uses responsive layout with `isWide` check at 768px. Chat already implements master-detail split on wide screens. The Tasks tab is registered at index 2 in the bottom navigation.

## Goals / Non-Goals

**Goals:**
- Pull projects, tasks, stages from Odoo and cache in Redis
- Project list screen
- Task list with stage filter and sort (deadline, priority, assignee)
- Task detail with description, deadline, stage, assignees, log notes
- Write log notes back to Odoo
- Responsive: mobile push navigation + web/desktop master-detail
- BullMQ cron to warm cache every 15 minutes

**Non-Goals:**
- Timesheet entries (TASK-FR-007 — excluded from scope)
- Subtasks display (excluded)
- Kanban board / drag-and-drop (TASK-FR-003, P1 SHOULD — future)
- My Tasks Dashboard with stats (TASK-FR-010 — simplified, no stats)
- Task search (TASK-FR-009, P1 SHOULD — future)
- Task notifications (TASK-FR-008, P1 SHOULD — future)
- AI log (TASK-FR-006, P1 SHOULD — future)
- Task creation/editing in app (Odoo is source of truth)
- PostgreSQL tables for tasks (cache-only architecture)

## Decisions

### D1: Redis cache only — no PostgreSQL tables

**Decision**: Projects, tasks, and stages are cached in Redis with TTL. No PostgreSQL tables for task data.

**Why**: Odoo is source of truth. Duplicating data in PostgreSQL adds sync complexity and staleness risk. Redis cache with 5-15 min TTL is sufficient for <50 users. Cache miss → fetch from Odoo on demand.

**Alternative**: PostgreSQL mirror tables with BullMQ sync. Rejected — over-engineering for read-only data with small user base.

### D2: Cache warming via BullMQ cron + on-demand fallback

**Decision**: BullMQ cron job every 15 minutes fetches all projects and stages into Redis. Individual task lists are cached on first request (5 min TTL). Cache miss triggers live Odoo fetch.

**Why**: Projects and stages change rarely — 15 min cache is fine. Tasks change more often — 5 min TTL balances freshness vs Odoo load. On-demand fallback ensures data is always available even if cron fails.

### D3: Log notes via Odoo `mail.message` model

**Decision**: Read log notes via `mail.message` search_read filtered by `model=project.task` and `res_id=task_id`. Write log notes via `mail.message` create with `message_type=comment`.

**Why**: Odoo stores task comments/log notes in the `mail.message` model (chatter). This is the standard Odoo pattern. Writing a log note creates a visible comment in Odoo's task view.

### D4: Responsive layout — reuse chat's master-detail pattern

**Decision**: On mobile (<768px), use full-screen push navigation: ProjectList → TaskList → TaskDetail. On web/desktop (≥768px), use 3-column layout: NavigationRail → ProjectList+TaskList (left panel) → TaskDetail (right panel).

**Why**: Consistent with existing chat wide-screen pattern. Users expect the same navigation behavior across features.

### D5: Stage mapping — use Odoo stage_id directly

**Decision**: Fetch stages from `project.task.type` and display their names as-is from Odoo. No hardcoded stage mapping. Stage colors assigned by sequence order (1st=textSecondary, 2nd=warning, 3rd=info, 4th=online).

**Why**: Odoo projects can have custom stages. Hardcoding "Backlog/In Progress/Review/Done" would break for projects with different workflows. Dynamic stage loading is more flexible.

## Risks / Trade-offs

- **[Risk] Odoo API rate limiting** → With <50 users and 15 min cache, Odoo load is minimal. On-demand fetches are per-project, not all tasks at once. Acceptable.

- **[Risk] Redis cache eviction** → If Redis runs low on memory, cached data may be evicted before TTL. Mitigated by on-demand fallback to Odoo.

- **[Risk] Log note write failure** → If Odoo is unreachable when user submits log note, show error and let user retry. No offline queue for log notes (unlike attendance).

- **[Trade-off] No offline support for tasks** → Tasks are read-only from Odoo cache. No Drift local storage. If offline, show "Không có kết nối" message. Acceptable — task viewing is not time-critical like attendance checkin.

- **[Trade-off] 5 min task cache staleness** → Task changes in Odoo take up to 5 min to appear in app. Acceptable for <50 users. User can pull-to-refresh to force cache invalidation.

