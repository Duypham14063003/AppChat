# Spec: Bubble Contrast & Sender Colors

## Capability

Make sent vs received bubbles clearly distinguishable and add per-sender color coding for group chat names.

## Requirements

### Bubble Contrast

- REQ-BC1: Outgoing bubble background MUST use `AppColors.bubbleMine` (#2A2210) instead of `gold.withOpacity(0.15)`
- REQ-BC2: Incoming bubble background remains `AppColors.surface` (#141418)
- REQ-BC3: The visual difference between sent and received MUST be noticeable at a glance

### Sender Name Colors

- REQ-SC1: In group chats, each sender's name MUST be displayed in a distinct color from an 8-color palette
- REQ-SC2: Color assignment: `senderColors[senderId.hashCode.abs() % 8]`
- REQ-SC3: All 8 colors MUST pass WCAG AA (4.5:1) against the incoming bubble background (#141418)
- REQ-SC4: The sender name color is used ONLY for the name text, not the bubble or message text
- REQ-SC5: The color palette is defined as a static list in `AppColors`

## Color Palette

```
#E57373 (red)     #81C784 (green)   #64B5F6 (blue)    #FFB74D (orange)
#BA68C8 (purple)  #4DD0E1 (cyan)    #F06292 (pink)     #AED581 (lime)
```

## Affected Files

- `app_colors.dart` — add `bubbleMine` constant and `senderColors` list
- `message_bubble.dart` — use `bubbleMine` for outgoing, accept `senderNameColor` param
- `chat_screen.dart` — compute and pass sender color
