## Context

CHAT-FR-003 requires users to select a contact and start a direct conversation. The backend `POST /conversations` endpoint and Flutter `ChatRepository.createConversation()` are already implemented. What's missing:

1. **Backend**: No `GET /users` endpoint exists. The API spec (`srs/07-external-interfaces/api-specification.md`) defines `GET /users` for listing contacts, but `UserController` only has `PATCH :id/deactivate`.
2. **Flutter**: The FAB on `ChatListScreen` has `// TODO: New conversation dialog`. No contact selection UI exists.

Current architecture:
- Backend: NestJS with TypeORM, `User` entity has id, name, email, department, job_title, avatar_url, is_active
- Flutter: Riverpod for state, Dio for HTTP, go_router for navigation
- Auth: JWT-based, `@CurrentUser('userId')` decorator extracts user from token

## Goals / Non-Goals

**Goals:**
- Users can tap FAB → see searchable contact list → tap contact → conversation created → navigate to chat
- Backend provides paginated, searchable user listing endpoint
- Reuse existing patterns (Riverpod providers, Dio repository, go_router)

**Non-Goals:**
- Group chat creation (CHAT-FR-004, separate change)
- User profile viewing from contact list
- Contact favorites or recent contacts
- Offline contact caching (contacts are always fetched fresh)

## Decisions

### D1: User listing endpoint location
**Decision**: Add `GET /users` to existing `UserController` in auth module, with a new `UserService` method.
**Rationale**: The `User` entity lives in the auth module. Adding a dedicated contacts module would be over-engineering for a simple list query. The `UserController` already exists at `/users`.
**Alternative**: Create a separate `ContactsController` — rejected because it would duplicate user entity access and add unnecessary module coupling.

### D2: Contact picker UI pattern
**Decision**: Full-screen `ContactPickerScreen` navigated via go_router (`/contacts/pick`), not a modal bottom sheet.
**Rationale**: A full screen provides room for search bar, department grouping, and scrolling through potentially hundreds of employees. Bottom sheets are awkward for long lists with search.
**Alternative**: Modal bottom sheet — rejected for UX reasons with large contact lists.

### D3: Search implementation
**Decision**: Server-side search via `GET /users?search=<term>` using SQL `ILIKE` on name and email columns.
**Rationale**: Simple, effective for the expected user count (< 1000 employees). No need for FTS or Elasticsearch at this scale.
**Alternative**: Client-side filtering — rejected because it requires loading all users upfront.

### D4: Conversation creation flow
**Decision**: On contact tap → call `POST /conversations` → on success navigate to `/chat/:id`. Show loading indicator during API call. If conversation already exists, API returns existing one (idempotent).
**Rationale**: Leverages existing idempotent `createDirectConversation` logic. No client-side duplicate check needed.

## Risks / Trade-offs

- **[Risk] Large user list performance** → Mitigated by server-side pagination (limit=50) and search. For < 1000 users this is not a real concern.
- **[Risk] Race condition on conversation creation** → Mitigated by existing backend idempotency (returns existing conversation if duplicate).
- **[Trade-off] No offline contact cache** → Contacts require network. Acceptable because starting a new conversation inherently requires network to call `POST /conversations`.

