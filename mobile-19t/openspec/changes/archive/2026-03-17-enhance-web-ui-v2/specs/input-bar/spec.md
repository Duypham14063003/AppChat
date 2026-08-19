# Spec: Input Bar Redesign

## Capability

Upgrade the message input bar with a rounded text field container, emoji button, and attachment button.

## Requirements

- REQ-IB1: TextField MUST be wrapped in a rounded container (surfaceVariant background, BorderRadius.circular(22), 1px border card color)
- REQ-IB2: Emoji button (Icons.emoji_emotions_outlined) MUST appear to the left of the text field
- REQ-IB3: Tapping emoji button opens an emoji picker (emoji_picker_flutter package) as a bottom panel
- REQ-IB4: Selected emoji is inserted at cursor position in the text field
- REQ-IB5: Attach button (Icons.attach_file) MUST appear between the text field and send button
- REQ-IB6: Tapping attach button shows a SnackBar "Tính năng đang phát triển" (placeholder)
- REQ-IB7: Send button behavior unchanged — gold when text present, hint when empty
- REQ-IB8: Enter-to-send (web) and Shift+Enter-for-newline behavior MUST be preserved
- REQ-IB9: All icon buttons MUST have tooltips ("Emoji", "Đính kèm", "Gửi")
- REQ-IB10: Emoji picker panel uses dark theme matching app colors

## Layout

```
┌──────────────────────────────────────────────────────┐
│ [😊]  ┌──────────────────────────────┐  [📎]  [➤]  │
│       │ Nhập tin nhắn...              │              │
│       └──────────────────────────────┘              │
└──────────────────────────────────────────────────────┘
```

## Affected Files

- `message_input_bar.dart` — full redesign of build method
- `pubspec.yaml` — add `emoji_picker_flutter` dependency
