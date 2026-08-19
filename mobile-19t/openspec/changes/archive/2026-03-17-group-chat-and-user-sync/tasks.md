## 1. Odoo User Sync — Backend

- [x] 1.1 Add `fetchEmployees()` method to `OdooService` (`apps/api/src/modules/auth/services/odoo.service.ts`): authenticate as service account via `POST {ODOO_URL}/web/session/authenticate` using `ODOO_SERVICE_USERNAME` + `ODOO_SERVICE_PASSWORD`, cache the session UID. Then call `POST {ODOO_URL}/jsonrpc` with `execute_kw` args `[db, uid, ODOO_API_KEY, "hr.employee", "search_read", [["active","=",true]], {fields: ["name","work_email","department_id","job_title","user_id"]}]`. Return typed array. Handle: Odoo unreachable (throw ServiceUnavailableException), credentials not configured (log warning, return []).
- [x] 1.2 Add `syncUsersFromOdoo()` method to `AuthService` (`apps/api/src/modules/auth/services/auth.service.ts`): call `fetchEmployees()`, for each employee with `work_email`: upsert into `users` table matching on `odoo_uid` (from employee's `user_id[0]` or employee `id`). Map: name→name, work_email→email, department_id[1]→department, job_title→job_title. Set `is_active=true`. After upsert, find users whose `odoo_uid` NOT IN the fetched set → set `is_active=false`. Return `{ created, updated, deactivated }` counts.
- [x] 1.3 Create seeder script `apps/api/scripts/seed-users.ts`: bootstrap NestJS app context, get `AuthService`, call `syncUsersFromOdoo()`, log results, exit. Add `"seed:users": "tsx scripts/seed-users.ts"` to `apps/api/package.json` scripts.
- [x] 1.4 Create `UserSyncProcessor` BullMQ worker (`apps/api/src/modules/auth/jobs/user-sync.processor.ts`): `@Processor('user-sync')`, calls `AuthService.syncUsersFromOdoo()`. Register queue in `AuthModule` with `BullModule.registerQueue({ name: 'user-sync' })`. Add repeatable job config: `{ every: 3600000 }` (1 hour).
- [ ] 1.5 Verify: run `npm run seed:users` → users table populated from Odoo. Check created/updated/deactivated counts.

## 2. Group Creation — Backend

- [x] 2.1 Create `CreateGroupDto`
- [x] 2.2 Add `createGroupConversation(userId, name, memberIds)` method to `ChatService`
- [x] 2.3 Add `POST /conversations/group` endpoint to `ConversationController`
- [ ] 2.4 Verify: `POST /conversations/group { name: "Test", member_ids: [...] }` creates group, returns conversation with members, system message inserted.

## 3. Group Management — Backend

- [x] 3.1 Create `UpdateConversationDto`
- [x] 3.2 Create `AddMembersDto`
- [x] 3.3 Create `UpdateMemberRoleDto`
- [x] 3.4 Add `updateConversation(convId, userId, dto)` to `ChatService`
- [x] 3.5 Add `addMembers(convId, userId, memberIds)` to `ChatService`
- [x] 3.6 Add `removeMember(convId, actorId, targetUserId)` to `ChatService`
- [x] 3.7 Add `updateMemberRole(convId, actorId, targetUserId, role)` to `ChatService`
- [x] 3.8 Add `deleteGroup(convId, userId)` to `ChatService`
- [x] 3.9 Add REST endpoints to `ConversationController`
- [ ] 3.10 Verify: test all 5 endpoints with correct and incorrect roles. Verify system messages are generated.

## 4. System Messages — Backend Helper

- [x] 4.1 Add `insertSystemMessage(convId, actorId, contentKey, metadata)` private helper to `ChatService`
- [x] 4.2 Refactor group creation/management methods (tasks 2.2, 3.4-3.8) to use `insertSystemMessage()` helper.
- [ ] 4.3 Verify: system messages appear in `GET /conversations/:id/messages` response with correct type and metadata.

## 5. Flutter: FAB Bottom Sheet

- [x] 5.1 In `ChatListScreen`: replace FAB with bottom sheet (`apps/mobile/lib/features/chat/screens/chat_list_screen.dart`): replace FAB `onPressed` direct navigation with `showModalBottomSheet`. Bottom sheet shows two ListTile options: Icon(Icons.chat) "Chat mới" → `context.push('/contacts/pick')`, Icon(Icons.group_add) "Tạo nhóm" → `context.push('/group/create/members')`. Close bottom sheet before navigating.
- [ ] 5.2 Verify: FAB opens bottom sheet, both options navigate correctly.

## 6. Flutter: Group Creation Flow

- [x] 6.1 Create `GroupCreateMembersScreen`
- [x] 6.2 Create `GroupCreateNameScreen`
- [x] 6.3 Add `createGroupConversation(String name, List<String> memberIds)` to `ChatRepository`
- [x] 6.4 Add routes to `app_router.dart`
- [ ] 6.5 Verify: full flow — FAB → "Tạo nhóm" → select members → "Tiếp" → enter name → "Tạo nhóm" → chat screen opens.

## 7. Flutter: Group Info Screen

- [x] 7.1 Create `GroupInfoScreen`
- [x] 7.2 Add group management methods to `ChatRepository`
- [ ] 7.3 Verify: group info screen loads, admin actions work, leave group works.

## 8. Flutter: ChatScreen Group Support

- [x] 8.1 In `ChatScreen`: detect conversation type, show group name in AppBar, make tappable to GroupInfoScreen
- [x] 8.2 In `MessageBubble`: sender info for GROUP conversations handled via existing senderName/senderAvatar params
- [x] 8.3 Add system message rendering in ChatScreen
- [ ] 8.4 Verify: group chat shows group name in AppBar, sender names on messages, system messages rendered correctly.

## 9. Verification

- [ ] 9.1 Run `npm run lint` and `npm run build` in `apps/api` — no errors
- [ ] 9.2 Run `flutter analyze` in `apps/mobile` — no errors
- [ ] 9.3 E2E: seed users → create group → send messages → see sender names → add member → see system message → leave group → back to list
- [ ] 9.4 E2E: group admin renames group → system message appears → member sees updated name

