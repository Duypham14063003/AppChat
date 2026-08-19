## Why

CHAT-FR-003 (Create Direct Conversation) is a P0 MUST requirement that is only partially implemented. The backend API (`POST /conversations`) and Flutter repository layer (`ChatRepository.createConversation()`) are complete, but the Flutter UI flow is missing — the FAB on ChatListScreen has `// TODO: New conversation dialog`. Users currently have no way to start a new conversation from the app. Additionally, the backend has no `GET /users` endpoint to list contacts for selection, which is required by the API specification (`srs/07-external-interfaces/api-specification.md`).

## What Changes

Backend (NestJS):
- Add `GET /users` endpoint to UserController: list active users with search/filter by name, exclude current user, return id/name/email/department/job_title/avatar_url
- Add pagination support (cursor-based or simple offset) for user listing

Flutter (Mobile):
- Create `ContactPickerScreen`: searchable list of active users fetched from `GET /users`, grouped by department
- Wire FAB on `ChatListScreen` to navigate to `ContactPickerScreen`
- On contact selection: call `ChatRepository.createConversation(memberId)` → navigate to `/chat/:id` with the returned conversation
- Add `GET /users` method to a new or existing repository
- Add `/contacts` route to go_router (or use a modal bottom sheet)

## Capabilities

### New Capabilities
- `user-contacts-api`: Backend endpoint `GET /users` to list active users for contact selection, with search by name and pagination
- `flutter-contact-picker`: Flutter screen for selecting a contact to start a new direct conversation, with search, department grouping, and conversation creation flow

### Modified Capabilities
- `flutter-chat-ui`: Wire the existing FAB button on ChatListScreen to open the contact picker and complete the new conversation flow

## Impact

- **Backend**: New `GET /users` endpoint in `UserController`, new service method in `AuthService` or a dedicated `UserService`, new DTO for user list response
- **Flutter**: New `ContactPickerScreen` widget, new `UserRepository` (or extend existing), new Riverpod provider for user list, route update in `app_router.dart`
- **API**: New public endpoint `GET /users?search=&cursor=&limit=` — requires JWT auth
- **Dependencies**: No new dependencies needed — uses existing Dio, Riverpod, go_router, TypeORM

