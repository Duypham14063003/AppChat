## mention-autocomplete

Detect `@` character in MessageInputBar, show member autocomplete overlay, track mention entities, and pass metadata to sendMessage. Includes @all support for admin/creator users.

### Requirements

1. **`@` trigger detection in MessageInputBar**
   - Monitor `TextEditingController` text changes in `onChanged`
   - Detect `@` character when: at position 0, or preceded by whitespace
   - Track `_mentionStartIndex` — the position of the triggering `@`
   - Extract query text: substring from `_mentionStartIndex + 1` to cursor position
   - Dismiss autocomplete when: member selected, backspace past `@`, space typed without selection, tap outside overlay, emoji picker opens

2. **Autocomplete overlay widget**
   - Use `OverlayEntry` positioned above the MessageInputBar
   - Max height: 200px (scrollable if more items)
   - Background: `AppColors.surface` with `AppColors.surfaceVariant` border
   - Border radius: 12px top corners
   - Shadow: subtle elevation
   - Each item row:
     - CircleAvatar (radius 16) with user avatar or initials fallback
     - User name (primary text, `AppColors.textPrimary`)
     - Department (secondary text, `AppColors.textSecondary`, fontSize 12)
   - `@all` row (if user is admin/creator):
     - Icon: `Icons.groups` in `AppColors.gold`
     - Text: "Tất cả" (primary), "Thông báo cho mọi người" (secondary)
     - Always shown at top of list, before filtered members

3. **Member filtering**
   - Source: `conversationMembersProvider` (already cached, has name + avatar)
   - Filter: case-insensitive prefix match on member name
   - Exclude current user from list
   - Vietnamese diacritics: match as-is (no accent stripping — "Ng" matches "Ngọc" because prefix "Ng" matches)
   - Sort: alphabetical by name
   - Show all members when query is empty (just typed `@`)

4. **Mention entity tracking**
   - Maintain `List<MentionEntity> _mentions` in `_MessageInputBarState`
   - `MentionEntity`: `{int offset, int length, String userId, String name}`
   - On member selection:
     - Replace text from `_mentionStartIndex` to cursor with `@DisplayName ` (trailing space)
     - Add entity: `{offset: _mentionStartIndex, length: "@DisplayName".length, userId, name}`
     - Update cursor position to after trailing space
   - On text change: recalculate offsets for all existing mentions if text before them changed (insertion/deletion shifts offsets)
   - On backspace into a mention span: remove the entire mention entity and its text

5. **Mention metadata in sendMessage**
   - Update `MessageInputBar.onSend` callback signature: `void Function(String text, List<Map<String, dynamic>>? mentions)`
   - On send: pass current `_mentions` list as metadata maps: `[{offset, length, user_id, name}]`
   - Clear `_mentions` after send
   - Update `ChatNotifier.sendMessage()` to accept optional `mentions` parameter
   - Include in WS payload: `metadata: {mentions: [...]}` when mentions is non-empty
   - Include in local Drift insert: serialize mentions to metadata JSON string

6. **@all permission check**
   - Read current user's role from conversation membership
   - Only show `@all` in autocomplete if role is `admin` or `creator`
   - `@all` entity: `{offset, length, user_id: "all", name: "Tất cả"}`

7. **Group-only activation**
   - Add `isGroup` parameter to `MessageInputBar`
   - Only activate `@` detection when `isGroup == true`
   - In DIRECT conversations, `@` is treated as normal text

### Integration Points

- `MessageInputBar` — `@` detection, overlay, entity tracking, updated onSend signature
- `ChatScreen` — pass `isGroup` and member data to MessageInputBar, update onSend handler
- `ChatNotifier.sendMessage()` — accept mentions parameter, include in WS payload and local insert
- `conversationMembersProvider` — data source for autocomplete (no changes needed)
- `OfflineQueueService._flushQueue()` — include `metadata` in replayed text messages (bug fix)

### Acceptance Criteria

- Type `@` in group chat → autocomplete overlay appears with all members
- Type `@Ng` → list filters to members whose name starts with "Ng"
- Tap member → `@Name ` inserted at cursor, overlay dismisses
- Send message with mention → WS payload includes `metadata.mentions` array
- Mention metadata persisted in local Drift database
- `@all` appears at top of list for admin/creator users only
- `@all` does not appear for regular members
- Backspace into mention text → entire mention removed
- Multiple mentions in one message work correctly with accurate offsets
- Autocomplete does not appear in DIRECT conversations
- Offline queue replays messages with mention metadata intact

