## mention-badge

Unread mention count tracking per conversation and `@` badge display on ConversationTile. Server computes count via JSONB query, client stores in Drift and renders badge.

### Requirements

1. **Server: Compute unread mention count in getConversations()**
   - In `ChatService.getConversations()`, add `unreadMentionCount` to the response
   - Query: count messages in conversation where:
     - `created_at > membership.last_read_at` (unread)
     - `deleted_at IS NULL`
     - `sender_id != userId` (not own messages)
     - AND (`metadata->'mentions' @> '[{"user_id": "USER_ID"}]'::jsonb` OR `metadata->'mentions' @> '[{"user_id": "all"}]'::jsonb`)
   - Use raw SQL subquery or TypeORM query builder with JSONB containment operator
   - Return `0` if no unread mentions
   - Handle: `last_read_at` is null (user never read → count all mentions since join)

2. **Server: Add to conversation response DTO**
   - Add `unreadMentionCount: number` to the conversation list response
   - Existing response already includes `unreadCount` — add alongside it
   - Example response per conversation:
     ```json
     {
       "id": "uuid",
       "type": "GROUP",
       "name": "Dev Team",
       "unreadCount": 15,
       "unreadMentionCount": 2,
       ...
     }
     ```

3. **Flutter: Add unreadMentionCount to LocalConversations Drift table**
   - Add column: `IntColumn get unreadMentionCount => integer().withDefault(const Constant(0))();`
   - Bump `schemaVersion` from 3 to 4 in `AppDatabase`
   - Add migration: `if (from < 4) { await customStatement('ALTER TABLE local_conversations ADD COLUMN unread_mention_count INTEGER NOT NULL DEFAULT 0'); }`
   - Run `dart run build_runner build --delete-conflicting-outputs` after table change

4. **Flutter: Map unreadMentionCount in chatListProvider**
   - In `_refreshFromApi()`, map `conv['unreadMentionCount']` (or `conv['unread_mention_count']`) to `LocalConversationsCompanion`
   - Reset to 0 when entering conversation (alongside existing `resetUnreadCount`)
   - Add `resetUnreadMentionCount(String convId)` to `ChatDao`

5. **Flutter: `@` badge on ConversationTile**
   - In `ConversationTile.build()` trailing column:
     - If `conversation.unreadMentionCount > 0`: show `@` badge
     - Badge design: small container with `@` text, gold background, same style as unread count badge
     - Position: below the timestamp, next to or replacing the unread count badge
   - Layout when both unread count and mention badge exist:
     ```
     ┌─────────────────────────────────────────┐
     │  [Avatar]  Conv Name          2h ago    │
     │            Last message...    [15] [@]  │
     └─────────────────────────────────────────┘
     ```
     - `[15]` = unread count badge (gold, existing)
     - `[@]` = mention badge (gold, new)
   - If only mention badge (no unread): show `[@]` alone
   - Badge is a `Container` with:
     - Padding: `EdgeInsets.symmetric(horizontal: 4, vertical: 2)`
     - Background: `AppColors.gold`
     - Border radius: 10
     - Text: `@`, color: `AppColors.background`, fontSize: 11, fontWeight: w600

6. **Flutter: Clear mention badge on conversation open**
   - When user opens a conversation (in `ChatMessagesNotifier.build()`):
     - Call `dao.resetUnreadMentionCount(convId)` alongside existing `dao.resetUnreadCount(convId)`
     - Invalidate `chatListProvider` to refresh the list

### Technical Details

**Server JSONB query for unread mention count:**
```sql
SELECT COUNT(*) FROM messages m
WHERE m.conv_id = $1
  AND m.created_at > $2  -- last_read_at
  AND m.deleted_at IS NULL
  AND m.sender_id != $3  -- not own messages
  AND (
    m.metadata->'mentions' @> $4::jsonb  -- [{"user_id": "USER_ID"}]
    OR m.metadata->'mentions' @> '[{"user_id": "all"}]'::jsonb
  )
```

**Optional GIN index for performance:**
```sql
CREATE INDEX CONCURRENTLY "IDX_messages_mentions"
  ON "messages" USING GIN ((metadata->'mentions'))
  WHERE metadata->'mentions' IS NOT NULL;
```
This index is optional for <50 users but recommended if message volume grows.

### Integration Points

- `ChatService.getConversations()` — add unread mention count subquery
- `ConversationController` — no changes (passes through ChatService response)
- `LocalConversations` Drift table — new column
- `AppDatabase` — schema version bump + migration
- `ChatDao` — new `resetUnreadMentionCount()` method
- `chatListProvider._refreshFromApi()` — map new field
- `ChatMessagesNotifier.build()` — reset mention count on open
- `ConversationTile` — render `@` badge

### Acceptance Criteria

- Server returns `unreadMentionCount` in conversation list response
- `unreadMentionCount` correctly counts messages where current user is mentioned (by user_id or @all)
- `@` badge appears on ConversationTile when unreadMentionCount > 0
- `@` badge disappears when user opens the conversation
- Badge uses gold color matching existing unread count badge
- Both unread count and mention badge can appear simultaneously
- Drift migration from schema 3 → 4 works without data loss
- `build_runner` codegen produces correct generated code
- Conversations with no mentions show no `@` badge (no regression)

