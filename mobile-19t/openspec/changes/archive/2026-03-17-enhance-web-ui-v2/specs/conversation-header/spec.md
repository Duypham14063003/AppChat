# Spec: Conversation Header Enhancement

## Capability

Add action buttons to the conversation AppBar and show dynamic group member count.

## Requirements

### Action Buttons

- REQ-CH1: AppBar MUST have action buttons in the trailing area
- REQ-CH2: Search button (Icons.search) — shows SnackBar "Tính năng đang phát triển" (placeholder)
- REQ-CH3: Info button (Icons.info_outline) — navigates to group info screen (groups) or shows SnackBar (DMs)
- REQ-CH4: All action buttons MUST have tooltips ("Tìm kiếm", "Thông tin")
- REQ-CH5: Action button icon color: textSecondary

### Group Subtitle

- REQ-CH6: Group conversations MUST show member count instead of hardcoded "Nhóm chat"
- REQ-CH7: Format: "N thành viên" (e.g., "5 thành viên")
- REQ-CH8: Member count fetched from conversation detail API (members list length)
- REQ-CH9: Fallback to "Nhóm chat" if member count is unavailable

### Visual Separation

- REQ-CH10: AppBar MUST have a visible bottom border (surfaceVariant color, 1px) to separate from message list

## Affected Files

- `chat_screen.dart` — add AppBar actions, update group subtitle, add bottom border
- `chat_providers.dart` — ensure conversation detail includes member count
