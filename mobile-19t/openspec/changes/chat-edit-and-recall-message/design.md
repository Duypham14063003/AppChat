## Context

The chat stack already supports sending, forwarding, reply state, reactions, bookmarks, pinned messages, REST-based history loading, and WebSocket delivery for new messages and status changes. Both backend and mobile persistence layers already include `edited_at` and `deleted_at` fields on messages, but those fields are not connected to user-facing behavior.

Today, there is no API or WebSocket mutation for editing or recalling a message. The mobile long-press menu does not expose either action, the input bar has no edit mode, and the local DAO filters `deletedAt.isNull()`, which means a soft-deleted message disappears from the timeline instead of rendering as a recalled-message placeholder. This change spans backend mutation APIs, realtime contracts, message serialization, local cache updates, and chat UI state, so a design document is warranted before implementation.

## Goals / Non-Goals

**Goals:**
- Let a sender edit the content of their own previously sent text message.
- Let a sender recall one of their own messages using soft-delete semantics.
- Keep edited and recalled state synchronized across devices through realtime updates and regular sync/history fetches.
- Render recalled messages as visible placeholders in the timeline rather than silently removing them from chat history.
- Keep conversation-list previews synchronized with the latest message state after edit and recall mutations.
- Add clear mobile affordances for edit and recall without inventing a separate navigation model.

**Non-Goals:**
- Allow editing media payloads, captions, forwarded payload snapshots, or system messages.
- Add admin or group-creator powers to edit or recall messages sent by other users.
- Introduce a time-limit policy for edit or recall in this change.
- Permanently hard-delete message rows from server or local storage.
- Redesign the overall message composer or context-menu layout beyond what is required for the two new actions.

## Decisions

### D1: Split edit and recall into explicit message mutations

**Decision:** Add dedicated backend mutations for message edit and message recall instead of overloading existing send/sync flows.

**Why:** Editing and recalling are state transitions on an existing message, not new-message creation. Explicit mutations keep validation, auditing, permissions, and error handling understandable on both server and client.

**Alternatives considered:**
- Reuse `send_message` with a mode flag. Rejected because it muddies the meaning of message creation and complicates acknowledgements.
- Model recall as a conversation-level delete endpoint. Rejected because group deletion already uses soft-delete semantics for a different scope and permission model.

### D2: Recalled messages stay in history as tombstones

**Decision:** Keep recalled messages in history and serialize them as recalled/tombstoned entries rather than filtering them out from message queries.

**Why:** Users expect a recalled message to remain represented in the conversation timeline so message order, replies, and surrounding context remain stable. This also avoids confusing jumps in search, bookmarks, and jump-to-message behavior when a once-visible message suddenly disappears.

**Alternatives considered:**
- Continue filtering `deleted_at IS NULL` everywhere and hide recalled messages completely. Rejected because it creates timeline gaps and does not match typical chat recall behavior.
- Hard-delete messages from storage. Rejected because it removes auditability and creates higher migration risk.

### D3: Limit editing to sender-owned text messages in v1

**Decision:** Only allow the original sender to edit text messages whose current state is not recalled.

**Why:** Text-only editing is the smallest complete feature with clear UX and minimal risk to metadata-heavy message types such as image, album, voice, and video. Sender-only permissions also align with the current trust model of message ownership.

**Alternatives considered:**
- Support editing captions and media payloads immediately. Rejected because it widens serialization, upload, and UI complexity too early.
- Allow admins to edit or recall member messages in group chats. Rejected because it introduces moderation semantics not present elsewhere in the chat product.

### D4: Use composer edit mode instead of inline bubble editing

**Decision:** Reuse the existing message input bar as the edit surface, with a temporary edit state that pre-fills the original content and lets the user save or cancel.

**Why:** The current composer already manages text input, mentions, reply state, and send affordances. Extending it with an edit banner is lower risk than building inline bubble editing and fits the existing mobile interaction model.

**Alternatives considered:**
- Edit inline inside the message bubble. Rejected because it adds layout complexity and conflicts with reaction, reply, and selection states.
- Open a separate full-screen edit page. Rejected because it is slower and feels heavy for a quick correction flow.

### D5: Realtime and history responses must converge on the same message shape

**Decision:** Use one canonical message shape for edited and recalled state across REST history, sync responses, and realtime events.

**Why:** The mobile layer already merges messages from API history, local cache, and WebSocket events. A single representation reduces edge cases where a message looks different depending on how it arrived.

**Alternatives considered:**
- Emit lightweight events and force the client to refetch the full message after every mutation. Rejected because it adds latency and creates more synchronization points.

### D6: Conversation-list preview state must be updated from the same edit/recall events

**Decision:** Treat the conversation list's denormalized preview as part of the edit/recall synchronization surface, and update it immediately when the affected message is the latest message in that conversation.

**Why:** The mobile app stores `local_messages` and `local_conversations.lastMessageContent` separately. Updating only the timeline leaves the list preview stale until a later conversation refresh succeeds, which is exactly the recall bug now observed in production.

**Alternatives considered:**
- Depend only on a background `getConversations()` refresh to fix the preview. Rejected because refresh is best-effort, can race with local cache, and visibly leaks old content after a successful recall.
- Rebuild every list preview on every message mutation by querying the entire conversation history. Rejected because it is heavier than needed for a targeted latest-message update.

## Risks / Trade-offs

- [Risk] Recalled-message placeholders may interact poorly with reply previews, bookmarks, or jump navigation. → Mitigation: define a canonical recalled serialization and update dependent UI to degrade gracefully when the original content is no longer available.
- [Risk] Converting `deleted_at` from "hidden" to "visible tombstone" can affect unread counts, search, and list queries. → Mitigation: update only message-list rendering and history filters required for recall while keeping search and unread semantics explicit in tests.
- [Risk] The conversation list can show stale last-message text if recall/edit updates only patch `local_messages` and not the denormalized conversation preview. → Mitigation: update conversation-preview state on `message_updated` and `message_recalled` when the affected message is the latest visible message, and verify the list placeholder path in tests.
- [Risk] Composer edit state can conflict with existing reply state or attachment drafting. → Mitigation: make edit mode mutually exclusive with reply mode and block entry into edit mode when unsupported draft types are active.
- [Risk] Realtime mutation ordering may race with new-message acknowledgements or sync-on-reconnect. → Mitigation: key updates by message id and make local upserts idempotent for edit and recall events.

## Migration Plan

1. Add backend mutation methods, DTOs, and serialization rules for edited and recalled messages.
2. Update history and sync queries so recalled messages remain available as tombstones instead of being filtered away.
3. Add WebSocket event publication and mobile event listeners for edit and recall updates.
4. Extend local Drift DAO and providers to update message content, `editedAt`, and recalled state without removing the row from the visible timeline.
5. Update the denormalized conversation-list preview state when the latest message is edited or recalled.
6. Add message-context-menu actions and composer edit mode in the mobile chat UI.
7. Verify direct and group chat flows for same-device, cross-device, reconnect, history reload, and conversation-list preview cases.

**Rollback:** If the UI rollout must be paused, disable the mobile actions first while keeping backend mutations unused. If the query behavior for recalled messages causes regressions, the server and mobile DAO can temporarily revert to the prior hidden-delete filter while preserving the new edit capability.

## Open Questions

None. This change intentionally fixes the product direction for v1 as sender-only text editing plus tombstone-style recall.
