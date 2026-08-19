## Context

Image and voice messaging are complete — upload endpoints, media bubbles, offline queue all working. `MessageType.VIDEO` needs to be added. No video packages exist in Flutter. The upload controller currently handles images and audio but not video files.

This change implements CHAT-FR-009 (Video Message, P2 COULD). It follows the Telegram UX pattern: single video selection, preview screen with playback, client-side thumbnail generation, and full-screen playback on tap.

Key constraints: Max 5 minutes duration, max 100MB file size, client-side thumbnail generation, local disk storage (no Bunny.net yet), single video per message (no multi-select).

## Goals / Non-Goals

**Goals:**
- Video picker integration via `image_picker` package (pickVideo method)
- Client-side validation: duration ≤300 seconds, size ≤100MB
- Client-side thumbnail generation via `video_thumbnail` package
- VideoPreviewScreen with video player, metadata display, caption input
- Full-screen VideoPlayerScreen with play/pause/seek controls via `chewie`
- Video bubble with thumbnail, play button overlay, duration badge
- Upload video + thumbnail via new `POST /chat/upload-video` endpoint
- Offline support via existing `PendingUploads` table
- Support common video formats: mp4, mov, avi, mkv, webm

**Non-Goals:**
- Video trimming/editing before send
- Video compression/transcoding
- Multi-video selection (album-style)
- Inline video playback in chat bubble (only full-screen)
- Bunny.net CDN integration (later phase)
- Server-side thumbnail generation (ffmpeg)
- Background video upload
- Video streaming (progressive download)

## Decisions

### D1: Video picker — `image_picker.pickVideo()`
**Choice**: Use `image_picker` package's `pickVideo()` method for video selection.
**Rationale**: Already used for image picking — no new dependency. Supports both gallery and camera video recording. Returns `XFile` with path, consistent with image flow. Works on iOS, Android, and web.

### D2: Thumbnail generation — client-side via `video_thumbnail`
**Choice**: Generate thumbnail on client using `video_thumbnail` package. Extract frame at 1 second (or video midpoint if shorter). Resize to 320x240, JPEG quality 70%.
**Rationale**: Faster UX (user sees thumbnail immediately in preview). No server processing needed (no ffmpeg dependency). Consistent with Telegram/WhatsApp behavior. Thumbnail uploaded alongside video.
**Implementation**: `VideoThumbnail.thumbnailData()` returns `Uint8List`, converted to `MultipartFile` for upload.

### D3: Duration validation — client-side via `video_player`
**Choice**: Use `video_player` package to initialize video and read duration. Validate ≤300 seconds before showing preview screen.
**Rationale**: Prevents wasted bandwidth uploading invalid videos. Immediate feedback to user. Server should still validate as defense-in-depth.
**Implementation**: 
```dart
final controller = VideoPlayerController.file(File(videoPath));
await controller.initialize();
final duration = controller.value.duration.inSeconds;
if (duration > 300) throw Exception('Video too long');
```

### D4: Video player UI — `chewie` package
**Choice**: Use `chewie` package for full-screen video player with built-in controls.
**Rationale**: Wraps `video_player` with standard UI controls (play/pause, seek bar, volume, fullscreen toggle). Saves implementation time. Consistent UX across platforms. Well-maintained package with 1.7k+ pub points.
**Alternative considered**: Custom controls on top of `video_player` — rejected due to complexity (gesture handling, state management, orientation changes).

### D5: Upload strategy — single POST with video + thumbnail
**Choice**: Upload video file and thumbnail bytes in single multipart/form-data POST to `/chat/upload-video`. Use Dio's `onSendProgress` callback for progress bar.
**Rationale**: Simpler than chunked upload. 100MB is manageable for modern mobile networks. Dio handles multipart upload efficiently. Progress callback provides UX feedback. Consistent with image upload pattern.
**Timeout**: Increase Dio timeout to 5 minutes for large files.

### D6: Video formats — accept common formats
**Choice**: Accept MIME types: `video/mp4`, `video/quicktime` (mov), `video/x-msvideo` (avi), `video/x-matroska` (mkv), `video/webm`.
**Rationale**: Covers most mobile recordings (mp4, mov) and common desktop formats. Server validates MIME type. No transcoding — accept as-is.

### D7: Video bubble layout — thumbnail + play button overlay
**Choice**: Custom `VideoThumbnailWidget` with:
- Thumbnail image (background)
- Semi-transparent play button icon (center, 48x48 circle)
- Duration badge (bottom-left corner, dark background)
- Tap → navigate to `VideoPlayerScreen`
**Rationale**: Standard video message UX (Telegram/WhatsApp/Messenger). Clear affordance (play button = video). Duration badge provides context. No auto-play (saves bandwidth, user control).

### D8: Preview screen layout
**Choice**: `VideoPreviewScreen` with:
- Video player (top, aspect ratio preserved)
- Metadata row: filename, size, duration, resolution
- Caption TextField (bottom)
- Send button (top-right)
**Rationale**: User can preview video before sending. Metadata transparency (user knows what they're sending). Caption optional. Consistent with image preview flow.

### D9: Full-screen player behavior
**Choice**: Tap video bubble → navigate to `VideoPlayerScreen` (full-screen). Chewie player with controls. Close button (top-left). Supports landscape/portrait.
**Rationale**: Telegram pattern. Better viewing experience than inline player. Simpler implementation (no inline player state management). User can rotate device for landscape.

### D10: Offline video queue — reuse PendingUploads
**Choice**: Reuse existing `PendingUploads` table. Store video path and thumbnail bytes in `localPaths` JSON. Same retry logic (max 5 retries).
**Rationale**: Infrastructure already exists. No schema changes needed. `OfflineQueueService` already processes pending uploads on reconnect. Video files cached to app cache directory.

### D11: Message metadata structure
**Choice**: Store in `metadata` JSONB column:
```json
{
  "url": "/uploads/chat/videos/xxx.mp4",
  "thumbnail": "/uploads/chat/thumbnails/xxx.jpg",
  "duration": 154,
  "size": 45234567,
  "width": 1920,
  "height": 1080,
  "mimeType": "video/mp4"
}
```
**Rationale**: All data needed for rendering bubble and player. Width/height for aspect ratio. Duration for badge display. Size for debugging. Thumbnail for bubble display.

### D12: Backend endpoint — separate upload-video endpoint
**Choice**: Create new `POST /chat/upload-video` endpoint (separate from image upload).
**Rationale**: Different validation rules (100MB vs 20MB). Different storage paths (videos/ vs chat/). Different MIME types. Clearer separation of concerns. Easier to add video-specific processing later (e.g., duration validation via ffprobe).

## Risks / Trade-offs

- **[Large file uploads on mobile data]** → 100MB max could be expensive on mobile data. Mitigated by: progress indicator (user can cancel), validation before upload (no retry waste). Consider adding "upload on WiFi only" setting in future.
- **[Video format compatibility]** → Some formats may not play on all platforms (e.g., mkv on iOS). Mitigated by: accepting common formats (mp4, mov), server validates MIME type. Future: add transcoding to mp4 if needed.
- **[Thumbnail quality]** → Client-generated thumbnail may not represent video well (e.g., black frame at 1 second). Mitigated by: extracting at 1 second (usually past intro fade). Future: let user scrub to choose thumbnail frame.
- **[Memory usage]** → Loading large video files into memory for validation. Mitigated by: `video_player` streams video, doesn't load entirely. Thumbnail generation uses native APIs (efficient).
- **[Storage space]** → Video files consume significant disk space. Mitigated by: 100MB limit per video, <50 users (low volume). Future: add cleanup job for old videos.

## Open Questions

- None — all decisions made during exploration phase.

