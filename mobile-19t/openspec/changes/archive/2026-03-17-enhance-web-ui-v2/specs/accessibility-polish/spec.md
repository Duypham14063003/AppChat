# Spec: Accessibility & Polish

## Capability

Fix color contrast issues, add tooltips, handle navigation stubs, and improve tile spacing.

## Requirements

### Color Contrast

- REQ-AP1: textHint color MUST change from #5A5648 to #7A7568
- REQ-AP2: New textHint (#7A7568) achieves WCAG AA 4.5:1 contrast ratio against #0A0A0A background
- REQ-AP3: This affects all timestamps, placeholders, and hint text across the app

### Tooltips

- REQ-AP4: All IconButton widgets MUST have a tooltip parameter
- REQ-AP5: Tooltip labels in Vietnamese:
  - Search: "Tìm kiếm"
  - Add/New: "Thêm mới"
  - Close: "Đóng"
  - Send: "Gửi"
  - Emoji: "Emoji"
  - Attach: "Đính kèm"
  - Info: "Thông tin"
  - Back: "Quay lại"

### Navigation Stubs

- REQ-AP6: HR, Tasks, and Profile navigation destinations MUST navigate to a placeholder screen
- REQ-AP7: Placeholder screen: centered icon + "Tính năng đang phát triển" text + subtitle "Coming soon"
- REQ-AP8: Each tab uses its own icon in the placeholder (people for HR, task for Tasks, person for Profile)
- REQ-AP9: Create a shared ComingSoonScreen widget that accepts icon and title params

### Routes

- REQ-AP10: Add routes: /hr, /tasks, /profile → ComingSoonScreen with appropriate params
- REQ-AP11: MainShell onDestinationSelected must navigate to these routes

## Affected Files

- `app_colors.dart` — update textHint value
- `message_input_bar.dart` — add tooltips
- `chat_list_screen.dart` — add tooltips
- `chat_screen.dart` — add tooltips
- `main_shell.dart` — wire all nav destinations
- `app_router.dart` — add /hr, /tasks, /profile routes
- `lib/shared/widgets/coming_soon_screen.dart` — new file
