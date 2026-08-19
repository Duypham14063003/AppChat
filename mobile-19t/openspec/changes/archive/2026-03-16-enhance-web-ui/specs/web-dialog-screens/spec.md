## ADDED Requirements

### Requirement: Contact picker renders as dialog on wide screens
On screens ≥768px, the `ContactPickerScreen` content SHALL be displayed inside a centered `Dialog` constrained to 480px width and 600px height, instead of as a full-screen page. On narrow screens, the existing full-screen behavior SHALL be preserved.

#### Scenario: Wide screen shows contact picker as dialog
- **GIVEN** the app is on a screen ≥768px wide
- **WHEN** the user initiates "Chat mới" (new direct chat)
- **THEN** a dialog appears with the contact picker content (search bar + contact list)

#### Scenario: Narrow screen shows contact picker full-screen
- **GIVEN** the app is on a screen <768px wide
- **WHEN** the user initiates "Chat mới"
- **THEN** the contact picker opens as a full-screen page (existing behavior)

### Requirement: Group creation screens render as dialogs on wide screens
On screens ≥768px, `GroupCreateMembersScreen` and `GroupCreateNameScreen` SHALL be displayed inside centered dialogs (480px width, 600px height). The two-step flow (members → name) SHALL work within dialogs — step 1 dialog closes and step 2 dialog opens. On narrow screens, existing full-screen push behavior is preserved.

#### Scenario: Wide screen group member selection as dialog
- **GIVEN** the app is on a wide screen
- **WHEN** the user initiates "Tạo nhóm"
- **THEN** a dialog appears with the multi-select contact picker

#### Scenario: Wide screen group name input as dialog
- **GIVEN** the user selected members in the dialog and tapped "Tiếp"
- **WHEN** the group name screen opens
- **THEN** it appears as a dialog with the name input field

### Requirement: New chat action uses popup menu on wide screens
On screens ≥768px, the FAB's `onPressed` SHALL show a `PopupMenuButton`-style popup menu with "Chat mới" and "Tạo nhóm" options instead of a `ModalBottomSheet`. On narrow screens, the existing `ModalBottomSheet` behavior SHALL be preserved.

#### Scenario: Wide screen FAB shows popup menu
- **GIVEN** the app is on a wide screen
- **WHEN** the user taps the FAB (+) button
- **THEN** a popup menu appears near the FAB with "Chat mới" and "Tạo nhóm" options

#### Scenario: Narrow screen FAB shows bottom sheet
- **GIVEN** the app is on a narrow screen
- **WHEN** the user taps the FAB (+) button
- **THEN** a modal bottom sheet appears (existing behavior)
