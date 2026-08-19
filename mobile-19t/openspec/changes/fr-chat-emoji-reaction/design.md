## Context

The chat module supports text, image, video, voice, and link-preview messages over raw WebSocket (`ws`) with Redis PubSub fan-out. A `message_reactions` table and TypeORM entity already exist with PK `(message_id, user_id)` — but zero service logic, zero WS events, and zero Flutter UI. The current PK only allows one emoji per user per message; this change migrates to multi-reaction support (Telegram-style).

Company size is <50 employees, so reaction payloads are small and full-snapshot broadcasts are viable.

## Goals / Non-Goals

**Goals:**
- Multi-reaction support: users can add up to 3 different emoji reactions per message
- Real-time reaction sync via WebSocket with Redis PubSub fan-out (same pattern as messages)
- Telegram-like UX: long-press picker, double-tap ❤️, reaction bar below bubbles, details bottom sheet
- Reactions included in message fetch/sync responses (no separate endpoint)
- Offline-first: reactions stored in local SQLite, optimistic UI updates

**Non-Goals:**
- Custom emoji / sticker reactions (standard Unicode emoji only)
- Reaction notifications (push) — reactions are lightweight, no FCM push
- Reaction analytics or statistics
- Animated emoji (Telegram Premium feature)
- Reaction to reactions

## Decisions

### 1. Schema: Composite PK `(message_id, user_id, emoji)`
**Choice**: Alter existing PK to include `emoji` column, enabling multiple reactions per user per message.
**Alternative**: Store reactions as JSONB array in `message.metadata` — rejected because it complicates concurrent updates and loses relational query capability.
**Alternative**: New table instead of altering — rejected because the existing table has no data in production yet.

### 2. Toggle semantics with server-side limit
**Choice**: Single `toggle_reaction` WS event that inserts or deletes. Server enforces max 3 reactions per user per message.
**Alternative**: Separate `add_reaction` / `remove_reaction` events — rejected for simplicity; toggle is the natural UX pattern (tap to add, tap again to remove).

### 3. Full snapshot in `reaction_update` broadcast
**Choice**: Broadcast the complete aggregated reaction list for the message (emoji, count, user list) on every change.
**Alternative**: Delta-only broadcast (added/removed) — rejected because with <50 users, payload is tiny and full snapshot eliminates client-side race conditions.

### 4. Reactions bundled with message responses
**Choice**: `getMessages()` and `syncMessages()` include a `reactions` field per message via LEFT JOIN + aggregation.
**Alternative**: Separate `/messages/:id/reactions` endpoint — rejected to avoid N+1 fetches and keep sync simple.

### 5. Flutter: `MessageItem` wrapper widget
**Choice**: New `MessageItem` widget wraps existing `MessageBubble` + `GestureDetector` + `ReactionBar`. `MessageBubble` stays unchanged.
**Alternative**: Extend `MessageBubble` with reaction props — rejected because `MessageBubble` is already 280 lines and mixing gesture/reaction concerns would reduce cohesion.

### 6. Animation: Scale bounce + fly-to-bar (Option B)
**Choice**: Reaction picker appears with staggered scale-in (elasticOut). Selected emoji animates from picker position to reaction bar position. Reaction chips scale-bounce on appear/update.
**Alternative**: Simple fade — too subtle. Full Telegram particle effects — too complex for current scope.

### 7. Emoji set
**Choice**: 6 quick-access emojis: 👍 ❤️ 😂 😮 😢 🔥, plus expand button to full `emoji_picker_flutter`. Double-tap sends ❤️.

## Risks / Trade-offs

- **Migration on partitioned table**: `message_reactions` references `messages` which is range-partitioned. The FK from entity decorator (not migration SQL) may need attention. → Mitigation: Migration only alters `message_reactions` PK, no FK changes needed.
- **Optimistic UI rollback**: If server rejects a reaction (e.g., limit exceeded), client must revert. → Mitigation: On `error` response, remove the optimistic reaction from local state.
- **Emoji rendering consistency**: Different OS versions render emoji differently. → Mitigation: Accept platform-native rendering; no custom emoji images.
- **Reaction picker z-index**: Floating picker overlay must not be clipped by `ListView` or other widgets. → Mitigation: Use `OverlayEntry` or `showMenu`-style positioning.
