# Spec: Message Grouping & Date Separators

## Capability

Group consecutive messages from the same sender and insert date separator widgets between different calendar days.

## Requirements

### Message Grouping

- REQ-MG1: Messages from the same sender within a 5-minute window MUST be visually grouped
- REQ-MG2: First message in a group shows sender name (group chats only) and has normal top margin (8px)
- REQ-MG3: Middle messages in a group hide avatar and sender name, use reduced margin (1px)
- REQ-MG4: Last message in a group shows the avatar (group chats only)
- REQ-MG5: A new group starts when: sender changes, time gap > 5 minutes, date changes, or a system message interrupts
- REQ-MG6: In DM conversations, grouping still applies (reduced margins) but no avatar/name is shown for incoming messages without sender info

### Date Separators

- REQ-DS1: A date separator MUST appear between messages from different calendar days
- REQ-DS2: Format: "Hôm nay" (today), "Hôm qua" (yesterday), "16 tháng 3" (this year), "16/03/2025" (other years)
- REQ-DS3: Visual: centered pill with surfaceVariant background, textSecondary text, fontSize 12
- REQ-DS4: Date separators do not break message grouping — they are inserted as separate items in the list

### Bubble Tail Logic

- REQ-BT1: Only the last message in a group gets the "tail" (flat corner on sender's side)
- REQ-BT2: Other messages in the group use fully rounded corners (radius 16 all sides, or 12 on the sender's side)

## Affected Files

- `message_bubble.dart` — add grouping params: `isFirstInGroup`, `isLastInGroup`, `showAvatar`, `showSenderName`
- `chat_screen.dart` — compute grouping logic in itemBuilder, build combined list with date separators
