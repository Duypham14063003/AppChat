## ADDED Requirements

### Requirement: Wide chat conversations use a centered content frame
The mobile app SHALL render wide chat conversations inside a centered, bounded content frame within the existing desktop conversation pane. The message timeline SHALL no longer rely on the full pane width when the pane is large enough for desktop-style presentation.

#### Scenario: Open a conversation in the desktop shell
- **WHEN** the user opens a chat conversation inside the wide desktop shell
- **THEN** the conversation timeline renders inside a centered content frame within the expanded conversation pane instead of stretching edge-to-edge across the full pane

#### Scenario: Message rhythm remains readable on wide panes
- **WHEN** the conversation pane is significantly wider than a mobile layout
- **THEN** the app keeps the message canvas visually bounded so bubble spacing and empty-state rhythm remain readable on desktop

### Requirement: Chat-adjacent surfaces align to the same wide frame
The mobile app SHALL align wide-layout chat-adjacent surfaces to the same bounded content frame used by the message timeline, including the pinned-message surface, typing indicator, composer area, and nearby floating affordances that belong to the conversation canvas.

#### Scenario: Composer alignment on wide chat panes
- **WHEN** the app shows the message composer in a wide chat conversation
- **THEN** the composer aligns to the same bounded content frame as the message timeline rather than spanning the full pane width independently

#### Scenario: Auxiliary conversation surfaces stay aligned
- **WHEN** the app shows pinned-message state, typing state, or conversation empty state on a wide chat pane
- **THEN** those surfaces align to the same horizontal content frame as the main timeline

### Requirement: Chat responsive behavior preserves narrow/mobile presentation
The mobile app SHALL preserve the current phone and narrow-tablet chat layout when the available conversation space is below the wide-layout threshold.

#### Scenario: Open chat on a phone-sized viewport
- **WHEN** the user opens a conversation on a phone-sized viewport
- **THEN** the app keeps the existing mobile-first chat layout and message composition behavior

#### Scenario: Avoid premature desktop framing on constrained panes
- **WHEN** the overall screen is wide but the actual conversation pane is still constrained by shell chrome or window size
- **THEN** the app delays the bounded desktop conversation frame until the pane itself has enough width to support it safely
