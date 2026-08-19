## Context

Chat messaging is fully implemented with text, image, album, voice, and video messages. Group conversations support member management with roles (admin/member/creator). Real-time delivery uses WebSocket + Redis Pub/Sub. System messages exist for group events (member added/removed/left). The `messages` table is range-partitioned by `created_at` with composite PK `(id, created_at)`. The `message_reactions` table already references messages by `id` alone (no FK to partitioned table) — proven pattern.

Current long-press on messages shows only a `ReactionPicker` overlay (floating emoji pill). No context menu exists. The `fr-chat-reply-message` change (0/34 tasks done) plans a `showModalBottomSheet` context menu but hasn't been implemented.

Flutter Drift schema is at version 5. WebSocket event dispatch uses `_handlers` map with `on(event, handler)` / `off(event, handler)` pattern.

## Goals / Non-Goals

**Goals:**
- Pin/unpin messages with max 5 per conversation, Telegram-style pinned bar with cycling
- Pinned messages list screen accessible from chat header
- Unified long-press context menu (replacing reaction-picker overlay) that is forward-compatible with Reply/Copy/Delete
- Real-time pin updates across all conversation members
- System messages for pin/unpin actions

**Non-Goals:**
- Silent pin option (always notify — team <50 people)
- Hide pinned bar preference (bar always visible when pins exist)
- Pin notifications via FCM push (only in-app real-time via WS)
- Implementing Reply/Copy/Delete actions in context menu (slots only, future changes fill them)

## Decisions

### D1: Separate `pinned_messages` table vs flag on `messages`

**Decision**: Separate `pinned_messages` table.

**Why**: The `messages` table is range-partitioned by `created_at`. Querying "all pinned messages for conversation X" would scan across partitions. A small separate table (max 5 rows per conversation) gives O(1) lookup. This matches the ER diagram in `database-schema.md` which already references `pinned_messages`.

**Alternative**: Add `is_pinned` boolean + `pinned_at` to messages table. Rejected because cross-partition queries for pinned messages would be slow and the partitioned PK makes updates awkward.

### D2: REST API for pin/unpin vs WebSocket events

**Decision**: REST endpoints for mutations, WebSocket for real-time broadcast.

**Why**: Pin/unpin is an infrequent action. REST gives proper HTTP status codes, easier error handling, and retry semantics. Real-time notification to other members still goes through Redis PubSub → WS (same as reaction_update pattern). This is consistent with group management (add/remove member) which also uses REST.

**Alternative**: WS-only like `toggle_reaction`. Rejected because pin has more complex validation (permission checks, limit enforcement) that benefits from REST error responses.

### D3: Pin endpoints on ConversationController vs separate PinController

**Decision**: Add methods to `ConversationController` following existing sub-resource pattern (`/:id/pins`).

**Why**: Consistent with existing `/:id/members`, `/:id/messages` patterns. The controller is not yet oversized. A separate controller adds module complexity for only 4 endpoints.

### D4: Context menu as `showModalBottomSheet` vs custom overlay

**Decision**: `showModalBottomSheet` with reaction row at top + action list below.

**Why**: Established pattern in codebase (`message_input_bar.dart` attach sheet, `reaction_details_sheet.dart`). The `fr-chat-reply-message` change also plans this pattern. Bottom sheet is more accessible than floating overlay, handles safe area, and is easier to extend with new actions.

**Layout**:
```
┌──────────────────────────────────┐
│  😀 😂 ❤️ 👍 😢 🔥  [+]        │  ← quick reactions row
├──────────────────────────────────┤
│  📌  Ghim tin nhắn               │  ← or "Bỏ ghim" if pinned
│  ↩️  Trả lời          (future)  │
│  📋  Sao chép          (future)  │
│  🗑️  Xóa               (future)  │
└──────────────────────────────────┘
```

### D5: `pin_order` column for cycling vs `pinned_at` ordering

**Decision**: Use `pinned_at` timestamp for ordering. No separate `pin_order` column.

**Why**: Simpler schema. Cycling order = newest pin first (DESC `pinned_at`), matching Telegram behavior. No need to maintain a separate order column that requires reordering on pin/unpin.

### D6: Pinned bar cycling state — server vs client

**Decision**: Client-side only. Current cycle index stored in widget state.

**Why**: Which pin the user is currently viewing is ephemeral UI state. No need to persist or sync. Resets on screen re-entry (shows newest pin), same as Telegram.

## Risks / Trade-offs

- **[Risk] Context menu replaces existing reaction picker overlay** → The `ReactionPicker` overlay in `MessageItem._showReactionPicker()` must be replaced. Existing double-tap for ❤️ reaction remains unchanged. The quick reaction row in the bottom sheet preserves the same emoji set.

- **[Risk] `fr-chat-reply-message` overlap** → That change plans a context menu with Reply/Copy. By building the unified menu now with disabled/future slots, reply-message's context menu tasks become redundant. Document this in both changes' tasks.

- **[Risk] Cross-partition JOIN for pin content** → `pinned_messages` stores `message_id` (uuid). To display pin content in the bar, we JOIN to `messages` by `id` alone (no partition pruning). With max 5 pins per conversation, this is negligible. Same pattern as `message_reactions`.

- **[Risk] Drift schema migration 5→6** → Adding `LocalPinnedMessages` table. If user has app at schema 4 and skips to 6, the `onUpgrade` chain must handle both steps. Existing migration blocks (`from < 2`, `from < 3`, `from < 4`, `from < 5`) already handle this pattern.

- **[Trade-off] No offline pin support** → Pin/unpin requires network (REST call). Unlike message sending, there's no offline queue for pin actions. Acceptable because pinning is infrequent and non-urgent.

## Open Questions

None — all decisions resolved during exploration phase.

