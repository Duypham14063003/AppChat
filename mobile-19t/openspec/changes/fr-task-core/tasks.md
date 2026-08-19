## 1. Backend: Extend OdooService

- [x] 1.1 Add `fetchProjects()` method to `OdooService`: call Odoo JSON-RPC `project.project` `search_read` with fields `["name", "user_id", "date_start", "date", "task_count"]`, return typed array
- [x] 1.2 Add `fetchTasks(projectId)` method: call `project.task` `search_read` with domain `[["project_id", "=", projectId]]`, fields `["name", "user_ids", "stage_id", "date_deadline", "priority", "description"]`
- [x] 1.3 Add `fetchTaskStages()` method: call `project.task.type` `search_read` with fields `["name", "sequence"]`, order by sequence
- [x] 1.4 Add `fetchTaskLogNotes(taskId)` method: call `mail.message` `search_read` with domain `[["model", "=", "project.task"], ["res_id", "=", taskId], ["message_type", "in", ["comment", "notification"]]]`, fields `["body", "author_id", "date", "message_type"]`, order by date DESC
- [x] 1.5 Add `writeTaskLogNote(taskId, body)` method: call `mail.message` `create` with `{ model: "project.task", res_id: taskId, body, message_type: "comment" }`
- [x] 1.6 Add TypeScript interfaces: `OdooProject`, `OdooTask`, `OdooTaskStage`, `OdooLogNote`

## 2. Backend: TaskService with Redis Cache

- [x] 2.1 Create `TaskService` at `apps/api/src/modules/task/services/task.service.ts`: inject OdooService, Redis (via ConfigService or @InjectRedis)
- [x] 2.2 Implement `getProjects()`: check Redis key `tasks:projects` → if hit return cached → if miss call `fetchProjects()`, cache with 15min TTL, return
- [x] 2.3 Implement `getTaskStages()`: check Redis key `tasks:stages` → cache 15min TTL
- [x] 2.4 Implement `getTasks(projectId, stageId?, sort?, refresh?)`: check Redis key `tasks:project:{projectId}` → cache 5min TTL. If refresh=true, delete key first. Apply stage filter and sort in-memory after cache retrieval
- [x] 2.5 Implement `getTaskDetail(taskId)`: fetch single task from Odoo (no cache for individual tasks — they're already in the project cache, but detail may need fresh data)
- [x] 2.6 Implement `getLogNotes(taskId)`: call `fetchTaskLogNotes(taskId)` — no cache (log notes should be fresh)
- [x] 2.7 Implement `createLogNote(taskId, body, userId)`: lookup user's odoo_uid, call `writeTaskLogNote(taskId, body)`, return created note

## 3. Backend: TaskController

- [x] 3.1 Create `TaskController` at `apps/api/src/modules/task/task.controller.ts` with `@Controller('tasks')`
- [x] 3.2 Add `GET /tasks/projects` endpoint: call `taskService.getProjects()`, return project list
- [x] 3.3 Add `GET /tasks/projects/:projectId/tasks` endpoint: accept query params `stage_id`, `sort` (deadline|priority|assignee), `refresh` (boolean). Call `taskService.getTasks()`
- [x] 3.4 Add `GET /tasks/:taskId` endpoint: call `taskService.getTaskDetail(taskId)`
- [x] 3.5 Add `GET /tasks/:taskId/log-notes` endpoint: call `taskService.getLogNotes(taskId)`
- [x] 3.6 Add `POST /tasks/:taskId/log-notes` endpoint: accept `{ body }`, call `taskService.createLogNote()`, return 201

## 4. Backend: BullMQ Cache Warming

- [x] 4.1 Create `TaskSyncProcessor` at `apps/api/src/modules/task/jobs/task-sync.processor.ts`: BullMQ processor for queue 'task-sync'
- [x] 4.2 Implement process job: call `taskService.getProjects()` (forces cache refresh) and `taskService.getTaskStages()` (forces cache refresh)
- [x] 4.3 Register BullMQ queue 'task-sync' in TaskModule, add repeatable job every 15 minutes (900000ms), retry 3 times with exponential backoff

## 5. Backend: Wire TaskModule

- [x] 5.1 Update `TaskModule` imports: ConfigModule, AuthModule (for OdooService), BullModule.registerQueue('task-sync')
- [x] 5.2 Register providers: TaskService, TaskSyncProcessor
- [x] 5.3 Register controllers: TaskController
- [x] 5.4 Import OdooService (export from AuthModule or move to shared module)
- [x] 5.5 Verify TaskModule is imported in AppModule

## 6. Flutter: Task Repository

- [x] 6.1 Create `TaskRepository` at `apps/mobile/lib/features/task/data/task_repository.dart` with Dio
- [x] 6.2 Add methods: `getProjects()` → GET /tasks/projects, `getTasks(projectId, {stageId, sort, refresh})` → GET /tasks/projects/:id/tasks, `getTaskDetail(taskId)` → GET /tasks/:id, `getLogNotes(taskId)` → GET /tasks/:id/log-notes, `createLogNote(taskId, body)` → POST /tasks/:id/log-notes
- [x] 6.3 Create data models: `Project`, `Task`, `TaskStage`, `LogNote` (Dart classes with fromJson)
- [x] 6.4 Create `taskRepositoryProvider`

## 7. Flutter: Task Providers

- [x] 7.1 Create `projectListProvider` AsyncNotifier at `apps/mobile/lib/features/task/providers/task_providers.dart`: fetch projects from API, expose refresh method
- [x] 7.2 Create `taskStagesProvider` AsyncNotifier: fetch stages from API (used for filter chips)
- [x] 7.3 Create `taskListProvider(projectId)` family AsyncNotifier: fetch tasks for project, expose filter/sort/refresh methods
- [x] 7.4 Create `taskDetailProvider(taskId)` family AsyncNotifier: fetch task detail
- [x] 7.5 Create `logNotesProvider(taskId)` family AsyncNotifier: fetch log notes, expose createLogNote method with optimistic update

## 8. Flutter: Screens — Project List

- [x] 8.1 Create `ProjectListScreen` at `apps/mobile/lib/features/task/screens/project_list_screen.dart`: AppBar with "Dự án" title, pull-to-refresh ListView of project cards
- [x] 8.2 Project card widget: project name (textPrimary), manager name (textSecondary), task count badge. Tap → navigate to TaskListScreen
- [x] 8.3 Handle loading/error/empty states

## 9. Flutter: Screens — Task List

- [x] 9.1 Create `TaskListScreen` at `apps/mobile/lib/features/task/screens/task_list_screen.dart`: AppBar with project name, filter chips row (stages), sort dropdown
- [x] 9.2 Create `TaskCard` widget at `apps/mobile/lib/features/task/widgets/task_card.dart`: task name, stage badge (colored), deadline (red if overdue, amber if ≤3 days), priority stars, assignee avatars
- [x] 9.3 Implement stage filter: tap chip → update provider filter → rebuild list
- [x] 9.4 Implement sort: dropdown → update provider sort → rebuild list
- [x] 9.5 Pull-to-refresh: call provider refresh with force=true
- [x] 9.6 Tap task → navigate to TaskDetailScreen (or update detail panel on wide)

## 10. Flutter: Screens — Task Detail

- [x] 10.1 Create `TaskDetailScreen` at `apps/mobile/lib/features/task/screens/task_detail_screen.dart`: scrollable content + fixed log note input at bottom
- [x] 10.2 Task header: name (large), stage badge, deadline with relative text, priority stars, assignee row
- [x] 10.3 Description section: render task description text (handle HTML from Odoo — strip tags or use simple HTML rendering)
- [x] 10.4 Log notes section: list of log note cards (author name, relative date, body content)
- [x] 10.5 Log note input bar: TextField with surfaceVariant fill + gold send button, matching chat MessageInputBar style. Placeholder: "Nhập ghi chú..."
- [x] 10.6 Submit log note: call provider createLogNote → optimistic add to list → on error show SnackBar and remove

## 11. Flutter: Responsive Layout

- [x] 11.1 Create `TaskShellScreen` at `apps/mobile/lib/features/task/screens/task_shell_screen.dart`: on mobile (<768px) show ProjectListScreen as default, push navigation. On wide (≥768px) show 3-column layout: project sidebar (300px) + task list (flex) + task detail (flex)
- [x] 11.2 Wire selected project and selected task state for wide layout panel updates
- [x] 11.3 Handle empty states: no project selected → "Chọn dự án", no task selected → "Chọn task"

## 12. Flutter: Navigation

- [x] 12.1 Verify Tasks tab in bottom NavigationBar is wired to TaskShellScreen
- [x] 12.2 Add GoRouter routes: /tasks (project list / shell), /tasks/projects/:projectId (task list), /tasks/:taskId (task detail)
- [x] 12.3 Ensure back navigation works correctly on mobile

## 13. Verification

- [x] 13.1 Run `npm run lint` in apps/api — fix issues
- [x] 13.2 Run `npm run build` in apps/api — fix TypeScript errors
- [x] 13.3 Run `npm test` in apps/api — fix broken tests
- [x] 13.4 Run `flutter analyze` in apps/mobile — fix issues
- [ ] 13.5 Test with Odoo: verify projects load, tasks load per project, stages display correctly, log notes display, log note write works
- [ ] 13.6 Test cache: verify Redis caching works, pull-to-refresh invalidates cache
- [ ] 13.7 Test responsive: verify mobile push navigation + web master-detail layout
- [ ] 13.8 Test Odoo unavailable: verify graceful error handling when Odoo is down

