## Why

The current mention flow breaks down when a tagged user appears inside a longer sentence, especially when normal text follows the mention. That makes group messages render inconsistently and undermines trust in the mention feature just as users start relying on it in real conversations.

The composer also treats mentions as plain text while typing, so users cannot visually confirm which parts of the draft are tracked mention entities. Adding realtime mention highlighting makes the drafting experience clearer and reduces accidental broken mentions before send.

## What Changes

- Fix mention entity tracking in the chat composer so mentions keep valid offsets and lengths when users insert, delete, or keep typing around them.
- Tighten mention rendering rules in message bubbles so mentions at the start, middle, or end of a sentence render correctly even when surrounding text exists.
- Add composer-side rich text highlighting for tracked mentions while the user is typing, using bold styling and stable per-user accent colors.
- Add automated coverage for mention placement edge cases and composer highlighting behavior to prevent regressions.

## Capabilities

### New Capabilities
- None.

### Modified Capabilities
- `mention-autocomplete`: Mention entities must remain valid while surrounding draft text changes, and the composer must visually highlight tracked mentions during drafting.
- `mention-rendering`: Message bubbles must render valid mention spans correctly when mentions appear inline with additional text before or after them.

## Impact

- Affected mobile code is centered in `MessageInputBar`, mention entity bookkeeping, custom composer text rendering, and `MessageBubble` mention span construction.
- No API or database contract changes are expected because the existing `metadata.mentions` structure remains the source of truth.
- Test coverage will need to expand around mention parsing, offset recalculation, and composer rendering behavior.
