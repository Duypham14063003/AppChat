## 1. Install Dependencies

- [x] 1.1 Add `super_clipboard` package to `apps/mobile/pubspec.yaml` via `flutter pub add super_clipboard`
- [x] 1.2 Verify build succeeds on all platforms: `flutter analyze`

## 2. Clipboard Image Reader Utility

- [x] 2.1 Create `ClipboardImageReader` utility at `apps/mobile/lib/core/utils/clipboard_image_reader.dart` with method `Future<XFile?> readImageFromClipboard()` that uses `super_clipboard` to check clipboard for image data (PNG, JPEG, GIF, BMP, WebP formats)
- [x] 2.2 Implement native platform path: read image bytes from clipboard, write to temp file via `path_provider` `getTemporaryDirectory()`, return `XFile` from temp path with filename `clipboard_paste_{timestamp}.png`
- [x] 2.3 Implement web platform path: read image bytes from clipboard, return `XFile.fromData(bytes, name: 'clipboard_paste_{timestamp}.png', mimeType: 'image/png')`
- [x] 2.4 Return `null` if clipboard has no image data (text-only or empty)

## 3. MessageInputBar Paste Interception

- [x] 3.1 In `MessageInputBar._MessageInputBarState`, add method `Future<void> _handlePaste()` that calls `ClipboardImageReader.readImageFromClipboard()`. If result is non-null XFile, call `widget.onAttachImages?.call([xFile])`. If null, perform default text paste via `_controller` (read text from clipboard and insert at cursor position)
- [x] 3.2 Wrap the existing `TextField` in `MessageInputBar._buildNormalUI()` with a `CallbackShortcuts` widget that maps `SingleActivator(LogicalKeyboardKey.keyV, control: true)` (Windows/Linux) and `SingleActivator(LogicalKeyboardKey.keyV, meta: true)` (macOS) to `_handlePaste()`
- [x] 3.3 Ensure the shortcut intercepts BEFORE the TextField's default paste handler — use `Actions` widget with `PasteTextIntent` override if `CallbackShortcuts` doesn't prevent default
- [x] 3.4 Preserve existing text paste: when `_handlePaste()` detects no image in clipboard, manually read text from clipboard via `Clipboard.getData('text/plain')` and insert into `_controller` at current selection

## 4. Integration Testing

- [x] 4.1 Run `flutter analyze` in `apps/mobile` — fix any issues
- [ ] 4.2 Test on Web (Chrome): copy image from browser → Ctrl+V in chat → verify ImagePreviewScreen opens → send → verify image message appears
- [ ] 4.3 Test on Windows: take screenshot (Win+Shift+S) → Ctrl+V in chat → verify flow
- [ ] 4.4 Test on macOS: take screenshot (Cmd+Shift+4) → Cmd+V in chat → verify flow
- [ ] 4.5 Test text paste preserved: copy text → Ctrl+V → verify text pastes normally into TextField
- [ ] 4.6 Test empty clipboard: Ctrl+V with empty clipboard → verify no error, no action

