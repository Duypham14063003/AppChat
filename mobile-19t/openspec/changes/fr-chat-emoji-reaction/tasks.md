## 1. Database Migration

- [x] 1.1 Create migration to alter `message_reactions` PK from `(message_id, user_id)` to `(message_id, user_id, emoji)` and add index `idx_reactions_message_id` on `message_id`
- [x] 1.2 Update `MessageReaction` TypeORM entity: add `emoji` to `@PrimaryColumn` decorators to match new composite PK

## 2. Backend Service

- [x] 2.1 Add `MessageReaction` repository injection to `ChatService`
- [x] 2.2 Implement `toggleReaction(userId, messageId, convId, emoji)` in `ChatService` — check membership, check existence, enforce max-3 limit, insert or delete, return action + aggregated reactions
- [x] 2.3 Implement `getReactionsForMessage(messageId)` helper in `ChatService` — LEFT JOIN `message_reactions` with `users`, GROUP BY emoji, return `[{ emoji, count, users: [{id, name}] }]`
- [x] 2.4 Modify `getMessages()` to include `reactions` field per message via subquery or post-fetch aggregation
- [x] 2.5 Modify `syncMessages()` to include `reactions` field per message

## 3. Backend WebSocket & DTO

- [x] 3.1 Add `toggle_reaction` DTO validation in `chat.dto.ts` — `message_id` (UUID), `conv_id` (UUID), `emoji` (string, max 10 chars, non-empty)
- [x] 3.2 Add `toggle_reaction` case to `ChatGateway.handleRawMessage()` switch — delegate to `ChatService.toggleReaction()`
- [x] 3.3 Broadcast `reaction_update` event to all conversation members via Redis PubSub after successful toggle — payload: `{ message_id, conv_id, user_id, user_name, emoji, action, reactions }`
- [x] 3.4 Send `reaction_ack` back to the sender socket with the result (action + updated reactions)

## 4. Flutter Data Layer

- [x] 4.1 Add `LocalMessageReactions` table to `tables.dart` with columns: `messageId`, `userId`, `emoji`, `userName`, `createdAt` and composite PK `(messageId, userId, emoji)`
- [x] 4.2 Add reaction queries to `ChatDao`: `upsertReaction`, `deleteReaction`, `getReactionsForMessage`, `replaceReactionsForMessage`
- [x] 4.3 Run `build_runner` to regenerate Drift code
- [x] 4.4 Increment Drift schema version and add migration step in `app_database.dart`
- [x] 4.5 Create `ReactionGroup` model class in `lib/features/chat/models/reaction_group.dart` — fields: `emoji`, `count`, `users` (List of `{id, name}`), `isMine`

## 5. Flutter State Management

- [x] 5.1 Create `messageReactionsProvider(messageId)` — watches local SQLite reactions, returns `List<ReactionGroup>` with `isMine` computed from current user ID
- [x] 5.2 Add `toggleReaction(messageId, convId, emoji)` method to `ChatNotifier` — optimistic local update + send `toggle_reaction` WS event
- [x] 5.3 Add `reaction_update` WebSocket event listener in `ChatNotifier` — parse payload, call `replaceReactionsForMessage` on ChatDao
- [x] 5.4 Handle `reaction_ack` and error responses — revert optimistic update on `REACTION_LIMIT` or other errors
- [x] 5.5 Parse `reactions` field from message fetch/sync responses and store in `local_message_reactions`

## 6. Flutter UI — MessageItem Wrapper

- [x] 6.1 Create `MessageItem` widget in `lib/features/chat/widgets/message_item.dart` — wraps `MessageBubble` + `GestureDetector` (long-press, double-tap) + `ReactionBar`
- [x] 6.2 Update `ChatScreen._buildMessageItems()` to use `MessageItem` instead of `MessageBubble` directly — pass reaction callbacks and data

## 7. Flutter UI — Reaction Bar

- [x] 7.1 Create `ReactionBar` widget in `lib/features/chat/widgets/reaction_bar.dart` — Row of `ReactionChip` widgets, shown only when reactions exist
- [x] 7.2 Create `ReactionChip` widget — displays emoji + count, highlighted style when `isMine`, tap to toggle, long-press to show details
- [x] 7.3 Add chip appear/update/remove animations: scale bounce on appear (elasticOut 200ms), count text scale on update (150ms), scale-out + fade on remove (150ms)

## 8. Flutter UI — Reaction Picker

- [x] 8.1 Create `ReactionPicker` overlay widget in `lib/features/chat/widgets/reaction_picker.dart` — positioned above message, shows 6 quick emoji + expand button
- [x] 8.2 Add staggered scale-in animation for picker emoji (30ms stagger, elasticOut, ~380ms total)
- [x] 8.3 Implement expand button (⋯) — opens `emoji_picker_flutter` full picker
- [x] 8.4 Add `emoji_picker_flutter` package to `pubspec.yaml`
- [x] 8.5 Implement emoji fly-to-bar animation on selection (300ms, easeInOut) with simultaneous picker fade-out

## 9. Flutter UI — Reaction Details Sheet

- [x] 9.1 Create `ReactionDetailsSheet` bottom sheet in `lib/features/chat/widgets/reaction_details_sheet.dart` — tab bar (All + per-emoji tabs with counts), user list per tab
- [x] 9.2 Wire up sheet trigger from `ReactionChip` tap or `ReactionBar` interaction
