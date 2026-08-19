## Context

The Flutter chat screen builds incoming and outgoing message rows through `MessageItem` and `MessageBubble`. Group conversations intentionally reserve a left-side gutter for avatars and optional sender names, while direct conversations suppress that chrome by passing `showAvatar: false` and `showSenderName: false`.

The current incoming-bubble branch in `message_bubble.dart` still enters the "sender chrome" layout whenever `senderName` or `senderAvatar` is present, even if the caller explicitly disabled avatar and sender-name display. In direct chats, `senderName` is usually available, so the widget inserts an empty spacer where the avatar gutter would normally be. That creates the visible left offset in personal conversations.

## Goals / Non-Goals

**Goals:**
- Remove unintended left gutter spacing from incoming direct-message bubbles.
- Preserve existing incoming group-chat behavior, including avatar and sender-name alignment.
- Keep forwarded headers, quoted replies, timestamps, and reaction rows visually aligned with the corrected bubble position.

**Non-Goals:**
- Redesign bubble colors, typography, or tail shapes.
- Change message grouping rules or avatar visibility policy.
- Introduce backend, data-model, or websocket changes.

## Decisions

### Use explicit display intent instead of inferred sender metadata
The incoming-bubble layout should only reserve avatar/sender chrome when the caller explicitly requests it, not merely because sender metadata exists. This keeps direct-chat layout tied to `showAvatar` and `showSenderName`, which already encode the screen-level intent.

Alternative considered:
- Continue branching on `senderName != null || senderAvatar != null` and only remove the spacer when `showAvatar` is false.
- Rejected because it still mixes two different concepts: whether metadata exists and whether the layout should expose sender chrome.

### Keep group layout behavior unchanged
Group chats still need their current gutter behavior for avatar alignment, sender-name headers, and grouped message rhythm. The fix should be scoped so only direct incoming bubbles stop reserving empty gutter space.

Alternative considered:
- Flatten all incoming bubbles into one shared layout.
- Rejected because it risks regressions in group-chat alignment and grouped-avatar timing.

### Verify nearby alignment surfaces during implementation
The bubble position itself is the primary bug, but adjacent UI such as reaction bars and reply/forward content should be checked after the layout fix to ensure they continue to align with the bubble edge.

Alternative considered:
- Limit scope to the bubble container only.
- Rejected because nearby surfaces visually depend on the same left-edge anchor.

## Risks / Trade-offs

- **[Risk]** A narrow fix in `MessageBubble` could leave reaction rows or other adjunct UI slightly offset relative to the bubble edge. → **Mitigation:** verify incoming direct-chat reactions, forwarded messages, and quoted replies after the spacing change.
- **[Risk]** Group-chat avatar timing could regress if the incoming layout branch is changed too broadly. → **Mitigation:** keep group behavior driven by `showAvatar` / `showSenderName` and preserve existing `isLastInGroup` handling.
- **[Trade-off]** The fix favors explicit display flags over convenience inference from sender metadata. → **Mitigation:** this makes the layout contract clearer and easier to reason about across direct vs. group conversations.
