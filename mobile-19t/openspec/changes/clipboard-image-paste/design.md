## Context

The chat feature has a complete image send pipeline: `MessageInputBar` → `onAttachImages(List<XFile>)` → `ImagePreviewScreen` (caption input, confirm) → `ChatNotifier.sendImageMessage()` → `ChatRepository.uploadImages()` → WS `send_message`. Images are picked via `ImagePicker.pickMultiImage()` triggered from an attach bottom sheet. The `MessageInputBar` TextField uses a `TextEditingController` with `onChanged` handler for typing detection and link preview.

Currently there is no clipboard image detection. The TextField's default paste behavior only handles text. On desktop/web, users commonly paste screenshots or copied images — this is a standard feature in Telegram, Slack, and Discord.

## Goals / Non-Goals

**Goals:**
- Detect image data in clipboard on Ctrl+V / Cmd+V in MessageInputBar
- Convert clipboard image to XFile and feed into existing image send flow
- Support Web, Windows, macOS (primary), Android/iOS (secondary)
- Preserve normal text paste behavior when clipboard has no image

**Non-Goals:**
- Paste multiple images at once (single image per paste, user can paste again)
- Paste files (PDF, DOC, etc.) — only image formats (PNG, JPEG, GIF, BMP, WebP)
- Drag-and-drop images (separate feature)
- Inline image preview in the text field (use existing ImagePreviewScreen)

## Decisions

### D1: `super_clipboard` package

**Decision**: Use `super_clipboard` for cross-platform clipboard reading.

**Why**: Single API for all platforms (Web, Windows, macOS, Android, iOS, Linux). Handles the complexity of platform-specific clipboard formats (NSPasteboard, Win32 clipboard, ClipboardEvent, UIPasteboard). Actively maintained, 500+ pub points.

**Alternative**: `pasteboard` (desktop only) + manual JS interop for web. Rejected — fragmented code, more maintenance.

**Alternative**: Flutter's built-in `Clipboard.getData()` — only supports text, not images.

### D2: Intercept paste via `Actions` + `Shortcuts` widget

**Decision**: Wrap the TextField with Flutter's `Actions`/`Shortcuts` system to intercept Ctrl+V/Cmd+V before the default text paste handler. Check clipboard for image → if found, consume the event and trigger image flow. If no image, let the default paste proceed.

**Why**: Clean integration with Flutter's input system. No platform-specific keyboard listeners needed. Works on all platforms. The `CallbackShortcuts` or `Actions` widget can intercept the paste intent before `TextField` processes it.

**Alternative**: `RawKeyboardListener` wrapping TextField. Rejected — deprecated in favor of `KeyboardListener`, and doesn't cleanly intercept the paste action before TextField consumes it.

### D3: Clipboard image → XFile conversion

**Decision**: Read image bytes from clipboard via `super_clipboard`, write to a temporary file (using `path_provider` temp directory), create `XFile` from the temp path. On web, use `XFile.fromData()` with the bytes directly.

**Why**: The existing `onAttachImages` callback expects `List<XFile>`. `XFile` can be created from bytes (web) or file path (native). Temp file is cleaned up after upload completes.

## Risks / Trade-offs

- **[Risk] `super_clipboard` adds native dependency** → Increases build size slightly. Acceptable for the UX improvement. Package is well-maintained.

- **[Risk] Clipboard may contain both text and image** → Some apps put both text (URL) and image (thumbnail) on clipboard when copying. Decision: prioritize image if present. User can still paste text by selecting "Paste as text" or clearing clipboard image first. This matches Telegram/Discord behavior.

- **[Trade-off] Single image per paste** → Clipboard typically holds one image. Multiple paste = multiple images. User can also use attach button for multi-select. Acceptable limitation.

- **[Trade-off] Mobile paste less common** → On Android/iOS, users rarely paste images into chat (they use share sheet or gallery picker). But `super_clipboard` supports it, so it works if they do.

