## Why

CHAT-FR-003 (Create Direct Conversation) is implemented but CHAT-FR-004 (Create Group Chat) and CHAT-FR-005 (Group Admin Management) are completely missing — both backend and Flutter. These are P1 SHOULD requirements needed for team collaboration in a <50 employee company.

Additionally, the user table is only populated when individual users login for the first time. There is no bulk sync from Odoo ERP, meaning the contact list (`GET /users`) is empty until people login. The SRS specifies "Employee profiles: Odoo → App, BullMQ cron, every 1 hour" but this has not been implemented. Without users in the database, neither direct nor group conversations can be created effectively.

## What Changes

Backend (NestJS):
- Add `OdooService.fetchEmployees()` method: authenticate as service account, call `hr.employee` `search_read` via Odoo JSON-RPC, return employee list with name, email, department, job_title
- Add `AuthService.syncUsersFromOdoo()`: upsert users from Odoo employee data, deactivate users no longer in Odoo
- Add seeder script `npm run seed:users` for one-time/dev sync
- Add BullMQ cron job for recurring hourly sync
- Add `POST /conversations/group` endpoint: create GROUP conversation with name, member_ids (min 2, max 200)
- Add `PATCH /conversations/:id` endpoint: update group name/avatar (admin/creator only)
- Add `POST /conversations/:id/members` endpoint: add members (admin/creator only)
- Add `DELETE /conversations/:id/members/:userId` endpoint: remove member or leave group
- Add `PATCH /conversations/:id/members/:userId` endpoint: change member role (creator only)
- Add `DELETE /conversations/:id` endpoint: delete group (creator only)
- Add system message generation for group events (create, add/remove member, rename, leave)

Flutter (Mobile):
- Update FAB on ChatListScreen: bottom sheet with "Chat mới" / "Tạo nhóm" options
- Create multi-select contact picker (Telegram-style: chip row + search + scrollable list)
- Create group name input screen (avatar placeholder + name field)
- Create group info screen (tap AppBar → member list, admin actions)
- Add ChatRepository methods for group CRUD operations
- Handle GROUP conversation display in ChatScreen (show group name in AppBar, sender names in messages)

## Capabilities

### New Capabilities
- `odoo-user-sync`: Bulk sync employees from Odoo ERP to users table via service account, with seeder script and BullMQ cron job
- `group-creation`: Backend API for creating GROUP conversations with name and multiple members
- `group-management`: Backend APIs for group admin actions (rename, add/remove members, change roles, delete group)
- `group-chat-flutter-ui`: Flutter screens for group creation flow (Telegram-style), group info/settings, and FAB update
- `system-messages`: Automatic system messages for group lifecycle events (created, member added/removed/left, renamed)

### Modified Capabilities
- None (all new capabilities)

## Impact

- **Backend**: New methods in OdooService, AuthService, ChatService. New DTOs. New BullMQ processor for user sync. New seeder script. 5 new REST endpoints.
- **Flutter**: New screens (GroupCreateMembersScreen, GroupCreateNameScreen, GroupInfoScreen). Modified ChatListScreen (FAB), ChatScreen (group AppBar), MessageBubble (sender name for groups). New ChatRepository methods.
- **Database**: No schema changes — existing tables (conversations, conversation_members, messages) already support GROUP type, roles, and system message type.
- **Dependencies**: No new dependencies needed.
- **External**: Odoo JSON-RPC calls using existing service account credentials (ODOO_SERVICE_USERNAME, ODOO_API_KEY).

