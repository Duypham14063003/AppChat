## 1. Composer Highlight Foundation

- [x] 1.1 Introduce a mention-aware text editing controller or equivalent composer text-span builder for `MessageInputBar`.
- [x] 1.2 Add deterministic per-user mention highlight colors and bold mention styling for tracked composer mentions.
- [x] 1.3 Wire the composer text field to use the mention-aware rendering path without regressing existing multiline, paste, emoji, or send behavior.

## 2. Mention Entity Integrity

- [x] 2.1 Refactor mention offset recalculation so edits before a mention shift offsets, edits after a mention leave it untouched, and edits intersecting a mention invalidate only the affected entity.
- [x] 2.2 Ensure selecting a mention followed by additional typing keeps the inserted mention span valid and excludes trailing text from the entity range.
- [x] 2.3 Preserve independence of multiple mentions in one draft so one broken mention does not corrupt the others.

## 3. Bubble Rendering Reliability

- [x] 3.1 Tighten `MessageBubble` mention span construction so inline mentions render correctly with text before and after them.
- [x] 3.2 Keep malformed or overlapping mention ranges fail-safe without hiding surrounding normal text.

## 4. Verification

- [x] 4.1 Add widget or unit tests for composer mention highlighting, stable mention colors, and mention invalidation on intersecting edits.
- [x] 4.2 Add rendering tests for mention placement at the start, middle, and end of a sentence, including trailing text after a mention.
- [ ] 4.3 Run manual verification for group-chat mention drafting and sent-message rendering on the affected UI targets.
