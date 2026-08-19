## ADDED Requirements

### Requirement: Long-press context menu with forward action
The ChatScreen SHALL show a context menu (bottom sheet) when a non-system message is long-pressed. The menu SHALL include a "Chuyển tiếp" (Forward) action with `Icons.forward` icon.

#### Scenario: Long-press a text message
- **WHEN** user long-presses a text message bubble
- **THEN** a bottom sheet appears with actions including "Chuyển tiếp"

#### Scenario: Long-press a system message
- **WHEN** user long-presses a system message (e.g., "X created group")
- **THEN** no context menu appears

### Requirement: Enter multi-select mode from context menu
Tapping "Chuyển tiếp" in the context menu SHALL enter selection mode with the long-pressed message pre-selected. The AppBar SHALL change to show: close button [✕], selected count text "[N] đã chọn", and forward button [➤].

#### Scenario: Tap forward in context menu
- **WHEN** user taps "Chuyển tiếp" in the context menu
- **THEN** ChatScreen enters selection mode with the message selected, AppBar shows "[1] đã chọn" and forward button

### Requirement: Toggle message selection in selection mode
In selection mode, tapping a non-system message SHALL toggle its selection state. A checkbox or visual indicator SHALL appear on each message to show selection state.

#### Scenario: Tap to select additional message
- **WHEN** user taps another message while in selection mode
- **THEN** that message is added to selection, count updates to "[2] đã chọn"

#### Scenario: Tap to deselect a selected message
- **WHEN** user taps an already-selected message
- **THEN** that message is removed from selection, count decreases

#### Scenario: Deselect all messages
- **WHEN** user deselects the last selected message
- **THEN** selection mode exits, normal AppBar and input bar return

### Requirement: Exit selection mode
Tapping the close button [✕] in the selection AppBar SHALL exit selection mode, clear all selections, and restore the normal AppBar and input bar.

#### Scenario: Tap close button
- **WHEN** user taps [✕] in selection AppBar
- **THEN** selection mode exits, all selections cleared, normal UI restored

### Requirement: Hide input bar in selection mode
The MessageInputBar SHALL be hidden when selection mode is active. It SHALL reappear when selection mode exits.

#### Scenario: Enter selection mode
- **WHEN** selection mode activates
- **THEN** MessageInputBar is not visible

### Requirement: Forward button opens chat picker
Tapping the forward button [➤] in the selection AppBar SHALL navigate to `ForwardChatPickerScreen`, passing the list of selected message IDs.

#### Scenario: Tap forward button with 3 messages selected
- **WHEN** user taps [➤] with 3 messages selected
- **THEN** ForwardChatPickerScreen opens with those 3 message IDs

