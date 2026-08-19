## Why

The web chat composer already supports clipboard image paste and manual file picking, but it still makes desktop users click through file dialogs for common attachment workflows. Drag and drop is a natural web interaction for chat and will make sending screenshots, documents, and videos feel much closer to the speed of desktop messaging tools.

The current web preview flow also leans on `XFile.path` behaving like a browser-friendly URL, which is fragile for data-backed files such as clipboard pastes or future dropped files. Tightening that compatibility now avoids a second round of attachment fixes after drag and drop lands.

## What Changes

- Add web-only drag-and-drop attachment support around the chat composer so users can drag supported files into the chat area and send them through the existing image, video, and file flows.
- Add drag-state UI feedback for the web composer, including a clear drop target highlight and rejection feedback for unsupported payloads.
- Route dropped files into the existing chat attachment callbacks, preserving current preview, validation, and upload behavior wherever possible.
- Harden web image/video preview compatibility so attachments created from browser data sources remain previewable before upload.

## Capabilities

### New Capabilities
- `web-chat-drag-drop`: Web-only drag-and-drop detection, validation, classification, and composer drop-target feedback for chat attachments.
- `web-chat-attachment-preview-compat`: Preview compatibility rules for data-backed web attachments so image and video previews continue to work across picker, paste, and drag-and-drop sources.

### Modified Capabilities
- None.

## Impact

- Affected mobile-web code will center on `MessageInputBar`, `ChatScreen`, and the web preview flows for image and video attachments.
- No backend API or upload contract changes are required because dropped files will continue through the existing attachment upload endpoints.
- A small web integration layer or additional dependency may be needed for browser drag events, plus new tests around file classification and preview compatibility.
