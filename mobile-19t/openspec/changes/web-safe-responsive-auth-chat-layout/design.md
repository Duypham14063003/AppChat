## Context

The current Flutter app already has several screens that behave differently on wide layouts. Profile and HR screens use centered `ConstrainedBox` containers on larger viewports, and the main shell already switches to a desktop split layout with a `NavigationRail`, embedded `ChatListScreen`, and an expanded conversation pane.

The problem is that the login and chat conversation experiences still behave like stretched mobile screens when rendered on the web. The login form expands across the browser width, and the chat pane keeps the shell split while letting the internal conversation content run edge-to-edge inside a very large pane. That makes the message timeline, empty space rhythm, and composer feel visually broken on desktop. At the same time, phone layouts are already stable and should not be redesigned as part of this change.

## Goals / Non-Goals

**Goals:**
- Keep the current narrow/mobile layouts unchanged.
- Constrain wide-screen authentication content into a centered frame on desktop-sized web viewports.
- Constrain the chat conversation internals into a centered content frame inside the existing desktop chat pane.
- Keep related chat surfaces aligned within the same frame, including pinned state, timeline, typing indicator, composer, and nearby floating affordances.
- Make wide-layout activation depend on the relevant container width, not only the full screen width, where doing so avoids tablet regressions.

**Non-Goals:**
- Rebuilding the desktop shell navigation or changing the current rail + chat-list split.
- Redesigning colors, bubble shapes, typography, or message grouping rules.
- Changing backend APIs, websocket flows, or chat data models.
- Solving every pre-existing chat alignment issue that is unrelated to wide-screen web rendering.

## Decisions

### Use container-constrained layouts for wide authentication and chat surfaces

The implementation should introduce centered, bounded layout frames for the specific wide-screen experiences that currently stretch too far: login and the conversation pane internals. The surrounding screen background can remain full-width, but the main interactive content should sit inside an explicit max-width container.

Why:
- This matches patterns that already exist in wide profile and HR screens.
- It improves desktop readability without redefining the mobile composition.
- It isolates the responsive fix to layout containers rather than changing the underlying field, bubble, or message rendering logic everywhere.

Alternatives considered:
- Let the screens remain full-width and only reduce widget padding. Rejected because it still leaves the login form and composer visually oversized on desktop.
- Build a separate dedicated desktop auth/chat UI. Rejected because the current need is layout safety, not a full desktop redesign.

### Make the chat conversation layout pane-aware

The chat screen should determine its wide treatment from the available conversation pane width, not only from the total browser width. The existing shell already consumes width for the rail and embedded chat list, so a global screen breakpoint can activate desktop behavior too early on mid-sized devices.

Why:
- On web and tablet layouts, the conversation pane can be significantly narrower than the overall viewport.
- Pane-aware layout keeps the responsive logic aligned with the content that actually needs constraining.
- This reduces the risk of breaking tablet or narrow desktop windows where the full screen is wide but the remaining chat pane is not.

Alternatives considered:
- Reuse the global `isWide = width >= 768` check everywhere. Rejected because it is already too coarse for the nested desktop chat layout.
- Apply no breakpoint and always constrain the pane. Rejected because it would unnecessarily alter narrow/mobile presentation.

### Keep message bubble sizing logic stable and constrain the surrounding frame instead

The current bubble logic already limits individual bubble width. This change should primarily constrain the conversation canvas that contains the timeline, composer, and aligned surfaces, rather than redefining bubble width rules globally.

Why:
- Bubble width is shared across mobile and wide layouts and already participates in other ongoing chat changes.
- Constraining the outer frame solves the desktop whitespace problem with lower regression risk.
- This keeps the fix focused on wide-screen layout composition rather than local message rendering behavior.

Alternatives considered:
- Increase or decrease bubble `maxWidth` globally. Rejected because it can unintentionally affect mobile spacing and message density.
- Rework message grouping and alignment rules as part of this change. Rejected because that belongs to separate chat-specific fixes.

### Align all adjacent chat surfaces to the same wide content frame

The responsive chat layout should treat the pinned message bar, message list, typing indicator, reply/edit preview, composer, and nearby floating controls as one aligned content system. These surfaces should not use different horizontal frames on wide layouts.

Why:
- A centered timeline with a full-width composer still feels broken.
- Users perceive the conversation UI as one composite surface, not separate stacked widgets.
- Aligning these surfaces together reduces visual drift when moving between empty state, active conversation, and search-related states.

Alternatives considered:
- Constrain only the message list. Rejected because the composer and other bars would still span the full pane and preserve the broken feel.

## Risks / Trade-offs

- **[Risk]** A wide-frame breakpoint chosen too aggressively could change tablet behavior that currently feels acceptable. → **Mitigation:** base wide chat treatment on pane width and verify phone, tablet, and desktop widths separately.
- **[Risk]** Constraining only part of the conversation stack could create misalignment between the timeline and composer. → **Mitigation:** align all major chat surfaces to the same wide content frame.
- **[Risk]** Existing direct-chat spacing bugs could be confused with this wider responsive effort. → **Mitigation:** keep this change focused on web-safe wide layout composition and leave unrelated bubble logic fixes to their dedicated change unless the same files naturally overlap during implementation.
- **[Trade-off]** This change improves desktop readability without introducing a bespoke desktop UI. → **Mitigation:** keep the design additive so a richer desktop redesign can build on the same constrained-frame pattern later.

## Migration Plan

1. Add responsive auth layout behavior to the login screen using a centered max-width container on wide viewports.
2. Add a shared wide-layout content frame for the chat conversation pane internals.
3. Verify that shell-level desktop chat split behavior still works as before while the conversation content becomes visually bounded.
4. Run mobile and wide-layout verification to confirm narrow layouts remain unchanged.

Rollback:
- The change is frontend-only and additive. If regressions appear, revert the responsive container logic and fall back to the existing mobile-first full-width layouts.

## Open Questions

None. The change assumes that preserving the existing shell split and introducing bounded content frames is the preferred first-step strategy for web-safe responsiveness.
