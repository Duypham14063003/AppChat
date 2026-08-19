## Why

Image messaging (CHAT-FR-006) and voice messaging (CHAT-FR-008) are complete. The next media type is video messaging (CHAT-FR-009, P2 COULD). Users need to send video clips in conversations — useful for sharing screen recordings, product demos, or quick video updates that are more expressive than images or voice alone.

The upload infrastructure (`POST /chat/upload`, `PendingUploads` table, `OfflineQueueService`) already exists from the image upload change. `MessageType.VIDEO` can be added to the API enum. No video handling packages exist in the Flutter app yet.

## What Changes

Frontend (Flutter):
- Add `video_player` package for video playback and duration extraction
- Add `video_thumbnail` package for client-side thumbnail generation
- Add `chewie` package for full-screen video player with controls
- Extend `MessageInputBar` attach menu to include video picker option
- Create `VideoPreviewScreen` — shows video player, duration, file size, caption input, send button
- Create `VideoPlayerScreen` — full-screen video player with play/pause/seek controls
- Create `VideoThumbnailWidget` — displays thumbnail with play button overlay and duration badge
- Send video message flow: pick → validate (≤300s, ≤100MB) → generate thumbnail → preview → upload video+thumbnail → WS send with type "video" and metadata `{url, thumbnail, duration, size, width, height, mimeType}`
- Update `MessageBubble` to render video type with thumbnail, play button, duration badge
- Offline support: reuse existing `PendingUploads` table and `OfflineQueueService`

Backend (NestJS):
- Create new `POST /chat/upload-video` endpoint accepting video file + thumbnail
- Accept video MIME types: `video/mp4`, `video/quicktime`, `video/x-msvideo`, `video/x-matroska`, `video/webm`
- Max file size: 100MB
- Save video to `/uploads/chat/videos/` and thumbnail to `/uploads/chat/thumbnails/`
- Return both URLs in response

## Capabilities

### New Capabilities
- `video-picking`: Video picker integration, client-side validation (duration ≤300s, size ≤100MB)
- `video-preview`: VideoPreviewScreen with player, metadata display, caption input
- `video-thumbnail`: Client-side thumbnail generation using `video_thumbnail` package
- `video-playback`: Full-screen VideoPlayerScreen with controls via `chewie` package
- `video-upload`: New upload-video endpoint, video+thumbnail upload, offline queue support

### Modified Capabilities
- `chat-messaging`: Extend `sendMessage` to handle `video` message type with metadata
- `flutter-chat-ui`: Update `MessageInputBar` with video option, update `MessageBubble` for video rendering

## Impact

- **Database**: No schema changes — existing `type` and `metadata` columns sufficient. `PendingUploads` table reused as-is.
- **API endpoints**: New `POST /chat/upload-video` endpoint for video+thumbnail upload
- **Packages (Flutter)**: `video_player` (playback + duration), `video_thumbnail` (thumbnail generation), `chewie` (player UI)
- **Packages (API)**: None (Multer already handles file uploads)
- **Storage**: Video files stored in `uploads/chat/videos/`, thumbnails in `uploads/chat/thumbnails/`
- **Performance**: Thumbnail generated client-side — no server processing needed. Large files (up to 100MB) require progress indicator during upload.

