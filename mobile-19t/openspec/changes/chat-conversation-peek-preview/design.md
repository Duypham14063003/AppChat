## Context

The current mobile chat entry flow is intentionally read-stateful:

- `ConversationTile.onTap` navigates to `/chat/:id`.
- `ChatScreen` sets `activeChatConversationIdProvider` after the first frame.
- `chatMessagesProvider` loads cached messages and calls `_markConversationRead`.
- `_markConversationRead` clears local unread counters with `dao.markConversationViewed`, syncs badge state, sends websocket `mark_read`, invalidates the chat list, and refreshes it.

That is the right behavior for entering a conversation. It is the wrong behavior for a preview/peek experience because simply looking at a few messages should not consume the unread state.

## Goals / Non-Goals

**Goals:**
- Let users preview recent messages from the chat list without marking the conversation as read.
- Preserve the current tap-to-open behavior and existing read-sync behavior for full conversation entry.
- Keep the preview read-only and visually distinct from the full chat screen.
- Avoid reusing provider paths that automatically call read reconciliation.
- Support both narrow/mobile and wide/tablet layouts.
- Add tests that prove previewing does not clear unread counters or send read events.

**Non-Goals:**
- Changing backend read/unread contracts.
- Changing notification badge semantics outside the preview guardrails.
- Replacing `ChatScreen` or rewriting the chat provider architecture.
- Adding message sending, reactions, editing, or attachments inside the preview.
- Changing search-result navigation behavior.

## Decisions

### D1: Use long-press as the peek gesture

**Decision:** Long-pressing a conversation row opens the peek preview. Single tap keeps the existing full-chat navigation.

**Why:** Single tap is already the strongest learned behavior for entering a conversation and marking it read. Long-press matches common chat app patterns for secondary preview/actions without surprising users.

**Alternatives considered:**
- Make single tap open preview. Rejected because it breaks existing navigation expectations.
- Add a separate icon button on every row. Rejected because it clutters the list and makes the primary row layout heavier.

### D2: Do not reuse `ChatScreen` for peek mode

**Decision:** Implement a dedicated read-only preview surface instead of adding a "peek mode" to `ChatScreen`.

**Why:** `ChatScreen` is deeply tied to active conversation state, synchronization on open, typing, input, selection mode, and read reconciliation. Reusing it risks accidentally clearing unread state or sending `mark_read`.

**Alternatives considered:**
- Add a boolean `peekMode` to `ChatScreen`. Rejected because it would require guarding many active-chat side effects and would be easy to regress.
- Navigate to a separate route. Rejected for initial scope because a transient sheet/dialog better matches a quick peek interaction and avoids route/read-state coupling.

### D3: Load preview messages through a read-only path

**Decision:** Preview loading should use a separate provider or helper that reads recent cached messages first and may optionally fetch recent server messages, but never calls `_markConversationRead`, never sets `activeChatConversationIdProvider`, and never sends websocket `mark_read`.

**Why:** The current `chatMessagesProvider` intentionally marks the active conversation as read. A separate read-only path keeps the safety boundary obvious.

**Implementation shape:**
- Add a preview provider such as `chatConversationPreviewProvider(convId)`.
- Prefer local cached messages for instant rendering.
- Optionally call `ChatRepository.getMessages(convId)` to refresh preview content and cache results.
- Return recent messages ordered for display without mutating unread counters.
- Avoid attaching full chat websocket listeners unless they can be proven read-safe.

### D4: Use bottom sheet on narrow screens and dialog/popover on wide screens

**Decision:** On phones, show a rounded modal bottom sheet. On wide layouts, show a centered dialog or anchored popover that does not replace the current split chat layout.

**Why:** A sheet feels natural on mobile and can display enough message context while preserving the chat list underneath. On wide screens, a dialog/popover avoids disturbing the split-pane layout.

**Suggested UI:**
- Header with avatar, conversation name, unread badge count, and close action.
- Message list preview with recent bubbles/text rows.
- Optional small copy: "Previewing does not mark as read."
- Footer action: "Open chat" that navigates to the full chat screen.

### D5: Full entry remains the only read-consuming action

**Decision:** Read state should only change when the user explicitly opens the full chat, not when the preview is shown, scrolled, dismissed, or refreshed.

**Why:** The feature's core value is preserving unread state after preview. Any implicit read side effect would defeat the product behavior.

**Guardrails:**
- Preview code must not write `lastViewedAt`.
- Preview code must not reset `unreadCount` or `unreadMentionCount`.
- Preview code must not call `sendMarkRead`.
- Preview code must not set `activeChatConversationIdProvider`.
- The full "Open chat" action can reuse the existing navigation path, intentionally allowing existing read-sync to run.

## Risks / Trade-offs

- [Risk] Preview provider accidentally reuses `chatMessagesProvider` and clears unread. → Mitigation: create a dedicated read-only preview provider and add tests around unread preservation.
- [Risk] Fetching preview messages from the API may update local message cache and conversation preview ordering. → Mitigation: allow message cache writes but forbid read-state writes; this still preserves unread state.
- [Risk] Long-press can conflict with future row actions. → Mitigation: keep the first long-press action as peek, and add other actions inside the preview or a later context menu if needed.
- [Risk] Media-heavy conversations may render awkwardly in preview. → Mitigation: use simplified message rows with text/media labels for initial scope.
- [Risk] Wide split layout already has a selected conversation panel. → Mitigation: preview should be transient and separate from selection so it does not set selected/active conversation.

## Migration Plan

No schema or backend migration is required.

1. Add read-only preview loading logic.
2. Add preview UI surface and connect it to conversation long-press.
3. Keep single tap navigation unchanged.
4. Add tests that verify preview does not clear local unread state or call read-sync helpers.
5. Manually verify phone and wide layouts with unread conversations.

Rollback is low risk: remove the long-press preview gesture and preview widget while leaving normal chat navigation unchanged.

## Open Questions

- Should the preview show only the latest cached messages, or also perform a background API refresh? The recommended default is cache-first plus optional server refresh, as long as read state is untouched.
- Should the preview include an unread separator or simply show the newest messages? Initial implementation can omit the separator and rely on the existing unread badge in the header.
