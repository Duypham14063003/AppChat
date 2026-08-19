# Proposal: Enhance Web UI v2

## Summary

Polish the Flutter web chat UI to match professional standards set by Zalo Web, Telegram, and Messenger. This is a Tier 1 (UI-only) change — no backend modifications, no new API endpoints, no database changes. All improvements target the existing Flutter frontend widgets and screens.

## Problem

The current web UI was built mobile-first and ported to web with a responsive shell. While the layout structure (NavigationRail + master-detail) is correct, the individual components look unfinished compared to Zalo/Telegram/Messenger:

- Group chat messages don't show sender names or avatars (bug)
- Messages are not grouped — every message repeats avatar/name
- No date separators between different days
- Sent vs received bubble contrast is nearly invisible (gold at 15% opacity)
- Input bar is bare — no emoji button, no attachment button, no visual container
- Conversation header has no action buttons and hardcodes "Nhóm chat" instead of member count
- Chat list lacks online presence dots, sender prefixes for groups, and proper initials
- textHint color fails WCAG AA accessibility (2.8:1 contrast ratio)
- Navigation stub tabs (HR/Tasks/Profile) do nothing on tap

## Scope

### In Scope (18 items)

**Message Area (5)**
1. Fix group sender name/avatar bug in chat_screen.dart
2. Message grouping — collapse consecutive messages from same sender within 2-5 minutes
3. Date separators — "Hôm nay", "Hôm qua", "dd/MM/yyyy"
4. Increase outgoing bubble contrast — solid dark-gold tint instead of 15% opacity
5. Sender name color coding — 8-color palette rotating by sender ID hash (Telegram style)

**Input Bar (3)**
6. Rounded container for text field
7. Emoji button (left side) — opens system emoji or emoji_picker_flutter
8. Attachment button — placeholder for now (shows "Coming soon" toast)

**Conversation Header (3)**
9. Action buttons — search icon + info/members icon
10. Group subtitle — show member count ("5 thành viên") instead of "Nhóm chat"
11. Bottom border/shadow for visual separation from message list

**Chat List (3)**
12. Online presence dot on avatar (8px green circle, bottom-right)
13. Group message preview prefix — "An: hello" instead of "hello"
14. Fix initials — multi-word split ("NV" for "Nguyễn Văn") matching contact_picker logic

**Accessibility & Polish (4)**
15. textHint color: #5A5648 → #7A7568 (achieves WCAG AA 4.5:1)
16. Tooltips on all icon buttons
17. Navigation stub tabs → navigate to "Coming soon" placeholder screen
18. Subtle separator/padding between conversation tiles

### Out of Scope
- Backend API changes
- Database schema changes
- Typing indicators (needs WS event)
- Message reactions (needs backend)
- Reply/quote UI (Tier 2)
- Image/file upload (needs upload API)
- Message context menu (Tier 2)
- Thread replies (Tier 3)

## Target Users

~50 employees of Nineteen Tech, using the web version (Chrome) on desktop for daily team communication.

## Success Criteria

- Group chat clearly shows who sent each message
- Sent vs received bubbles are visually distinct at a glance
- Input bar looks complete (emoji + attach + rounded field)
- Chat list shows online status and group sender context
- All text meets WCAG AA contrast requirements
- No regressions on mobile (narrow screen) layout
