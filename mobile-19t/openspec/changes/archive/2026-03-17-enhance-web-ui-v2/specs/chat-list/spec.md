# Spec: Chat List Enhancements

## Capability

Add online presence dots, group sender prefixes, proper initials, and tile spacing to the conversation list.

## Requirements

### Online Presence Dot

- REQ-CL1: DIRECT conversations with an online other member MUST show a green dot on the avatar
- REQ-CL2: Dot: 10px diameter, #2ECC71 fill, 2px #0A0A0A border, positioned bottom-right of avatar
- REQ-CL3: Online = otherMemberLastSeenAt within 2 minutes of now
- REQ-CL4: Implementation: wrap CircleAvatar in a Stack with a Positioned dot

### Group Preview Prefix

- REQ-CL5: GROUP conversations MUST prefix lastMessageContent with sender name: "An: hello"
- REQ-CL6: Use lastMessageSenderName if available, otherwise use first name from lastMessageSenderId lookup
- REQ-CL7: If sender is current user, prefix with "Bạn: " instead of name
- REQ-CL8: System messages show content directly without prefix

### Initials Fix

- REQ-CL9: Avatar fallback initials MUST use first character of first word + first character of last word
- REQ-CL10: "Nguyễn Văn An" → "NA", "Test Bot" → "TB", "Admin" → "A"
- REQ-CL11: Match the logic already used in ContactPickerScreen's _ContactListItem

### Tile Spacing

- REQ-CL12: Add subtle visual separation between conversation tiles
- REQ-CL13: Implementation: 1px Divider with surfaceVariant color, or 4px vertical padding per tile

## Affected Files

- `conversation_tile.dart` — online dot, initials, prefix, spacing
- `chat_list_screen.dart` — use ListView.separated if needed
- `chat_providers.dart` — may need to store lastMessageSenderName in local DB
