## Context

The mobile chat module currently uses `activeChatConversationIdProvider` as the single gate for whether a conversation is "actively viewed" and therefore allowed to send websocket `mark_read` events. `ChatScreen` sets that provider in `initState` and clears it only in `dispose`.

This approach is insufficient for the current router architecture because the app uses `StatefulShellRoute.indexedStack`, which can keep the chat branch and `ChatScreen` mounted even after the user has navigated away from the visible chat surface. In that state, inbound message sync and refresh paths can still call `_markConversationRead(...)`, causing an off-screen conversation to auto-see messages.

## Goals / Non-Goals

**Goals:**
- Ensure a conversation is only treated as actively viewed while its route is visibly foregrounded.
- Prevent off-screen mounted chat screens from sending `mark_read`.
- Preserve existing read/unread behavior for conversations the user is truly viewing.
- Make the active-view gate robust against tab switches, route overlays, and app backgrounding.

**Non-Goals:**
- Redesign websocket payloads or backend read-receipt semantics.
- Change seen-by placement or seen-by API contracts.
- Introduce per-message viewport detection before marking read.
- Rework the broader router structure beyond what is needed for correct active-state tracking.

## Decisions

### Track chat activity from visibility and route state, not only widget disposal

The mobile client will promote a conversation to "actively viewed" only when the corresponding chat route is currently foregrounded and demote it immediately when the route loses visibility, even if the widget remains mounted.

Why this approach:
- It aligns read behavior with what the user can actually see.
- It fixes the `indexedStack` preservation bug without relying on delayed disposal.
- It keeps the existing provider-based gating model while correcting the signal that drives it.

Alternative considered:
- Continue using `dispose()` to clear the active conversation. Rejected because mounted-but-hidden screens are a normal router behavior in this app.

### Include app lifecycle foreground state in the active-view gate

The active conversation gate will require both route visibility and an interactive app lifecycle state. A chat that remains on top of the branch while the app is backgrounded SHALL NOT keep auto-sending `mark_read`.

Why this approach:
- It closes another false-positive read path when the app is not actively being viewed.
- It keeps read receipts aligned with actual user attention.

Alternative considered:
- Route visibility only. Rejected because a visible route in a backgrounded app is still not truly being read.

### Gate every automatic read path behind the same resolved active-view state

All automatic read flows, including open synchronization, inbound websocket updates, and API refresh reconciliation, will rely on the same active-view evaluation before sending `mark_read`.

Why this approach:
- It prevents drift where one code path is fixed but another still auto-sees.
- It makes the behavior deterministic and easier to test.

Alternative considered:
- Patch only the initial open flow. Rejected because `_markConversationRead(...)` is invoked from multiple async paths after the screen is already mounted.

## Risks / Trade-offs

- **[Visibility state may lag route changes]** → Mitigation: update the active-view signal from explicit route/branch lifecycle hooks rather than passive polling.
- **[Foreground rules may suppress valid reads if too strict]** → Mitigation: preserve current behavior for the fully visible chat route and focus changes only on hidden/background cases.
- **[Multiple navigation surfaces can be subtle]** → Mitigation: verify behavior for branch switches, nested pushes, and notification-driven chat entry separately.
- **[State coordination becomes more cross-cutting]** → Mitigation: centralize the visibility-derived active-view decision instead of scattering route checks through individual read paths.

## Migration Plan

1. Introduce a visibility-aware active conversation signal for mobile chat.
2. Update chat screen lifecycle and router integration to set and clear that signal on foreground transitions, not only on disposal.
3. Route all automatic `mark_read` calls through the refined gate.
4. Verify navigation cases where the chat screen remains mounted but should no longer be considered active.

Rollback strategy:
- Revert to the existing `dispose`-based active conversation tracking if the visibility-driven gate causes regressions in legitimate read updates.

## Open Questions

- Should modal overlays such as image viewers or info sheets temporarily suspend `mark_read`, or only full route changes and branch changes?
