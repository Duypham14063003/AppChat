## ADDED Requirements

### Requirement: FAB shows bottom sheet with conversation options
The ChatListScreen FAB SHALL open a bottom sheet with two options: "Chat mới" (new direct chat) and "Tạo nhóm" (create group). "Chat mới" navigates to the existing ContactPickerScreen. "Tạo nhóm" navigates to the group creation flow.

#### Scenario: Tap FAB
- **WHEN** user taps the FAB on the chat list screen
- **THEN** a bottom sheet appears with "Chat mới" and "Tạo nhóm" options

#### Scenario: Select "Chat mới"
- **WHEN** user taps "Chat mới" in the bottom sheet
- **THEN** bottom sheet closes and app navigates to `/contacts/pick`

#### Scenario: Select "Tạo nhóm"
- **WHEN** user taps "Tạo nhóm" in the bottom sheet
- **THEN** bottom sheet closes and app navigates to `/group/create/members`

### Requirement: Group creation step 1 — multi-select contact picker
The app SHALL provide a `GroupCreateMembersScreen` at route `/group/create/members`. The screen SHALL display a search bar at top, a horizontal chip row showing selected contacts below it, and a scrollable contact list. Users tap contacts to select/deselect. Selected contacts appear as chips with an "x" to remove. A "Tiếp" (Next) button in the AppBar is enabled when at least 2 contacts are selected. Tapping "Tiếp" navigates to step 2 passing the selected member IDs.

#### Scenario: Select contacts for group
- **WHEN** user taps 3 contacts in the list
- **THEN** 3 chips appear in the chip row and the "Tiếp" button becomes enabled

#### Scenario: Deselect via chip
- **WHEN** user taps "x" on a chip
- **THEN** the contact is deselected and removed from the chip row

#### Scenario: Search contacts
- **WHEN** user types in the search bar
- **THEN** the contact list filters by name (debounced 300ms, server-side)

#### Scenario: Fewer than 2 selected
- **WHEN** user has selected only 1 contact
- **THEN** the "Tiếp" button is disabled/grayed out

### Requirement: Group creation step 2 — name and create
The app SHALL provide a `GroupCreateNameScreen` at route `/group/create/name`. The screen SHALL display a camera icon placeholder (for future avatar upload) on the left and a text field for group name on the right. A "Tạo nhóm" (Create) button is enabled when the name is non-empty. Tapping "Tạo nhóm" calls `POST /conversations/group` with the name and selected member IDs, then navigates to `/chat/:id`.

#### Scenario: Enter name and create
- **WHEN** user enters "Dev Team" and taps "Tạo nhóm"
- **THEN** app calls API, shows loading, then navigates to `/chat/:id` with the new group

#### Scenario: Empty name
- **WHEN** the name field is empty
- **THEN** the "Tạo nhóm" button is disabled

#### Scenario: API error
- **WHEN** the group creation API call fails
- **THEN** a snackbar error is shown and user remains on the name screen

### Requirement: Group info screen
The app SHALL provide a `GroupInfoScreen` accessible by tapping the AppBar in ChatScreen when the conversation type is GROUP. The screen SHALL display: group avatar (or placeholder), group name, member count, and a scrollable member list. Each member shows avatar, name, and role badge (Creator/Admin). If the current user is creator or admin, the screen SHALL show: "Thêm thành viên" button, edit name option, and member action menu (promote/demote, remove). All members see a "Rời nhóm" (Leave) option. The creator sees a "Xóa nhóm" (Delete) option.

#### Scenario: View group info
- **WHEN** user taps the AppBar in a GROUP conversation
- **THEN** app navigates to the group info screen showing group details and member list

#### Scenario: Admin adds member
- **WHEN** admin taps "Thêm thành viên" and selects contacts
- **THEN** selected contacts are added to the group via API

#### Scenario: Member leaves group
- **WHEN** member taps "Rời nhóm" and confirms
- **THEN** member is removed from the group and navigated back to chat list

### Requirement: ChatScreen handles GROUP conversations
The ChatScreen AppBar SHALL display the group name and member count for GROUP conversations. Tapping the AppBar navigates to GroupInfoScreen. The MessageBubble SHALL show sender name and avatar for all non-system, non-mine messages in GROUP conversations.

#### Scenario: Open group conversation
- **WHEN** user navigates to a GROUP conversation
- **THEN** AppBar shows group name and "X thành viên" subtitle

#### Scenario: Tap group AppBar
- **WHEN** user taps the AppBar in a GROUP conversation
- **THEN** app navigates to `/group/:id/info`

### Requirement: Navigation routes for group screens
The app SHALL register the following routes in go_router:
- `/group/create/members` → GroupCreateMembersScreen
- `/group/create/name` → GroupCreateNameScreen (receives member IDs via extra)
- `/group/:id/info` → GroupInfoScreen

#### Scenario: Navigate group creation flow
- **WHEN** user completes the group creation flow
- **THEN** navigation stack is: /chat → /chat/:id (group creation screens are replaced)

