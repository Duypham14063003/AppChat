## ADDED Requirements

### Requirement: Unified long-press context menu
The system SHALL replace the current `ReactionPicker` overlay on long-press with a `showModalBottomSheet` context menu. The bottom sheet SHALL have a quick reaction row at the top (same 6 emojis: 😀 😂 ❤️ 👍 😢 🔥 plus expand button) followed by action items as `ListTile` entries. The bottom sheet SHALL use `AppColors.surface` background with 16px top border radius, matching existing bottom sheet patterns.

#### Scenario: Long-press opens context menu
- **WHEN** the user long-presses a non-system message bubble
- **THEN** a modal bottom sheet appears with quick reaction row and action list

#### Scenario: System messages excluded
- **WHEN** the user long-presses a system message
- **THEN** no context menu appears (same as current behavior)

### Requirement: Quick reaction row in context menu
The system SHALL display a horizontal row of quick reaction emojis (😀 😂 ❤️ 👍 😢 🔥) at the top of the context menu bottom sheet, plus an expand button to open the full emoji picker. Tapping an emoji SHALL toggle the reaction (same as current behavior), dismiss the bottom sheet, and call `toggleReaction`.

#### Scenario: Tap quick reaction emoji
- **WHEN** the user taps ❤️ in the quick reaction row
- **THEN** the reaction is toggled on the message, the bottom sheet dismisses

#### Scenario: Tap expand button
- **WHEN** the user taps the [+] expand button in the reaction row
- **THEN** the full emoji picker opens (existing behavior)

### Requirement: Pin action in context menu
The system SHALL display a "📌 Ghim tin nhắn" action in the context menu when the user has pin permission and the message is not already pinned. When the message is already pinned, the action SHALL show "📌 Bỏ ghim". Tapping the action SHALL call the pin/unpin API via ChatRepository, dismiss the bottom sheet, and show a brief SnackBar confirmation.

#### Scenario: Pin action shown for admin in GROUP
- **WHEN** an admin long-presses a message in a GROUP conversation
- **THEN** the context menu shows "📌 Ghim tin nhắn"

#### Scenario: Pin action hidden for non-admin in GROUP
- **WHEN** a regular member long-presses a message in a GROUP conversation
- **THEN** the context menu does NOT show the pin action

#### Scenario: Pin action shown for any member in DIRECT
- **WHEN** any member long-presses a message in a DIRECT conversation
- **THEN** the context menu shows "📌 Ghim tin nhắn"

#### Scenario: Unpin action shown for pinned message
- **WHEN** a user with pin permission long-presses a pinned message
- **THEN** the context menu shows "📌 Bỏ ghim" instead of "Ghim tin nhắn"

#### Scenario: Pin limit feedback
- **WHEN** a user taps "Ghim tin nhắn" but the conversation already has 5 pins
- **THEN** the API returns 400 and a SnackBar shows "Tối đa 5 tin nhắn được ghim"

### Requirement: Future action slots in context menu
The system SHALL include disabled/placeholder action items for "↩️ Trả lời", "📋 Sao chép", and "🗑️ Xóa" in the context menu. These items SHALL be visually present but non-functional (greyed out or hidden based on implementation preference). This ensures forward-compatibility with `fr-chat-reply-message` and future changes.

#### Scenario: Future actions visible but inactive
- **WHEN** the context menu is displayed
- **THEN** Reply, Copy, and Delete action slots are present in the menu structure for future activation

### Requirement: Double-tap reaction preserved
The system SHALL preserve the existing double-tap gesture on message bubbles to toggle ❤️ reaction. This behavior is independent of the context menu change.

#### Scenario: Double-tap still works
- **WHEN** the user double-taps a message bubble
- **THEN** the ❤️ reaction is toggled (same as current behavior)

### Requirement: Context menu receives message context
The context menu bottom sheet SHALL receive the message data, conversation type, user's role in the conversation, and pinned status of the message. This context determines which actions are visible and their labels.

#### Scenario: Context menu adapts to message state
- **WHEN** the context menu opens for a pinned message in a GROUP conversation where the user is admin
- **THEN** the menu shows "Bỏ ghim" (not "Ghim"), quick reactions, and future action slots

