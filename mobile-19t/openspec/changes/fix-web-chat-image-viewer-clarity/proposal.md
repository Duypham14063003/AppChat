## Why

The current web chat image experience can render screenshots and text-heavy images with visibly soft or broken-looking text, especially in the fullscreen image viewer. This makes shared documents, tables, and screenshots hard to read on web even when the original uploaded asset is acceptable.

## What Changes

- Improve web-specific rendering for chat images so text-heavy screenshots remain readable in the chat image viewer.
- Define a web image viewing path that prioritizes clarity over mobile-style zoom behavior when necessary.
- Preserve existing mobile image viewing behavior unless a shared fix is clearly safe across platforms.
- Verify that chat image previews and fullscreen viewing use the most appropriate web rendering path for sharpness.

## Capabilities

### New Capabilities
- `web-chat-image-clarity`: Define web-specific requirements for displaying chat images sharply enough to read text content in previews and fullscreen viewing.

### Modified Capabilities
- None.

## Impact

- Affected web behavior in `apps/mobile/lib/features/chat/screens/image_viewer_screen.dart`.
- Likely affected web chat preview rendering in `apps/mobile/lib/features/chat/widgets/album_grid.dart`.
- May affect shared media rendering helpers if a platform-specific abstraction is introduced.
- No backend API or upload contract changes are required in this change.
