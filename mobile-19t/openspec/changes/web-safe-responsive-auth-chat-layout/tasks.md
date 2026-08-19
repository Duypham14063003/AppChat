## 1. Responsive Auth Layout

- [x] 1.1 Add a wide-screen layout container to `apps/mobile/lib/features/auth/screens/login_screen.dart` so the login form renders inside a centered bounded frame on desktop-sized viewports
- [x] 1.2 Keep the existing narrow/mobile login composition unchanged while ensuring validation, loading, and error states still render correctly in both narrow and wide modes

## 2. Responsive Chat Conversation Layout

- [x] 2.1 Add pane-aware wide-layout detection for the conversation area in `apps/mobile/lib/features/chat/screens/chat_screen.dart` so desktop framing depends on the actual chat pane width
- [x] 2.2 Constrain the message timeline and conversation empty-state content to a shared centered frame on wide chat panes without changing the current phone layout
- [x] 2.3 Constrain and align the pinned surface, typing indicator, composer, reply/edit preview, and scroll-to-bottom affordance to the same wide conversation frame
- [x] 2.4 Verify the updated conversation framing still works correctly inside the existing wide shell split from `apps/mobile/lib/core/router/main_shell.dart`

## 3. Verification

- [x] 3.1 Add responsive widget or layout tests covering login wide-frame rendering and narrow/mobile fallback behavior
- [x] 3.2 Add responsive widget or layout tests covering wide chat framing, aligned composer behavior, and narrow/mobile chat fallback behavior
- [ ] 3.3 Manually verify login and chat layouts on mobile-sized and desktop-sized web viewports to confirm the web-safe framing does not regress the current mobile UX
