## Context

Chat bubbles currently format every message timestamp with a single `HH:mm` pattern. That works for messages sent today, but it becomes ambiguous for older messages because the bubble itself no longer communicates the send date and users must infer it from surrounding day separators.

The bug is local to Flutter message rendering in `message_bubble.dart`, but the formatting choice affects every bubble type that renders `_buildTimestampRow()`, including text, media, voice, and forwarded/replied messages. The fix should stay visually compact while making older messages self-describing.

## Goals / Non-Goals

**Goals:**
- Keep same-day message timestamps compact and familiar.
- Include date information for messages that are not from the current day.
- Use one shared bubble timestamp formatter so all message types behave consistently.
- Add test coverage for same-day, prior-day, and prior-year timestamp formatting.

**Non-Goals:**
- Changing date separator behavior in the chat timeline.
- Redesigning message bubble layout, spacing, or metadata placement beyond the timestamp text itself.
- Introducing locale packages or a full i18n date-formatting system in this change.
- Changing pinned/bookmarked list timestamps outside the chat bubble.

## Decisions

### D1: Use contextual formatting based on whether the message is from today

**Decision:** Show `HH:mm` for messages sent today, and show a date-plus-time format for older messages.

**Why:** Same-day messages benefit from a short timestamp, but old messages need explicit date context to avoid ambiguity.

**Alternatives considered:**
- Always show full date and time. Rejected because it makes current-day chat noisier than necessary.
- Keep `HH:mm` everywhere and rely on day separators. Rejected because users can inspect isolated bubbles and still need the send date.

### D2: Use a numeric date format that stays compact in the bubble

**Decision:** Use a compact numeric format such as `dd/MM HH:mm` for older messages, and include the year only when the message is from a different calendar year.

**Why:** Numeric formatting fits narrow bubbles better than verbose month names while still making the date immediately legible.

**Alternatives considered:**
- Use relative labels like "Hôm qua". Rejected because they become unstable over time and are less precise in historical chat context.
- Use a verbose format like `21 thg 4, 12:20`. Rejected because it consumes more space in already dense bubbles.

### D3: Keep formatting logic local and testable

**Decision:** Implement bubble timestamp formatting through a small helper in the message bubble layer and cover it with focused widget/unit tests.

**Why:** The bug is presentation-specific, so a local helper is enough and avoids unnecessary architecture churn.

**Alternatives considered:**
- Introduce a global date-format utility immediately. Rejected because the current need is narrow and well-scoped.

## Risks / Trade-offs

- [Risk] Older timestamps become slightly wider and may affect tight bubble layouts. → Mitigation: use compact numeric formatting and verify across representative bubble types.
- [Risk] Local timezone assumptions could make edge cases around midnight appear surprising. → Mitigation: keep using the existing local `DateTime` semantics already used elsewhere in chat UI.
- [Risk] Future localization work may want a different formatting strategy. → Mitigation: keep the formatter isolated so it can be swapped later.

## Migration Plan

1. Replace the current fixed `HH:mm` formatter in the message bubble with contextual date-aware formatting.
2. Reuse the shared formatter for every timestamp row rendered inside chat bubbles.
3. Add tests for today, prior-day, and prior-year outputs.
4. Manually verify bubble rendering in a conversation containing both recent and older messages.

**Rollback:** Revert to the current `HH:mm` formatter if the new format causes unacceptable layout regressions, though that would restore the ambiguity for older messages.

## Open Questions

None. The intended format direction is compact same-day time and explicit date for older messages.
