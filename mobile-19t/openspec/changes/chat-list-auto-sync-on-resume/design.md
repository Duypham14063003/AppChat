## Context

The mobile chat list is cache-first: `ChatListNotifier` loads local Drift data first and refreshes from the API in the background. It also listens to websocket `new_message` events and updates local conversation previews optimistically. That works for many live-message cases, but it leaves a gap when the app has been backgrounded or reopened after a message arrives outside the active session lifecycle.

The user-facing result is confusing: the server already has the new message, and the conversation detail screen can fetch it when opened, but the chat list remains stale until the user manually refreshes or enters the conversation. This makes the list feel unreliable as a source of “latest chat state.”

The fix should preserve the current local-cache-first architecture and websocket preview path while adding deterministic synchronization points that keep the list current after app resume and other lifecycle transitions.

## Goals / Non-Goals

**Goals:**
- Refresh the chat list automatically when the app returns to the foreground.
- Keep websocket-based preview updates, but ensure the list can recover when preview-only updates are insufficient.
- Make conversation previews, timestamps, and ordering reflect new server messages without requiring manual pull-to-refresh.
- Add verification coverage for resume-driven chat list synchronization.

**Non-Goals:**
- Rebuild the chat architecture around a global live-sync state model.
- Change backend websocket contracts or add new server endpoints for this fix.
- Redesign unread badge logic or notification badge sync beyond whatever chat-list refresh already picks up.
- Change conversation-detail synchronization behavior except where it already interacts with chat-list refresh.

## Decisions

### D1: Treat app resume as a deterministic chat-list synchronization point

**Decision:** When the app enters the foreground, the mobile client will explicitly refresh the chat list provider instead of relying only on stale cache plus later incidental navigation.

**Why:** Resume is the clearest lifecycle moment where server state may have drifted while the app was backgrounded. A direct refresh restores trust in the chat list without waiting for the user to open a conversation.

**Alternatives considered:**
- Only rely on websocket `new_message` events. Rejected because backgrounded sessions can miss timely local preview updates or resume into stale state.
- Refresh only when the user navigates back to the chat tab. Rejected because the user can already be on the chat tab and still see stale data.

### D2: Keep websocket preview writes, but allow refresh fallback to reconcile full list state

**Decision:** Continue updating local conversation previews immediately on `new_message`, while using provider refresh as the reconciliation path for ordering, missing preview fields, and any state missed while backgrounded.

**Why:** Websocket preview writes keep the UI responsive during active sessions, while API refresh remains the authoritative recovery path when local state is incomplete.

**Alternatives considered:**
- Remove websocket preview updates and always refetch the entire list. Rejected because it would reduce responsiveness and increase unnecessary network churn.
- Trust preview-only updates indefinitely. Rejected because the current bug shows preview/local updates alone are not enough across lifecycle transitions.

### D3: Keep auto-refresh scoped and idempotent

**Decision:** The resume-driven refresh should be safe to trigger repeatedly without causing obvious duplicate work or unstable list behavior.

**Why:** App lifecycle transitions can fire frequently. The sync point needs to be lightweight enough to run when resumed without creating runaway refresh loops.

**Alternatives considered:**
- Add aggressive periodic polling. Rejected because lifecycle-based refresh is cheaper and more directly tied to the stale-data window.

## Risks / Trade-offs

- [Risk] Resume-driven refresh may cause extra API calls during frequent app switching. → Mitigation: keep refresh logic idempotent and scoped to the existing conversation list fetch.
- [Risk] Websocket preview and API refresh could race, temporarily reordering rows. → Mitigation: continue writing conversation state through the existing local-store path and let the final refreshed list settle from persisted data.
- [Risk] Triggering refresh from lifecycle code could affect other screens unintentionally if done too broadly. → Mitigation: target chat-list synchronization explicitly instead of invalidating unrelated providers.

## Migration Plan

1. Add a chat-list refresh trigger tied to app foreground/resume.
2. Keep existing websocket preview updates and ensure list refresh can reconcile stale state after resume.
3. Add tests for resume-driven synchronization behavior and list freshness after inbound messages.
4. Manually verify that returning to the chat tab after backgrounding shows the newest message without pull-to-refresh.

**Rollback:** Remove the lifecycle-driven refresh trigger and fall back to the previous cache-only behavior if the new refresh point introduces severe performance or ordering regressions, though that would restore the stale-list UX gap.

## Open Questions

None. The immediate requirement is clear: chat list freshness should no longer depend on manual reload.
