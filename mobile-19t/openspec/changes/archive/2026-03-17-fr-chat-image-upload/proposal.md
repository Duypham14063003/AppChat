## Why

FR-CHAT Phase 1 is complete — text messaging, WebSocket, offline queue, push notifications all working. The next most requested feature is image sharing (CHAT-FR-006, P0 MUST). Users need to share photos in conversations — screenshots, site photos, documents captured by camera. This is the foundation for all future media types (file, voice, video).

Currently the `MessageType` enum includes `image` and the `metadata` JSONB column exists, but there is no upload endpoint, no media rendering in bubbles, and no image picker integration. The attach button in `MessageInputBar` shows a "Tính năng đang phát triển" stub.

## What Changes

Backend (NestJS):
- Create `MediaModule` with upload endpoint `POST /chat/upload` using multer for multipart file handling
- Save uploaded files to local disk (`uploads/` directory) — Bunny.net CDN integration deferred to later phase
- Serve static files via NestJS `ServeStaticModule` at `/uploads/` path
- Validate: image/* MIME types only, max 20MB per file, max 10 files per request
- Return array of `{ url, originalName, size, mimeType }` for each uploaded file

Frontend (Flutter):
- Add `image_picker`, `cached_network_image`, `photo_view` packages
- Implement image picker flow: bottom sheet (Camera / Gallery) → multi-select → preview screen
- Create preview screen: swipeable images, per-image remove, single caption, send button
- Upload images via Dio multipart POST with per-image progress tracking
- Create album message: type `album` for multi-image, type `image` for single image
- Render album bubble with Telegram-style mosaic grid layout (1-4 images visible, +N overlay for 5+)
- Full-screen image viewer with pinch-to-zoom and swipe between images
- Offline support: cache selected images to app directory, queue upload for when online

## Capabilities

### New Capabilities
- `media-upload`: Backend upload endpoint with multer, local disk storage, static file serving, validation
- `album-bubble`: Chat bubble rendering for single image and multi-image album with mosaic grid layout
- `image-preview`: Image picker integration, preview/edit screen before send, full-screen viewer with zoom
- `offline-media-queue`: Offline image caching, pending upload queue in Drift, retry on reconnect

### Modified Capabilities
- `chat-messaging`: Extend `sendMessage` to handle `image` and `album` message types with metadata
- `flutter-chat-ui`: Update `MessageInputBar` attach button, update `MessageBubble` for image/album rendering

## Impact

- **Database**: No schema changes — existing `type` and `metadata` columns sufficient
- **API endpoints**: 1 new REST endpoint (`POST /chat/upload`), static file serving
- **Packages (API)**: `multer` (file upload handling)
- **Packages (Flutter)**: `image_picker`, `cached_network_image`, `photo_view`
- **Storage**: Local disk `uploads/` directory on server (Bunny.net CDN later)
- **Drift**: New `pending_uploads` table for offline media queue
- **Performance**: Upload progress tracking, optimistic UI with local file display
