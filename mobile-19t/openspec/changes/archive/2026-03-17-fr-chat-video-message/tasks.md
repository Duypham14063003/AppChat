# Implementation Tasks

## Phase 1: Dependencies & Setup

### Task 1.1: Add Flutter dependencies
- [x] Add `video_player: ^2.8.0` to `apps/mobile/pubspec.yaml`
- [x] Add `video_thumbnail: ^0.5.3` to `apps/mobile/pubspec.yaml`
- [x] Add `chewie: ^1.7.0` to `apps/mobile/pubspec.yaml`
- [x] Run `flutter pub get`

### Task 1.2: Create backend upload directories
- [x] Update `apps/api/src/modules/chat/upload.controller.ts` to create `/uploads/chat/videos/` directory
- [x] Update `apps/api/src/modules/chat/upload.controller.ts` to create `/uploads/chat/thumbnails/` directory

## Phase 2: Backend Implementation

### Task 2.1: Create upload-video endpoint
- [x] Add `POST /chat/upload-video` endpoint in `apps/api/src/modules/chat/upload.controller.ts`
- [x] Accept `video` and `thumbnail` files using `FileFieldsInterceptor`
- [x] Validate video MIME types: mp4, mov, avi, mkv, webm
- [x] Validate video file size ≤100MB
- [x] Save video to `/uploads/chat/videos/` with UUID filename
- [x] Save thumbnail to `/uploads/chat/thumbnails/` with UUID filename
- [x] Return JSON with video and thumbnail URLs

### Task 2.2: Update message entity (verify)
- [x] Verify `messages.type` column supports "video" value
- [x] Verify `messages.metadata` JSONB column can store video metadata

## Phase 3: Flutter - Video Picking

### Task 3.1: Update MessageInputBar
- [x] Update `_showAttachSheet()` in `apps/mobile/lib/features/chat/widgets/message_input_bar.dart`
- [x] Add "Video" option to bottom sheet
- [x] Add `_pickVideo()` method using `ImagePicker.pickVideo()`
- [x] Add video duration validation (≤300s) using `VideoPlayerController`
- [x] Add video size validation (≤100MB)
- [x] Show error snackbar for validation failures
- [x] Add `onAttachVideo` callback parameter to `MessageInputBar`

### Task 3.2: Update ChatScreen
- [x] Add `_onAttachVideo()` method in `apps/mobile/lib/features/chat/screens/chat_screen.dart`
- [x] Navigate to `VideoPreviewScreen` with selected video
- [x] Pass `onAttachVideo` callback to `MessageInputBar`

## Phase 4: Flutter - Video Preview

### Task 4.1: Create VideoPreviewScreen
- [x] Create `apps/mobile/lib/features/chat/screens/video_preview_screen.dart`
- [x] Initialize `VideoPlayerController` with video file
- [x] Display video player with play/pause controls
- [x] Display metadata: filename, duration, size, resolution
- [x] Add caption TextField
- [x] Add Send button in AppBar
- [x] Return `VideoPreviewResult` with video and caption on send

### Task 4.2: Format metadata helpers
- [x] Add `_formatDuration()` helper (e.g., "2:34")
- [x] Add `_formatSize()` helper (e.g., "45.2 MB")
- [x] Add `_formatResolution()` helper (e.g., "1920x1080")

## Phase 5: Flutter - Thumbnail Generation

### Task 5.1: Add thumbnail generation method
- [x] Add `generateVideoThumbnail()` method in `apps/mobile/lib/features/chat/data/chat_repository.dart`
- [x] Use `VideoThumbnail.thumbnailData()` to extract frame at 1 second
- [x] Resize to max width 320px, JPEG quality 70%
- [x] Return `Uint8List` or null on failure
- [x] Handle errors gracefully

## Phase 6: Flutter - Video Upload

### Task 6.1: Add uploadVideo method
- [x] Add `uploadVideo()` method in `apps/mobile/lib/features/chat/data/chat_repository.dart`
- [x] Create `FormData` with video file and thumbnail bytes
- [x] POST to `/chat/upload-video` with progress callback
- [x] Set timeout to 5 minutes
- [x] Return video and thumbnail URLs from response

### Task 6.2: Add sendVideoMessage method
- [x] Add `sendVideoMessage()` method in `apps/mobile/lib/features/chat/providers/chat_providers.dart`
- [x] Extract video metadata (duration, size, width, height)
- [x] Generate thumbnail using `generateVideoThumbnail()`
- [x] Create optimistic message with status "pending"
- [x] Check if online/offline
- [x] If online: upload video + thumbnail, send WebSocket message, update status
- [x] If offline: queue in `PendingUploads` table
- [x] Handle upload errors and update status to "failed"

### Task 6.3: Update offline queue service
- [x] Verify `apps/mobile/lib/features/chat/data/offline_queue_service.dart` handles video uploads
- [x] Ensure video files are processed from `PendingUploads` table on reconnect

## Phase 7: Flutter - Video Playback

### Task 7.1: Create VideoThumbnailWidget
- [x] Create `apps/mobile/lib/features/chat/widgets/video_thumbnail_widget.dart`
- [x] Display thumbnail image from URL
- [x] Add semi-transparent play button overlay (center)
- [x] Add duration badge (bottom-left corner)
- [x] Add `onTap` callback

### Task 7.2: Create VideoPlayerScreen
- [x] Create `apps/mobile/lib/features/chat/screens/video_player_screen.dart`
- [x] Initialize `VideoPlayerController` with network URL
- [x] Initialize `ChewieController` with controls
- [x] Display full-screen video player
- [x] Add close button in AppBar
- [x] Handle loading and error states
- [x] Dispose controllers properly

### Task 7.3: Update MessageBubble
- [x] Update `apps/mobile/lib/features/chat/widgets/message_bubble.dart`
- [x] Add case for `message.type == 'video'`
- [x] Render `VideoThumbnailWidget` with thumbnail, duration, and tap handler
- [x] Navigate to `VideoPlayerScreen` on tap

## Phase 8: Testing

### Task 8.1: Backend tests
- [ ] Test upload-video endpoint with valid video → returns URLs (manual)
- [ ] Test upload-video endpoint with invalid MIME type → returns 400 (manual)
- [ ] Test upload-video endpoint with file >100MB → returns 413 (manual)
- [ ] Test upload-video endpoint without video file → returns 400 (manual)

### Task 8.2: Flutter unit tests
- [ ] Test video duration validation (manual)
- [ ] Test video size validation (manual)
- [ ] Test thumbnail generation (manual)
- [ ] Test uploadVideo() method (manual)
- [ ] Test sendVideoMessage() method (manual)

### Task 8.3: Flutter widget tests
- [ ] Test VideoPreviewScreen renders and accepts input (manual)
- [ ] Test VideoThumbnailWidget renders thumbnail, play button, duration (manual)
- [ ] Test VideoPlayerScreen renders player and controls (manual)

### Task 8.4: Integration tests
- [ ] Test full flow: pick → preview → send → upload → display (manual)
- [ ] Test offline queue: send offline → reconnect → upload (manual)
- [ ] Test video playback: tap bubble → player opens → video plays (manual)

## Phase 9: Documentation

### Task 9.1: Update CLAUDE.md
- [ ] Document video message feature in `CLAUDE.md` (manual)
- [ ] Add video upload endpoint to API commands (manual)
- [ ] Add video packages to mobile dependencies (manual)

### Task 9.2: Update README (if needed)
- [ ] Document video message feature in project README (manual)

## Estimated Effort

- Phase 1: 0.5 hours
- Phase 2: 2 hours
- Phase 3: 2 hours
- Phase 4: 3 hours
- Phase 5: 1 hour
- Phase 6: 4 hours
- Phase 7: 4 hours
- Phase 8: 4 hours
- Phase 9: 0.5 hours

**Total: ~21 hours**

## Dependencies

- Phase 2 depends on Phase 1
- Phase 3 depends on Phase 1
- Phase 4 depends on Phase 3
- Phase 5 depends on Phase 1
- Phase 6 depends on Phase 2, 4, 5
- Phase 7 depends on Phase 1, 6
- Phase 8 depends on all previous phases
- Phase 9 depends on Phase 8

