## Context

Text messaging, media sharing (image/album/video/voice), link preview, and emoji reactions are implemented. Users share URLs and media frequently but cannot relay existing messages to other conversations. The `messages` table already has `forwarded_from_id` (uuid) and `forwarded_from_sender` (varchar) columns from the initial migration, but they are unused — the `sendMessage()` INSERT query does not include them. The Flutter local DB (`LocalMessages` Drift table) also lacks these columns.

The feature follows Telegram's UX: long-press → context menu → multi-select → chat picker → forward. Server-side message copy approach (not client-side re-send).

## Goals / Non-Goals

**Goals:**
- Multi-select messages in ChatScreen for batch forwarding
- Chat picker screen with multi-select conversations, search, and selected chips
- Server-side message copy via new `forward_message` WebSocket event
- "Forwarded from [Name]" header on forwarded message bubbles
- Per-forward privacy toggle ("Ẩn nguồn") to hide original sender attribution
- Forward all message types: text, image, album, video, voice (preserve type + metadata)
- Preserve chronological order when forwarding multiple messages
- Block forwarding of deleted messages

**Non-Goals:**
- External share-in from other apps (Android Intent / iOS Share Extension) — separate change
- Forward to users not in any conversation (must pick existing conversation)
- Edit forwarded message content before sending
- Forward-of-forward chain tracking (just store immediate source)
- Restrict forwarding per group/channel (admin setting)
- oEmbed or special rendering for forwarded media

## Decisions

### D1: Forward approach — Server-side copy
**Choice**: Client sends `{ original_message_ids[], target_conv_ids[] }` via WebSocket. Server looks up original messages, copies content/type/metadata into new messages with `forwarded_from_id` and `forwarded_from_sender` populated.
**Rationale**: Server validates message existence and membership. Media URLs are reused (no re-upload). Client payload is minimal (just IDs). Handles deleted-message edge case server-side.
**Alternative considered**: Client-side copy (read message locally, re-send with forward fields) — rejected because client may have stale data, deleted messages, or missing metadata for old messages evicted from local cache.

### D2: WebSocket event — New `forward_message` event
**Choice**: Add `forward_message` event to ChatGateway switch. Payload: `{ id: string, message_ids: string[], conv_ids: string[], hide_sender: boolean }`. Server responds with `forward_ack` containing created message IDs per conversation.
**Rationale**: Separate event keeps `send_message` simple. Batch payload (arrays) avoids N×M individual WS calls. Single round-trip for the entire forward operation.
**Payload structure**:
```json
{
  "event": "forward_message",
  "data": {
    "message_ids": ["uuid1", "uuid2"],
    "conv_ids": ["conv-a", "conv-b"],
    "hide_sender": false
  },
  "id": "envelope-id"
}
```

### D3: Privacy — Per-forward "Ẩn nguồn" toggle
**Choice**: Toggle in ForwardChatPickerScreen. When enabled, `forwarded_from_sender` is set to `null` in the new message. UI shows "Tin nhắn chuyển tiếp" instead of "Chuyển tiếp từ [Name]".
**Rationale**: Simpler than user-level privacy settings. For a <50 employee internal app, per-forward control is sufficient. No DB schema changes needed — just set the column to null.
**Alternative considered**: User-level setting (Telegram's "Forwarded Messages" privacy) — overkill for internal app.

### D4: Multi-select mode UX
**Choice**: Long-press message → context menu with "Chuyển tiếp" → enters selection mode. In selection mode: AppBar changes to `[✕] [N đã chọn] [➤ Chuyển tiếp]`, tap toggles selection, checkboxes appear left of each message, input bar hides. Tap forward button → opens ForwardChatPickerScreen.
**Rationale**: Matches Telegram pattern. Selection mode is a distinct UI state in ChatScreen (not a separate screen). Reuses existing message list — just adds selection overlay.

### D5: Chat picker — Reuse conversation list pattern
**Choice**: New `ForwardChatPickerScreen` as a full-screen route. Shows conversation list (from `chatListProvider`), search bar, multi-select with checkboxes, selected conversation chips at top, "Ẩn nguồn" toggle, and send FAB.
**Rationale**: Similar to `GroupCreateMembersScreen` pattern (search + multi-select + chips). Uses existing `chatListProvider` for data. Full-screen (not bottom sheet) because multi-select needs space.

### D6: Forward header rendering
**Choice**: In `MessageBubble._buildBubble()`, check for `forwardedFromId` or `forwardedFromSender` on the message. If present, render a header above the content: "↪ Chuyển tiếp từ [Name]" in `AppColors.gold`, italic, 12px. If `forwardedFromSender` is null (anonymous), show "↪ Tin nhắn chuyển tiếp".
**Rationale**: Minimal change to MessageBubble. Gold color matches app accent. Arrow icon (↪) provides visual cue. No tap action on the header (no profile navigation for forwarded sender).

### D7: Drift migration — Add forward columns to LocalMessages
**Choice**: Increment schema version to 4. Add `forwardedFromId` (text nullable) and `forwardedFromSender` (text nullable) columns to `LocalMessages` table via `onUpgrade` migration.
**Rationale**: Required for local storage of forwarded message data. Nullable columns — existing messages unaffected. Requires `build_runner` codegen after change.

### D8: Backend sendMessage INSERT — Include forward columns
**Choice**: Update the raw SQL INSERT in `ChatService.sendMessage()` to include `forwarded_from_id` and `forwarded_from_sender` parameters. Also update `ChatService.forwardMessages()` (new method) to use these columns.
**Rationale**: The columns exist in DB but the INSERT query skips them. Both `sendMessage` (for future use) and `forwardMessages` need them.

### D9: Message ordering — Preserve original chronological order
**Choice**: When forwarding multiple messages, server sorts `message_ids` by original `created_at` ascending, then inserts in that order with incrementing timestamps (each +1ms) to maintain order in the target conversation.
**Rationale**: Users expect forwarded messages to appear in the same order as the original conversation. Incrementing timestamps ensure correct ordering in the target conversation's timeline.

## Risks / Trade-offs

- **[N×M INSERT volume]** → Forwarding 10 messages to 5 conversations = 50 INSERTs. For <50 employees this is fine. Mitigated by: sequential processing, no concurrent forward storms expected.
- **[Media URL durability]** → Forwarded messages reference original media URLs. If original is deleted, forwarded message shows broken media. Mitigated by: media files are not deleted when messages are soft-deleted (only `deleted_at` is set).
- **[Stale forward attribution]** → `forwarded_from_sender` stores the sender's name at forward time. If user changes name later, old forwards show the old name. Acceptable trade-off — same as Telegram behavior.
- **[Selection mode complexity]** → Adding selection state to ChatScreen increases widget complexity. Mitigated by: clean state management with `_isSelectionMode` and `_selectedMessageIds` Set.
- **[Drift migration]** → Schema version bump requires careful migration. Mitigated by: simple ALTER TABLE ADD COLUMN — no data migration needed.

## Open Questions

- None — all decisions made during exploration phase.

