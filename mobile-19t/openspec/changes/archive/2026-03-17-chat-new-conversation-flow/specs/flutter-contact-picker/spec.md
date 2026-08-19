## ADDED Requirements

### Requirement: Contact picker screen displays searchable user list
The Flutter app SHALL provide a `ContactPickerScreen` that displays a list of active users fetched from `GET /users`. The screen SHALL include a search bar at the top that filters users by name in real-time (server-side). Users SHALL be displayed with avatar, name, department, and job title.

#### Scenario: Open contact picker
- **WHEN** user navigates to the contact picker screen
- **THEN** a list of active users is loaded from the server and displayed, sorted by name

#### Scenario: Search contacts by name
- **WHEN** user types "Ngoc" in the search bar
- **THEN** the list filters to show only users matching "Ngoc" (debounced 300ms, server-side search)

#### Scenario: Empty search results
- **WHEN** user searches for a name with no matches
- **THEN** "Không tìm thấy liên hệ" is displayed

#### Scenario: Loading state
- **WHEN** contacts are being fetched from server
- **THEN** a loading indicator (shimmer or circular progress) is displayed

#### Scenario: Error state
- **WHEN** the server request fails
- **THEN** an error message is displayed with a retry button

### Requirement: Contact selection creates conversation and navigates to chat
The Flutter app SHALL create a direct conversation when a user taps a contact in the picker. If the conversation already exists, the app SHALL navigate to the existing conversation. The app SHALL show a loading indicator during conversation creation.

#### Scenario: Tap contact to start new conversation
- **WHEN** user taps on contact "Tran Ngoc" who has no existing direct conversation
- **THEN** app calls `POST /conversations { member_id: "<tran_ngoc_id>" }`, shows loading, then navigates to `/chat/:id` with the new conversation

#### Scenario: Tap contact with existing conversation
- **WHEN** user taps on contact "Tran Ngoc" who already has a direct conversation
- **THEN** app calls `POST /conversations { member_id: "<tran_ngoc_id>" }`, server returns existing conversation, app navigates to `/chat/:id`

#### Scenario: Conversation creation fails
- **WHEN** user taps a contact but the API call fails
- **THEN** a snackbar error message is shown and user remains on the contact picker screen

### Requirement: Contact picker navigation route
The Flutter app SHALL register a route `/contacts/pick` in go_router that displays the `ContactPickerScreen`. The route SHALL be accessible from the ChatListScreen FAB.

#### Scenario: Navigate to contact picker from FAB
- **WHEN** user taps the FAB (floating action button) on the chat list screen
- **THEN** app navigates to `/contacts/pick` showing the contact picker

#### Scenario: Return to chat list after conversation created
- **WHEN** conversation is created and user navigates to `/chat/:id`
- **THEN** the contact picker is removed from the navigation stack (replaced, not pushed)

