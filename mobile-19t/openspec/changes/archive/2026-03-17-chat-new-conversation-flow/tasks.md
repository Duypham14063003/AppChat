## 1. Backend: User Listing API

- [x] 1.1 Add `GET /users` endpoint to `UserController`: accept query params `search` (string, optional), `cursor` (uuid, optional), `limit` (number, default 50). Apply `@ApiBearerAuth()` auth guard
- [x] 1.2 Create `ListUsersDto` in `apps/api/src/modules/auth/dto/auth.dto.ts`: validate search (optional string), cursor (optional UUID), limit (optional number, max 100)
- [x] 1.3 Add `listUsers(currentUserId, search?, cursor?, limit?)` method to `AuthService` (or create `UserService`): query `User` entity WHERE `is_active = true` AND `id != currentUserId`, with optional `ILIKE` search on name/email, cursor-based pagination by name+id, return `{ users, total, nextCursor, hasMore }`
- [x] 1.4 Map user response to safe DTO: return only id, name, email, department, jobTitle, avatarUrl (no sensitive fields)

## 2. Flutter: User Repository & Provider

- [x] 2.1 Create `UserRepository` in `apps/mobile/lib/features/chat/data/user_repository.dart`: method `getUsers({String? search, String? cursor, int limit = 50})` calling `GET /users` via Dio
- [x] 2.2 Create `UserContact` model class in `apps/mobile/lib/features/chat/data/user_repository.dart`: fields id, name, email, department, jobTitle, avatarUrl, with `fromJson` factory
- [x] 2.3 Create `userRepositoryProvider` in `apps/mobile/lib/features/chat/providers/chat_providers.dart`

## 3. Flutter: Contact Picker Screen

- [x] 3.1 Create `ContactPickerScreen` widget in `apps/mobile/lib/features/chat/screens/contact_picker_screen.dart`: Scaffold with AppBar (title "Tin nhắn mới", search bar), body with user list
- [x] 3.2 Create `contactListProvider` (Riverpod FutureProvider.family with search query): fetch users from `UserRepository`, support debounced search
- [x] 3.3 Implement contact list item widget: ListTile with CircleAvatar (initials or avatar_url), name, department/job_title subtitle
- [x] 3.4 Implement search: TextField in AppBar with 300ms debounce, triggers `contactListProvider` refetch with search term
- [x] 3.5 Implement contact tap handler: show loading overlay → call `ChatRepository.createConversation(memberId)` → navigate to `/chat/:id` (replace route, not push)
- [x] 3.6 Handle error states: show snackbar on conversation creation failure, show error + retry on user list fetch failure
- [x] 3.7 Handle empty state: show "Không tìm thấy liên hệ" when search returns no results

## 4. Flutter: Navigation & Wiring

- [x] 4.1 Add `/contacts/pick` route to `app_router.dart` → `ContactPickerScreen`
- [x] 4.2 Wire FAB `onPressed` in `ChatListScreen` to `context.push('/contacts/pick')`

## 5. Verification

- [x] 5.1 Verify: `GET /users` returns active users, excludes current user, excludes deactivated users
- [x] 5.2 Verify: `GET /users?search=<term>` filters by name/email case-insensitively
- [x] 5.3 Verify: Contact picker loads, search works, tap creates conversation and navigates to chat
- [x] 5.4 Run `npm run lint` and `npm run build` in apps/api — no errors
- [x] 5.5 Run `flutter analyze` in apps/mobile — no errors

