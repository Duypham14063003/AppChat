## Context

The existing mention feature already stores entities in `metadata.mentions` and renders sent mentions in `MessageBubble`, but the composer and renderer do not share a strict integrity model for mention ranges. In practice, the current `MessageInputBar` updates offsets with a lightweight diff and removes entities only for some edit patterns, which makes inline mentions fragile when users keep typing before or after a tagged name.

The chat composer is also still a plain `TextEditingController` + `TextField` setup, so mentions look identical to normal text while drafting. That makes it hard for users to tell whether a visible `@Name` is still a tracked entity or has already been broken by subsequent edits.

## Goals / Non-Goals

**Goals:**
- Preserve valid mention entities when draft text changes around them.
- Remove or rebuild invalid entities deterministically when a user edits inside a mention span.
- Render inline mentions correctly in sent messages regardless of whether text appears before or after the mention.
- Highlight tracked mentions in the composer with bold text and stable per-user accent colors.
- Add regression coverage for inline mention placement and composer highlighting.

**Non-Goals:**
- Changing the backend mention schema or validation rules.
- Adding new mention types beyond existing user mentions and `@all`.
- Introducing profile navigation or new mention tap interactions.
- Reworking the autocomplete member search UX beyond what is needed for entity integrity.

## Decisions

### D1: Keep `metadata.mentions` as the only persisted contract
**Choice:** Continue using the current `{offset, length, user_id, name}` entity model in `metadata.mentions` without any API or schema change.
**Rationale:** The bug is in client-side entity bookkeeping and rendering, not in the payload shape. Keeping the same contract isolates the change to Flutter code and avoids unnecessary migration or backend work.
**Alternative considered:** Normalizing composer mentions into a different local data shape and transforming on send. Rejected because it increases moving parts without solving the real issue.

### D2: Move composer highlighting into a custom `TextEditingController`
**Choice:** Replace the plain controller with a mention-aware controller that overrides `buildTextSpan()` based on the current tracked mentions.
**Rationale:** This lets the existing `TextField` keep native selection, IME, paste, and multiline behavior while gaining rich inline styling. It is the smallest architectural step that adds realtime mention highlighting without replacing the input widget.
**Alternative considered:** Overlaying a separate `RichText` behind a transparent `TextField`. Rejected because it is harder to keep cursor, selection, scrolling, and accessibility aligned.

### D3: Use stable per-user colors from a fixed palette
**Choice:** Map each mention to a color from a small fixed palette using a deterministic hash of `user_id`, while keeping bold weight for all mentions.
**Rationale:** Users asked for a random-looking color treatment, but true randomness per rebuild would cause visible flicker. Deterministic palette selection gives visual variety while keeping the same user recognizable across frames and edits.
**Alternative considered:** Single global accent color for all mentions. Rejected because it does not satisfy the requested richer composer feedback.

### D4: Recalculate mention integrity from text spans, not only raw offset shifting
**Choice:** Strengthen composer bookkeeping so text edits are evaluated against each mention span, with explicit handling for three cases: edits before a mention shift the offset, edits fully inside a mention invalidate that entity, and edits after a mention leave it untouched.
**Rationale:** The current diff logic is too permissive and can leave stale ranges behind, especially when a mention is followed by more text. A span-oriented pass is easier to reason about and easier to test with start/middle/end sentence cases.
**Alternative considered:** Attempting to patch the existing offset-only logic with more conditions. Rejected because it would keep the behavior opaque and brittle.

### D5: Make bubble rendering tolerant but not corrective
**Choice:** `MessageBubble` should continue to guard against invalid or overlapping ranges, but it must render all valid inline mention spans exactly as described by metadata, including text before and after them.
**Rationale:** The composer is responsible for generating valid entities; the bubble should not attempt to infer or repair broken mentions. Its job is to render valid spans reliably and ignore malformed ranges safely.
**Alternative considered:** Re-parsing visible `@Name` patterns from plain text as a fallback. Rejected because it would diverge from the persisted entity model and could highlight false positives.

## Risks / Trade-offs

- `[Custom controller styling may regress IME or selection behavior]` → Keep the native `TextField`, limit the change to `buildTextSpan()`, and cover common drafting flows with widget tests.
- `[Entity invalidation may feel aggressive if users edit near a mention]` → Only remove entities when the edit intersects the tracked mention span; preserve mentions for edits before or after the span.
- `[Stable palette colors may have low contrast in some themes]` → Choose colors that remain readable against the existing composer background and fall back to current text color rules when needed.
- `[Renderer and composer may drift again over time]` → Reuse shared mention parsing assumptions and add edge-case tests for start, middle, end, and trailing-text placements.

## Migration Plan

No migration or rollout sequencing is required. The change is client-only and backwards compatible with existing stored `metadata.mentions` payloads.

Rollback is low risk: reverting the Flutter changes restores the previous plain-text composer and current mention bookkeeping behavior without affecting persisted messages.

## Open Questions

- None at this stage; the remaining work is implementation and verification.
