## Why

Users on desktop (Windows/macOS) and web frequently copy images (screenshots, images from browser, etc.) and expect to paste them directly into the chat input with Ctrl+V / Cmd+V — the same UX as Telegram, Slack, and Discord. Currently the only way to send images is via the attach button → ImagePicker file dialog. Adding clipboard paste removes friction for the most common desktop image-sharing workflow.

## What Changes

Frontend (Flutter — MessageInputBar only):
- Add `super_clipboard` package for cross-platform clipboard image reading
- Intercept paste events (Ctrl+V / Cmd+V) in `MessageInputBar`'s TextField
- When clipboard contains image data: read image bytes, convert to `XFile`, pass to existing `onAttachImages` callback → ImagePreviewScreen → sendImageMessage flow
- When clipboard contains only text: paste text normally (default behavior)
- Support all platforms: Web (ClipboardEvent), Windows (Win32 clipboard), macOS (NSPasteboard), Android/iOS (UIPasteboard — less common but supported)

No backend changes — reuses existing image upload flow entirely.

## Capabilities

### New Capabilities
- `clipboard-image-paste`: Detect and handle image paste from clipboard in MessageInputBar — intercept Ctrl+V/Cmd+V, read clipboard image, convert to XFile, feed into existing image send flow

### Modified Capabilities
<!-- No existing spec-level requirements are changing. The image send flow (sendImageMessage, uploadImages, ImagePreviewScreen) is reused as-is. -->

## Impact

- **Flutter packages**: New dependency: `super_clipboard` (cross-platform clipboard read/write)
- **Flutter UI**: Modified: `MessageInputBar` widget — add paste event interception. No other UI changes.
- **Existing flow**: Reuses `onAttachImages` → `ImagePreviewScreen` → `sendImageMessage` → `uploadImages` → WS send. Zero changes to this pipeline.
- **Backend**: No changes.
- **Database**: No changes.

