## Context

The current mobile chat module uses a shared image viewer implementation across platforms. On web, the fullscreen viewer path uses Flutter web image rendering with `NetworkImage` and `PhotoViewGallery`. For text-heavy screenshots, this can produce visibly soft text compared to the original image, especially after scaling and zoom transforms.

The issue appears specific to the web rendering path rather than the upload contract: the mobile client uploads raw bytes and later displays the returned asset URL. The likely problem space is therefore viewer rendering, scaling behavior, and platform-specific widget choice on web.

## Goals / Non-Goals

**Goals:**
- Improve readability of text-heavy chat images on web.
- Ensure fullscreen image viewing on web favors sharp rendering of screenshots and document captures.
- Keep the mobile viewing path stable unless a change is proven safe cross-platform.
- Make the web image viewer behavior predictable for screenshots, tables, and dense text content.

**Non-Goals:**
- Redesign media upload or backend image storage.
- Guarantee OCR-grade perfection for all low-resolution source images.
- Replace all media rendering widgets across the app.
- Change native mobile image viewing unless needed for shared maintenance.

## Decisions

### Use a web-specific image viewing path when fidelity matters

The web image viewer will be allowed to diverge from the mobile path if doing so improves text clarity. This likely means avoiding the exact same `PhotoView`-based rendering path on web when it introduces softness for screenshots.

Why this approach:
- Flutter web rendering tradeoffs are different from mobile.
- Screenshot legibility is a stronger requirement on web desktop usage.
- It avoids forcing a lowest-common-denominator media viewer across all platforms.

Alternative considered:
- Keep one shared viewer for all platforms and only tweak scaling hints. Rejected as the primary strategy because text-heavy screenshots often need a different rendering path, not just cosmetic tuning.

### Favor browser-native or less transform-heavy rendering for web

The design should prefer a web rendering path with fewer quality-degrading transforms for fullscreen images, such as a simpler interactive viewer or a browser-native image element integration if needed.

Why this approach:
- Text clarity often degrades when screenshots are repeatedly resampled by transform-heavy canvas rendering.
- Browser-native image display can preserve screenshot sharpness better for desktop viewing.

Alternative considered:
- Only change `filterQuality` or fit settings. Rejected as a sole solution because it may not address the root cause if the web path is fundamentally too transform-heavy.

### Treat preview clarity and fullscreen clarity separately

The fullscreen viewer is the highest-priority fix because it is the place users expect to read small text. Preview tiles can be improved where reasonable, but they do not need to solve the same fidelity problem as the dedicated viewer.

Why this approach:
- It keeps scope focused on the usability failure.
- It avoids overcomplicating lightweight preview grids.

Alternative considered:
- Require previews to stay fully readable at thumbnail size. Rejected because that is unrealistic for many screenshots.

## Risks / Trade-offs

- **[Web-only code path divergence]** → Mitigation: isolate platform-specific rendering behind a small viewer boundary.
- **[Reduced zoom polish on web]** → Mitigation: prioritize readability over advanced gesture behavior for desktop screenshot viewing.
- **[Source image may still be low quality]** → Mitigation: focus acceptance on not unnecessarily degrading already-readable images.
- **[Browser/platform differences]** → Mitigation: verify behavior on the target browser(s) used by the team before declaring success.

## Migration Plan

1. Introduce a web-appropriate rendering path for fullscreen chat image viewing.
2. Evaluate whether preview rendering also needs targeted web tuning.
3. Validate with text-heavy screenshots that were previously hard to read.
4. Keep native mobile behavior unchanged unless a shared adjustment is clearly safe.

Rollback strategy:
- Revert the web-specific viewer path and fall back to the previous shared viewer if regressions outweigh clarity improvements.

## Open Questions

- Is the expected target browser primarily Chrome-based desktop, or do we need to explicitly support Safari/Firefox fidelity quirks in this change?
