## 1. Router Shell Update

- [x] 1.1 Refactor the root tab router structure so Chat, HR, Tasks, and Profile behave as persistent shell branches rather than ordinary sliding page transitions
- [x] 1.2 Ensure bottom-navigation and wide-layout destination selection switches root tabs without horizontal push-style animation
- [x] 1.3 Preserve existing nested detail-screen push navigation behavior for chat, HR, task, and profile subflows

## 2. Verification

- [x] 2.1 Add mobile router or widget tests for route-to-tab selection sync and non-sliding root-tab switching behavior
- [ ] 2.2 Manually verify that bottom tab taps no longer animate from left to right and that nested detail pages still navigate normally
