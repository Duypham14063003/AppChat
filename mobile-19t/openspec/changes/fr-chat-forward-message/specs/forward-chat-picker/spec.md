## ADDED Requirements

### Requirement: Chat picker screen for forward destination
The app SHALL provide a `ForwardChatPickerScreen` that displays the user's conversation list with multi-select capability. The screen SHALL include: a search bar to filter conversations, checkboxes on each conversation tile, selected conversation chips displayed above the list, and a send FAB button.

#### Scenario: Open chat picker
- **WHEN** ForwardChatPickerScreen opens
- **THEN** it displays all user's conversations sorted by `lastMessageAt` descending, with a search bar at top

#### Scenario: Search conversations
- **WHEN** user types "Dev" in the search bar
- **THEN** conversation list filters to show only conversations whose name contains "Dev"

### Requirement: Multi-select conversations
The user SHALL be able to select one or more conversations as forward destinations. Selected conversations SHALL appear as chips below the search bar.

#### Scenario: Select a conversation
- **WHEN** user taps a conversation in the picker
- **THEN** a checkbox appears checked, and a chip with the conversation name appears in the chips row

#### Scenario: Deselect a conversation
- **WHEN** user taps a selected conversation or its chip
- **THEN** the checkbox unchecks and the chip is removed

### Requirement: Privacy toggle for anonymous forwarding
The ForwardChatPickerScreen SHALL include an "Ẩn nguồn" (Hide source) toggle switch. When enabled, forwarded messages SHALL not include the original sender's name.

#### Scenario: Toggle hide source on
- **WHEN** user enables "Ẩn nguồn" toggle
- **THEN** the toggle is on, and when messages are forwarded, `hide_sender` is set to `true`

#### Scenario: Toggle hide source off (default)
- **WHEN** ForwardChatPickerScreen opens
- **THEN** "Ẩn nguồn" toggle is off by default

### Requirement: Send forward from chat picker
Tapping the send FAB SHALL trigger the forward operation, sending all selected messages to all selected conversations with the current hide_sender setting. After successful forward, the screen SHALL pop back to ChatScreen and exit selection mode. A SnackBar SHALL confirm the action.

#### Scenario: Forward 2 messages to 3 conversations
- **WHEN** user taps send FAB with 2 messages and 3 conversations selected
- **THEN** forward_message WS event is sent, screen pops back, selection mode exits, SnackBar shows "Đã chuyển tiếp 2 tin nhắn đến 3 cuộc trò chuyện"

#### Scenario: No conversation selected
- **WHEN** no conversations are selected
- **THEN** send FAB is disabled (greyed out)

