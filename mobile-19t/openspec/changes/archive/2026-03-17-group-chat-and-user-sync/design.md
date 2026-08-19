## Context

The app has working DIRECT conversations (FR-003) but no group chat (FR-004/005) and no bulk user sync from Odoo. Users are only created on first login, leaving the contact list empty for new deployments. The DB schema already supports GROUP conversations (type, name, avatar_url, member roles) — no migrations needed.

Current architecture:
- Backend: NestJS, TypeORM, `ChatService` has `createDirectConversation()` but no group methods. `OdooService` only has `authenticate()`.
- Flutter: `ContactPickerScreen` for single-select, `ChatScreen` with hardcoded "Chat" AppBar, `MessageBubble` without sender info for groups.
- Odoo: JSON-RPC API at `erp.19t.vn`, service account `meeting-service@19t.vn`, `hr.employee` model has name, work_email, department_id, job_title.
- Config: `ODOO_SERVICE_USERNAME`, `ODOO_API_KEY` env vars already defined in Joi schema.

## Goals / Non-Goals

**Goals:**
- Bulk sync all active employees from Odoo to users table (seeder + cron)
- Create group conversations with name and multiple members (Telegram-style flow)
- Full group admin management (rename, add/remove members, change roles, delete)
- System messages for group lifecycle events
- Flutter UI for group creation, group info, and group chat display

**Non-Goals:**
- Avatar upload (Bunny.net integration — separate change)
- Invite links for groups
- Granular admin permissions (Telegram-style per-permission toggles — overkill for <50 employees)
- Group description field
- Public/private group types
- E2E encryption

## Decisions

### D1: Odoo sync approach
**Decision**: Two-pronged: (1) `npm run seed:users` CLI script for dev/initial setup, (2) BullMQ cron job every 1 hour for production. Both call the same `AuthService.syncUsersFromOdoo()` method.
**Rationale**: Seeder gives immediate control for development. Cron job matches SRS spec ("Employee profiles: Odoo → App, BullMQ cron, every 1 hour"). Shared logic avoids duplication.

### D2: Odoo authentication for service account
**Decision**: Authenticate via `POST /web/session/authenticate` with `ODOO_SERVICE_USERNAME` + `ODOO_SERVICE_PASSWORD` to get a session UID, then use that UID + `ODOO_API_KEY` for `execute_kw` calls. Cache the session UID in memory (re-authenticate if expired).
**Rationale**: Odoo JSON-RPC requires a UID for `execute_kw`. The service account authenticates once, then uses the UID for subsequent calls. API key replaces password in `execute_kw` args per Odoo 14+ API key support.

### D3: Employee-to-user mapping
**Decision**: Map `hr.employee` records to `users` table. Use Odoo's employee `id` field as a stable identifier to find the linked `res.users` record's `id` for `odoo_uid`. Map: `name` → `name`, `work_email` → `email`, `department_id[1]` → `department`, `job_title` → `job_title`. Employees without `work_email` are skipped.
**Rationale**: `hr.employee` has department and job_title directly. The `user_id` M2O field on employee links to `res.users` which provides the `id` used as `odoo_uid` in our system.

### D4: Group creation flow (Telegram-style)
**Decision**: Members first → Name second. Step 1: multi-select contact picker with chip row + search. Step 2: name input + avatar placeholder + create button. Minimum 2 members (excluding creator).
**Rationale**: Telegram's proven UX pattern. Members-first lets users see who they're grouping before naming. Avatar placeholder is non-functional (upload in future change).

### D5: Role model (simplified)
**Decision**: Three roles: `creator` (immutable, one per group), `admin` (can manage members and group info), `member` (chat only). Only creator can change roles and delete group. Creator and admin can add/remove members and rename.
**Rationale**: Telegram has granular per-permission admin rights — overkill for <50 employees. Three simple roles cover all FR-005 requirements.
**Note**: The `conversation_members.role` column is varchar(10). Need to ensure `creator` fits (7 chars — OK).

### D6: System messages storage
**Decision**: Store as regular messages with `type = 'system'`. The `content` field stores an action key (e.g., "added_member"). The `metadata` JSONB field stores structured data for rendering (actor_name, member_name, etc.). `sender_id` is the actor who performed the action.
**Rationale**: Reuses existing message infrastructure (storage, pagination, real-time delivery via Redis Pub/Sub). No new tables needed. Flutter renders system messages differently based on `type`.

### D7: Group deletion strategy
**Decision**: Soft-delete: remove all `conversation_members` rows, soft-delete messages (set `deleted_at`), and mark conversation with a flag. The conversation row is kept for audit purposes.
**Rationale**: Hard delete of partitioned messages is complex and risky. Soft delete is simpler and allows potential recovery.

### D8: Navigation for group creation
**Decision**: Use `go_router` with `extra` parameter to pass selected member IDs from step 1 to step 2. After group creation, use `context.go('/chat/$convId')` to replace the creation flow with the chat screen, keeping `/chat` in the back stack via ShellRoute.
**Rationale**: `extra` is the standard go_router way to pass complex data between routes. The creation screens are transient and should not remain in the back stack.

## Risks / Trade-offs

- **[Risk] Odoo service account credentials**: If not configured, sync silently skips (graceful degradation). Dev can use seeder script with test data.
- **[Risk] Odoo employee without work_email**: Skipped during sync. Logged as warning. These employees cannot use the app anyway (no email = no login).
- **[Risk] Large employee count**: For <50 employees, full sync is fine. If company grows to 1000+, may need delta sync. Not a concern now.
- **[Trade-off] No avatar upload**: Group avatar placeholder is non-functional. Acceptable for v1 — upload infrastructure is a separate concern.
- **[Trade-off] creator role in varchar(10)**: Fits (7 chars) but tight. If future roles are longer, column may need widening. Low risk.
- **[Trade-off] System messages as regular messages**: Increases message count in partitioned table. Negligible impact for <50 employee company with group events.

