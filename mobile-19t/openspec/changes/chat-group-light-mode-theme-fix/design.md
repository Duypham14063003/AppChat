## Context

The app theme system already supports multiple presets, including the light `ivorySlate` palette, through `context.appPalette`. However, several chat and group-management flows still use legacy `AppColors` constants that were designed for the dark-only UI. This creates mismatched surfaces in light mode: dialogs stay dark, search hints can lose contrast, loading overlays feel too heavy, and some action rows visually clash with the page background.

The affected flows are not isolated to one widget. They span group rename dialogs, group-creation search flows, new-chat contact search, add-member dialogs, and member-removal confirmation dialogs. Because these screens already live inside the new theme system, the fix should standardize them on palette-aware neutral colors rather than introducing another theme layer.

## Goals / Non-Goals

**Goals:**
- Make the listed chat/group flows visually correct in both light and dark presets.
- Replace hardcoded dark neutrals with theme-palette values for surfaces, text, hints, icons, borders, and scrims.
- Preserve semantic accent colors such as destructive and warning actions where they communicate meaning.
- Add verification coverage for representative light-mode rendering behavior.

**Non-Goals:**
- Redesign the overall chat/group UX or change the information architecture of these screens.
- Refactor every remaining `AppColors` usage across the entire app in this change.
- Change backend behavior, chat state management, or navigation semantics.

## Decisions

### D1: Use `context.appPalette` as the source of truth for neutral UI colors

**Decision:** Neutral colors in the affected chat/group flows will be derived from `context.appPalette` instead of `AppColors.*` dark constants.

**Why:** The palette system already captures the active preset for both light and dark themes, so reusing it is the most direct way to make these screens adaptive without duplicating color logic.

**Alternatives considered:**
- Keep using `AppColors` and add special light-mode overrides case by case. Rejected because it duplicates theme logic and is hard to maintain.
- Introduce a second chat-specific theme abstraction. Rejected because the app already has a shared palette system.

### D2: Keep semantic action colors but adapt surrounding surfaces

**Decision:** Destructive/warning accents may still use semantic colors such as `danger` and `warning`, while backgrounds, typography, neutral icons, and scrims become palette-driven.

**Why:** The bug is primarily about broken neutral contrast, not about the existence of semantic action colors. Preserving those accents keeps intent clear while fixing readability and visual consistency.

**Alternatives considered:**
- Convert every accent color to a palette-derived tone. Rejected because it broadens the change and risks weakening destructive affordances.

### D3: Treat dialogs, inline search fields, and empty states as the primary verification targets

**Decision:** The implementation will focus testing and manual verification on representative problem surfaces: dialogs, add/search flows, and chat search app bars.

**Why:** These are the UI states shown in the bug report and the ones most likely to regress when theme handling is inconsistent.

**Alternatives considered:**
- Add broad screenshot coverage for every chat screen. Rejected because it adds heavy test scope for a targeted theme fix.

## Risks / Trade-offs

- [Risk] Some dark-mode screens may shift slightly when neutral colors are migrated to palette values. → Mitigation: keep semantic accents unchanged and verify both light and dark representative flows.
- [Risk] A few nested widgets may still inherit old hardcoded colors, leaving partial fixes. → Mitigation: target the specific reported flows and add focused rendering tests around them.
- [Risk] Scrim/overlay tuning may feel too strong or too weak after moving away from fixed black alpha. → Mitigation: use palette-aware overlay values that preserve readability without overpowering light mode.

## Migration Plan

1. Audit and update the reported chat/group flows to replace hardcoded dark neutrals with palette-aware values.
2. Ensure dialogs, search bars, chips, empty states, and loading overlays render correctly in the light preset.
3. Add tests for representative light-mode chat/group surfaces.
4. Manually verify the reported flows in the light preset and spot-check dark mode for regressions.

**Rollback:** Revert the theme-adaptive styling changes in the affected chat/group screens if the palette migration introduces unacceptable regressions.

## Open Questions

None.
