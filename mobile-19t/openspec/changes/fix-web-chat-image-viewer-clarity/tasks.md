## 1. Web viewer strategy

- [x] 1.1 Audit the current web chat image rendering path and isolate the fullscreen viewer boundary that can diverge from mobile behavior.
- [x] 1.2 Implement a web-specific fullscreen image viewer path that prioritizes sharp rendering for text-heavy screenshots.
- [x] 1.3 Keep native mobile image viewing behavior unchanged unless a shared adjustment is explicitly safe.

## 2. Preview and integration checks

- [x] 2.1 Review whether web thumbnail/album preview rendering needs targeted tuning separate from the fullscreen fix.
- [x] 2.2 Ensure the web clarity fix still works with the current image URL/upload contract and existing chat message metadata.
- [x] 2.3 Verify copy/download/image-open actions still behave correctly after the web viewer change.

## 3. Validation

- [ ] 3.1 Test with text-heavy screenshots on web and confirm readability improves compared with the previous viewer behavior.
- [ ] 3.2 Test regular photo-style images on web and confirm normal viewing is not regressed.
- [x] 3.3 Run relevant Flutter web analysis/regression checks for the chat image viewer and related widgets.
