## ADDED Requirements

### Requirement: Long-press message shows reaction picker
The system SHALL display a floating reaction picker overlay when the user long-presses a message bubble. The picker SHALL show 6 quick-access emoji: 👍 ❤️ 😂 😮 😢 🔥, plus an expand button (⋯) that opens a full emoji picker.

#### Scenario: Long-press on a text message
- **WHEN** user long-presses a message bubble
- **THEN** a reaction picker overlay appears above the message with 6 emoji + expand button

#### Scenario: Long-press on media message
- **WHEN** user long-presses an image, video, or voice message bubble
- **THEN** the same reaction picker overlay appears

#### Scenario: Picker does not show for system messages
- **WHEN** user long-presses a system message (e.g., "X created group")
- **THEN** no reaction picker is shown

### Requirement: Double-tap sends heart reaction
The system SHALL send a ❤️ reaction when the user double-taps a message bubble. If the user already has a ❤️ reaction on that message, double-tap SHALL remove it (toggle behavior).

#### Scenario: Double-tap to add heart
- **WHEN** user double-taps a message they haven't reacted ❤️ to
- **THEN** a ❤️ reaction is toggled (added)

#### Scenario: Double-tap to remove heart
- **WHEN** user double-taps a message they already reacted ❤️ to
- **THEN** the ❤️ reaction is toggled (removed)

### Requirement: Quick emoji selection from picker
When the user taps one of the 6 quick-access emoji in the picker, the system SHALL send a `toggle_reaction` for that emoji and dismiss the picker.

#### Scenario: Tap quick emoji
- **WHEN** user taps 👍 in the reaction picker
- **THEN** a `toggle_reaction` event is sent with `emoji: "👍"` and the picker dismisses

### Requirement: Full emoji picker via expand button
When the user taps the expand button (⋯) in the quick picker, the system SHALL open a full emoji picker (using `emoji_picker_flutter`). Selecting an emoji from the full picker SHALL send a `toggle_reaction` and dismiss both pickers.

#### Scenario: Open full picker and select
- **WHEN** user taps ⋯, then selects 🎉 from the full emoji picker
- **THEN** a `toggle_reaction` event is sent with `emoji: "🎉"` and all pickers dismiss

### Requirement: Reaction bar displays below message bubble
When a message has reactions, the system SHALL display a `ReactionBar` widget below the message bubble. Each unique emoji SHALL be shown as a chip with the emoji and its count (e.g., "👍 3"). The user's own reactions SHALL be visually highlighted (different background/border).

#### Scenario: Message with reactions
- **WHEN** a message has reactions [👍×3, 😂×1]
- **THEN** a reaction bar appears below the bubble showing "👍 3" and "😂 1" chips

#### Scenario: Own reaction highlighted
- **WHEN** the current user has reacted 👍 to a message
- **THEN** the 👍 chip in the reaction bar has a highlighted style (e.g., accent border/background)

#### Scenario: Message with no reactions
- **WHEN** a message has zero reactions
- **THEN** no reaction bar is displayed

### Requirement: Tap reaction chip to toggle own reaction
When the user taps a reaction chip in the reaction bar, the system SHALL toggle their reaction for that emoji. If they already reacted with that emoji, it is removed. If not, it is added.

#### Scenario: Tap to add same emoji
- **WHEN** user taps the "😂 2" chip and has not reacted 😂
- **THEN** a `toggle_reaction` is sent for 😂 (adding it)

#### Scenario: Tap to remove own emoji
- **WHEN** user taps the "👍 3" chip and has already reacted 👍
- **THEN** a `toggle_reaction` is sent for 👍 (removing it)

### Requirement: Reaction details bottom sheet
When the user long-presses (or taps) a reaction chip, the system SHALL show a bottom sheet listing who reacted with which emoji. The sheet SHALL have filter tabs: "All", and one tab per unique emoji with count.

#### Scenario: View reaction details
- **WHEN** user taps a reaction chip in the reaction bar
- **THEN** a bottom sheet appears with tabs [All (6), 👍 (3), 😂 (2), ❤️ (1)] and a list of users with their reactions

### Requirement: Reaction picker animation
The reaction picker SHALL appear with a staggered scale-in animation. Each emoji scales from 0 to 1 with `Curves.elasticOut` over 200ms, staggered 30ms apart.

#### Scenario: Picker appear animation
- **WHEN** the reaction picker is shown
- **THEN** each emoji animates in sequence with scale bounce effect, total duration ~380ms

### Requirement: Emoji fly-to-bar animation
When the user selects an emoji from the picker, the selected emoji SHALL animate from its picker position to the reaction bar position below the message. The picker SHALL fade out simultaneously.

#### Scenario: Emoji fly animation on selection
- **WHEN** user taps an emoji in the picker
- **THEN** the emoji visually flies from the picker to the reaction bar area (300ms, easeInOut) while the picker fades out

### Requirement: Reaction chip appear/update animation
New reaction chips SHALL scale in (0→1.2→1.0, 200ms, elasticOut). Count changes SHALL animate the count text (scale 1→1.3→1.0, 150ms). Removed chips SHALL scale out and fade (1→0, 150ms).

#### Scenario: New chip appears
- **WHEN** a new emoji reaction is added to a message
- **THEN** the chip scales in with a bounce effect

#### Scenario: Chip removed
- **WHEN** the last reaction of an emoji is removed
- **THEN** the chip scales out and fades away

### Requirement: MessageItem wrapper widget
A new `MessageItem` widget SHALL wrap `MessageBubble` with gesture detection (long-press, double-tap) and `ReactionBar`. The existing `MessageBubble` widget SHALL NOT be modified internally. `ChatScreen._buildMessageItems()` SHALL use `MessageItem` instead of `MessageBubble` directly.

#### Scenario: MessageItem renders bubble and reactions
- **WHEN** a message with reactions is displayed
- **THEN** `MessageItem` renders `MessageBubble` above and `ReactionBar` below, wrapped in gesture detectors
