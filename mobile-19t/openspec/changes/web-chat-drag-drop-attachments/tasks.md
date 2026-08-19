## 1. Web Drag-and-Drop Foundation

- [x] 1.1 Add a web-only drag-and-drop integration layer for chat attachments, including any helper widget or browser-specific adapter needed to receive dropped files.
- [x] 1.2 Wrap the web chat composer region with a drop target that can surface idle, active, and rejected drag states.
- [x] 1.3 Add drop overlay copy and visual feedback that clears correctly on drag exit and completed drop.

## 2. Attachment Classification and Routing

- [x] 2.1 Normalize dropped browser files into the attachment format expected by the existing chat callbacks.
- [x] 2.2 Route supported dropped payloads into the existing image, video, and document attachment flows without duplicating upload logic.
- [x] 2.3 Reject unsupported or mixed payloads before preview/upload begins and preserve the current draft state when a drop is rejected.

## 3. Web Preview Compatibility

- [x] 3.1 Introduce a preview-safe normalization path for web attachments that are backed by browser data instead of relying only on `XFile.path`.
- [x] 3.2 Update image preview flow so picker-, paste-, and drag-drop-based web images all preview successfully.
- [x] 3.3 Update video preview flow so picker-, paste-, and drag-drop-based web videos all preview successfully.

## 4. Verification

- [x] 4.1 Add automated tests for drop payload classification, unsupported payload rejection, and draft-state preservation.
- [x] 4.2 Add automated coverage for web preview compatibility across picker, clipboard, and drag-drop attachment sources.
- [ ] 4.3 Run manual web QA for single/multi-image drop, single video drop, supported document drop, mixed payload rejection, and existing clipboard/picker parity.
