## Context

FR-CHAT Phase 1 is complete — text messaging, WebSocket, offline queue, push notifications all working. The `MessageType` enum already includes `IMAGE` and the `metadata` JSONB column exists on the messages table. The attach button in `MessageInputBar` is a stub showing "Tính năng đang phát triển". No upload endpoint, no media rendering, no image picker packages exist yet.

This change implements CHAT-FR-006 (Send Image, P0 MUST) — the first media type. It establishes the upload infrastructure that future media types (file, voice, video) will reuse.

Key constraint: Upload to backend local disk first. Bunny.net CDN integration is deferred to a later phase.

## Goals / Non-Goals

**Goals:**
- Multi-image upload (1-10 images per send) with Telegram-style album UX
- Backend upload endpoint with multer, local disk storage, static file serving
- Album message model: single message with metadata containing array of image objects
- Mosaic grid layout in chat bubble for album display
- Preview screen before sending: swipe, remove, caption
- Full-screen image viewer with pinch-to-zoom
- Upload progress tracking per image
- Offline support: cache images locally, queue upload for when online
- Optimistic UI: show local images immediately in chat

**Non-Goals:**
- Bunny.net CDN integration (later phase — swap storage adapter)
- Image compression/resize on client (keep original, optimize later)
- Server-side thumbnail generation with sharp (later with Bunny.net)
- Image editing (crop, rotate, filters)
- GIF support
- Camera capture (only gallery picker for now — camera can be added trivially later)

## Decisions

### D1: Upload architecture — client → API → local disk
**Choice**: Flutter uploads images via `POST /chat/upload` (multipart/form-data) to NestJS. Server saves to `uploads/chat/` directory on local disk. Files served via `ServeStaticModule` at `/uploads/` path.
**Rationale**: Simplest approach for Phase 1. Bunny.net doesn't support presigned URLs like S3, so direct-to-CDN upload would require exposing API keys to client. Local disk is sufficient for <50 users. Storage adapter can be swapped later without changing client code.
**File naming**: `{uuid}-{timestamp}.{ext}` to prevent collisions and enable easy cleanup.

### D2: Message model — album message type
**Choice**: Add `ALBUM = 'album'` to `MessageType` enum. Single image sends use `type: 'image'` with metadata `{ url, width, height, size, mimeType }`. Multi-image sends use `type: 'album'` with metadata `{ images: [{ url, width, height, size, mimeType }], caption? }`.
**Rationale**: Telegram-style album model. One message = one album. Cleaner than N separate messages with a group_id. Easy to reply/forward/delete as a unit. Single image uses `type: 'image'` for backward compatibility with existing enum.
**Alternative rejected**: Separate messages with `group_id` — noisy in DB, complex delete/forward logic, requires grouping logic in UI.

### D3: Upload endpoint — batch upload, return URLs
**Choice**: `POST /chat/upload` accepts up to 10 files in a single multipart request. Returns array of `{ url, originalName, size, width, height, mimeType }`. Client then sends WS `send_message` with the returned URLs in metadata.
**Rationale**: Two-step flow (upload files → send message) is cleaner than embedding files in WS messages. Allows upload progress tracking via HTTP. WS message stays lightweight (just URLs). If upload fails, no orphan message in DB.
**Validation**: Accept `image/jpeg`, `image/png`, `image/webp`, `image/gif` only. Max 20MB per file. Max 10 files per request.

### D4: Flutter image picker — `image_picker` package
**Choice**: Use `image_picker` for gallery multi-select. Add `cached_network_image` for efficient image loading with caching. Add `photo_view` for full-screen pinch-to-zoom viewer.
**Rationale**: `image_picker` is the official Flutter plugin, supports multi-select on iOS/Android, works on web. `cached_network_image` handles disk caching and placeholder/error states. `photo_view` provides pinch-to-zoom with minimal code.

### D5: Album bubble layout — Telegram-style mosaic grid
**Choice**: Fixed grid patterns based on image count:
- 1 image: full width, aspect ratio preserved (max height 300)
- 2 images: side by side, equal width
- 3 images: 1 large left + 2 stacked right
- 4 images: 2×2 grid
- 5+ images: show first 4 in grid, "+N" overlay on 4th position
**Rationale**: Telegram's mosaic is the gold standard. Fixed patterns are simpler to implement than dynamic aspect-ratio-based layouts. Covers 95% of use cases elegantly.

### D6: Upload progress — per-image Dio progress callback
**Choice**: Upload via Dio `MultipartFile` with `onSendProgress` callback. Track progress per file. Show circular progress overlay on each image thumbnail in the chat bubble during upload.
**Rationale**: Dio already in the project, supports multipart upload with progress natively. Per-image progress gives better UX than overall progress bar.

### D7: Offline media queue — cache files + Drift pending_uploads table
**Choice**: When user sends images while offline: (1) copy selected images to app cache directory, (2) insert record in new `PendingUploads` Drift table with local paths, conv_id, caption, status. (3) Show images from local cache in chat bubble (optimistic UI). (4) When online, upload cached files → send WS message → delete cached files.
**Rationale**: Must copy to app cache because user might delete original from gallery before reconnecting. Drift table provides persistence across app restarts. Same retry logic as text offline queue (max 5 retries, then "failed" status).

### D8: Preview screen — simple swipeable gallery with remove and caption
**Choice**: After image selection, show full-screen preview with PageView (swipeable). Bottom strip shows thumbnails. Each image has a remove (X) button. Single caption field applies to the album. Send button in bottom-right.
**Rationale**: Simpler than WhatsApp (per-image captions) but sufficient for internal app. Single caption reduces UI complexity. Can add per-image captions later if needed.

## Risks / Trade-offs

- **[Local disk storage]** → Files stored on server disk. If server disk fills up, uploads fail. Mitigation: monitor disk usage, migrate to Bunny.net CDN in next phase.
- **[No thumbnails]** → Full-size images loaded in chat bubbles. On slow connections, bubbles may load slowly. Mitigation: `cached_network_image` handles caching after first load. Thumbnail generation can be added with Bunny.net phase.
- **[Large uploads on mobile data]** → No compression means original file sizes (could be 5-15MB per photo). Mitigation: acceptable for internal app with <50 users. Compression can be added later as optimization.
- **[Orphan files]** → If upload succeeds but WS message fails, files exist on disk without a message reference. Mitigation: add cleanup cron job later. Low priority for <50 users.

## Open Questions

- None — all decisions made during exploration phase.
