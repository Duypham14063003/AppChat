## Context

The app uses `go_router` with a `ShellRoute` for the four root sections exposed in the bottom navigation: Chat, HR, Tasks, and Profile. In `MainShell`, tapping a destination calls `context.go(...)`, which updates the active child route. Because these tab roots are modeled as regular `GoRoute` pages inside a standard shell, the UI can inherit route-transition behavior that feels like pushing a new page from left to right rather than switching between persistent tabs.

That motion clashes with the UX expectation of bottom navigation. Users typically expect tab changes to be instantaneous or minimally animated, while detail screens such as chat conversations, HR history, payroll config, and task detail can continue to use normal push transitions. The router structure is therefore the key design surface: the fix should target root-tab navigation without degrading nested route behavior.

## Goals / Non-Goals

**Goals:**
- Remove push-style horizontal transitions when switching among the four bottom-navigation root tabs.
- Preserve standard push navigation animations for deeper screens opened from within a tab.
- Keep tab selection state and route-driven index synchronization coherent across narrow and wide layouts.
- Prefer a shell structure that better matches persistent-tab semantics and future per-tab state retention.

**Non-Goals:**
- Redesign the visual appearance of the bottom navigation bar or navigation rail.
- Change the route paths for existing tabs or detail screens.
- Redesign nested navigation flows inside chat, HR, tasks, or profile.
- Introduce custom animated tab content transitions for this change.

## Decisions

### D1: Treat root tabs as shell branches rather than ordinary shell children

**Decision:** Model the four root tabs using a navigation structure intended for persistent tab branches, with tab switching handled as branch changes instead of ordinary page transitions.

**Why:** Bottom navigation is semantically a shell with stable destinations, not a stack of sibling pages being pushed over one another. A branch-oriented shell makes the intended behavior explicit and aligns with the UX expectation that tabs switch context rather than navigate forward.

**Alternatives considered:**
- Keep the current `ShellRoute` and rely on route replacement through `context.go`. Rejected because it preserves the conceptual mismatch that causes the current transition behavior.
- Manually override every tab root with ad-hoc page transitions while keeping the same shell shape. Rejected as a smaller patch that does not improve the overall router semantics as clearly.

### D2: Use no-transition behavior for tab-root switches

**Decision:** Root tab switches should use no horizontal transition, or the equivalent branch-switch behavior provided by the shell container.

**Why:** The user complaint is specifically about the left-to-right slide. Instant or nearly instant switching is a better default for bottom navigation and matches widely expected mobile behavior.

**Alternatives considered:**
- Replace the current slide with a fade. Rejected because even a fade is unnecessary for this shell interaction and still treats the tab change as a screen transition.
- Keep the slide but shorten the duration. Rejected because the directionality is the bigger UX issue than the timing.

### D3: Keep detail screens on the root navigator with existing push semantics

**Decision:** Preserve current detail-screen routing for pages such as chat threads, HR subpages, and task detail so only root-tab switching changes.

**Why:** The problem is isolated to shell tab changes. Detail screens still benefit from normal push navigation cues, and narrowing scope keeps the router refactor safer.

**Alternatives considered:**
- Flatten all nested routes into branch navigators at once. Rejected because it broadens the change beyond the reported UX issue.

## Risks / Trade-offs

- [Risk] Refactoring the shell could subtly affect tab index synchronization or wide-layout rendering. → Mitigation: keep route-path mapping explicit and verify both narrow bottom navigation and wide navigation rail behavior.
- [Risk] A deeper shell refactor may preserve branch state differently than the current setup. → Mitigation: define expected state-retention behavior in tests and use router APIs intended for branch switching.
- [Risk] A quick no-transition patch could solve the animation symptom but miss long-term branch-state benefits. → Mitigation: prefer a branch-aware shell design and note `NoTransitionPage` only as fallback if implementation complexity appears unexpectedly high.

## Migration Plan

1. Update the root router shell so the four tab destinations behave as persistent branches.
2. Ensure tab taps switch branches without left-to-right page transitions.
3. Keep existing nested detail routes on their current push-style navigation path.
4. Add tests for root-tab switching and route/index synchronization.
5. Manually verify behavior on both bottom navigation and wide-layout navigation rail flows.

**Rollback:** Revert the shell configuration and tab route pages to the current `ShellRoute` behavior if branch migration introduces routing regressions.

## Open Questions

None. The desired UX direction is clear: root tab switches should not animate like pushed pages.
