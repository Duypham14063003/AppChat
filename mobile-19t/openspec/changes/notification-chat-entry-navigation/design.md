## Context

The mobile app already handles notification taps centrally in `apps/mobile/lib/app.dart`. Chat notifications currently resolve to `/chat/:id`, but the tap handler uses `router.go(...)`, which replaces the current location instead of entering chat as a temporary detail route. On mobile, `ChatScreen` relies on the navigation stack to show the default back button, so replacing the location removes the expected exit path.

The router already supports two chat entry patterns in normal UI flow:
- `push('/chat/:id')` for narrow/mobile navigation, where chat is opened as a detail screen and can be popped
- `go('/chat/:id')` for embedded or shell-like transitions, where chat becomes the active location directly

This change is intentionally narrow. It only addresses chat entry from notifications and does not redesign notification payloads, unread badge handling, or broader deep-link architecture.

## Goals / Non-Goals

**Goals:**
- Preserve a visible back affordance when the user opens a chat from a notification on mobile.
- Keep existing notification tap routing for non-chat destinations working as-is.
- Reuse the app's existing route structure rather than introducing duplicate chat routes.
- Add verification coverage for the navigation mode chosen for chat notification entry.

**Non-Goals:**
- Fix notification badge count or unread clearing behavior.
- Redesign chat app bar visuals or manual back-button widgets.
- Change desktop or web notification click behavior beyond what is required to keep chat entry coherent.
- Introduce backend payload or API changes.

## Decisions

### D1: Treat chat notification entry as push-style navigation on mobile

**Decision:** Notification taps targeting `/chat/:id` will use push-style navigation semantics instead of unconditional `go(...)`.

**Why:** A chat opened from a notification behaves like a detail screen layered on top of the app shell. Push-style navigation preserves the route underneath, allowing Flutter's default app bar leading behavior to surface a back button naturally.

**Alternatives considered:**
- Keep `go(...)` and manually inject a custom back button into `ChatScreen`. Rejected because it would mask the navigation-state problem and create inconsistent behavior between entry paths.
- Add a separate notification-only chat route. Rejected because it duplicates routing concerns for the same screen and increases maintenance cost.

### D2: Keep notification route resolution separate from navigation mode selection

**Decision:** Continue resolving notification payloads into app routes, but decide navigation method based on destination type rather than embedding stack semantics into the route string itself.

**Why:** The existing `routeForNotificationData(...)` helper is still useful as a route resolver. The missing behavior is not route discovery; it is how that route is entered. Separating these concerns keeps the notification contract simple and makes future destination-specific navigation policies easier to extend.

**Alternatives considered:**
- Encode a custom “push” flag directly into payload-derived routes. Rejected because the route string should represent location, not transition policy.
- Replace all notification navigation with push semantics. Rejected because shell destinations like `/hr` are better treated as tab/shell navigation, not stacked details.

### D3: Verify behavior through notification routing tests focused on chat entry semantics

**Decision:** Extend notification-related tests to cover the chat-specific navigation expectation rather than only checking route parsing.

**Why:** Existing tests prove payload-to-route mapping but do not guard the user-facing regression here. This bug exists specifically because route mapping passed while navigation semantics were wrong.

**Alternatives considered:**
- Rely on manual QA only. Rejected because notification entry bugs are easy to reintroduce when routing code changes.

## Risks / Trade-offs

- [Risk] Pushing the same chat repeatedly from multiple notification taps could stack duplicate conversation screens. → Mitigation: implementation should check current location or otherwise keep notification re-entry behavior deliberate and predictable.
- [Risk] Notification tap handling may run before auth/shell state is fully restored on cold start. → Mitigation: keep routing within the existing authenticated app flow and verify terminated-state handling during implementation.
- [Risk] Using destination-specific navigation rules can grow ad hoc over time. → Mitigation: confine the rule to chat detail entry and keep the helper boundary explicit.

## Migration Plan

1. Update notification tap handling to use push-style navigation for chat conversation destinations.
2. Leave shell/root destinations on their existing navigation behavior.
3. Add or expand notification routing tests to cover chat-entry stack expectations.
4. Manually verify background and terminated notification taps on mobile.

**Rollback:** Revert the notification chat-entry decision back to `go(...)` if the push behavior introduces severe duplicate-stack issues, though that would restore the missing-back-button regression.

## Open Questions

None. The user-facing problem and the preferred navigation behavior are both clear for this change.
