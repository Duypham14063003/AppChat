## Context

The chat composer already has three web-relevant attachment entry paths: manual file picking, clipboard image paste, and the existing callback chain from `MessageInputBar` into `ChatScreen` and `ChatNotifier`. Upload itself is not the missing piece; the missing piece is a browser drag surface that can convert dropped files into the same image, video, and document flows users already exercise through picker-based attachments.

There is also a compatibility wrinkle in current web previews. Some preview code assumes `XFile.path` is directly usable as a browser URL, while clipboard and future drag-and-drop attachments can be backed by in-memory data instead. If drag and drop is added without stabilizing that preview assumption, users may be able to drop a file but fail during preview.

## Goals / Non-Goals

**Goals:**
- Add web-only drag-and-drop attachment support to the chat composer area.
- Reuse existing attachment callbacks and upload flows instead of creating a parallel upload pipeline.
- Provide clear drag-state feedback so users know when files are accepted, rejected, or ready to drop.
- Support the same preview/send behavior for dropped files as for picker- and paste-based files.
- Keep unsupported or mixed payloads from silently entering inconsistent states.

**Non-Goals:**
- Changing backend upload endpoints or chat message payload formats.
- Adding drag-and-drop attachment support to mobile platforms.
- Expanding supported file types beyond the current image, video, and validated document set.
- Redesigning the entire web chat composer layout beyond the drop-target affordance.

## Decisions

### D1: Attach drag-and-drop at the composer layer, not the full page
**Choice:** Add the drop surface around the web chat composer region and optionally its immediate bottom chat area, rather than making the entire conversation page a drop target.
**Rationale:** Users naturally associate file sending with the composer. Keeping the drop target localized reduces accidental drops while still giving enough hit area for desktop use. It also keeps drag-state UI coupled to the existing attachment controls.
**Alternative considered:** Whole-screen drop targeting. Rejected because it increases accidental activation and makes feedback feel less precise.

### D2: Reuse `onAttachImages`, `onAttachVideo`, and `onAttachFile`
**Choice:** Normalize dropped browser files into `XFile` instances and route them into the same callbacks already used by picker-based attachments.
**Rationale:** This preserves the current image preview, video preview, direct file send, reply-state handling, and upload pipeline. It also limits regression risk because drag and drop becomes a new entry point, not a new attachment subsystem.
**Alternative considered:** Sending dropped files directly from the drag handler. Rejected because it would duplicate preview and validation logic.

### D3: Treat mixed dropped payloads as rejectable input
**Choice:** Accept one logical payload class per drop: multiple images, one video, or one document. Reject mixed sets such as image plus PDF or multiple dissimilar non-image files.
**Rationale:** The current composer flows already diverge by attachment type. Enforcing a single class per drop keeps behavior predictable and avoids inventing a new mixed-preview UX inside this change.
**Alternative considered:** Best-effort splitting and partial acceptance. Rejected because it would surprise users and complicate feedback.

### D4: Add a web attachment normalization layer for preview compatibility
**Choice:** Introduce a small abstraction or helper that can provide a preview-safe source for web attachments regardless of whether the underlying `XFile` came from picker bytes, clipboard bytes, or drag-and-drop bytes.
**Rationale:** Browser drag events commonly yield byte-backed file objects. A normalization step lets image and video preview screens consume a stable source instead of relying on `XFile.path` always being a direct URL. This also hardens existing clipboard behavior.
**Alternative considered:** Requiring drag-and-drop sources to synthesize URL-like `path` values only. Rejected because it leaves preview assumptions scattered and fragile.

### D5: Keep drag-and-drop web-only behind `kIsWeb`
**Choice:** Gate drag state, browser event handling, and any optional dependency usage behind web platform checks.
**Rationale:** Drag-and-drop browser semantics do not map cleanly to mobile or native desktop in the current scope. Web-only gating avoids platform condition complexity in the rest of the composer.
**Alternative considered:** Using a cross-platform drag package everywhere. Rejected because the requested feature is specifically for the web chat UI and broader platform support would add scope without clear value now.

## Risks / Trade-offs

- `[Browser drag events may require a new dependency or custom web bridge]` → Keep the integration thin and isolate browser-specific code behind helper widgets or conditional imports.
- `[Preview compatibility changes could affect existing clipboard or picker flows]` → Reuse the same normalization path for all web attachment sources and add targeted tests for picker, paste, and drag-drop parity.
- `[Localized drop targets may feel too small on wide desktop layouts]` → Use a visually clear overlay with a comfortably large composer-adjacent hit area instead of a tiny inner control target.
- `[Rejected mixed payloads may frustrate users]` → Provide explicit rejection copy that explains what was dropped and what the composer accepts in one action.

## Migration Plan

No backend or database migration is required. Rollout is client-only and can be guarded to web platforms from the first implementation.

Rollback is straightforward: remove the drag-drop layer and retain the existing picker and clipboard attachment flows unchanged.

## Open Questions

- None required before implementation; the remaining choices are operational details inside the approved scope.
