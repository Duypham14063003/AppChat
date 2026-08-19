## image-preview

Image picker integration, preview/edit screen before sending, and full-screen image viewer with zoom.

### Requirements

1. **Image picker trigger**
   - Replace attach button stub in `MessageInputBar` with functional bottom sheet
   - Bottom sheet options: "Gallery" (multi-select from photo library)
   - Use `image_picker` package `pickMultiImage()` for gallery multi-select
   - Max 10 images per selection (show snackbar if exceeded)

2. **Preview screen** (shown after image selection)
   - Full-screen modal route
   - `PageView` for swiping between selected images
   - Bottom thumbnail strip showing all selected images (horizontally scrollable)
   - Active thumbnail highlighted with gold border
   - Remove button (X) on each thumbnail — removes image from selection
   - If all images removed, pop back to chat
   - Single caption `TextField` at bottom (applies to entire album)
   - Send button (gold, bottom-right) — triggers upload + send flow
   - Back button — discard selection and return to chat

3. **Full-screen image viewer** (for viewing sent/received images)
   - Opened by tapping any image in album bubble
   - `photo_view` package for pinch-to-zoom and pan
   - `PageView` for swiping between album images
   - Dark background, image counter "1/5" at top
   - Close button (X) or swipe down to dismiss
   - For albums: start at tapped image index

4. **Upload flow** (triggered from preview screen Send button)
   - Upload all images via `ChatRepository.uploadImages()` (Dio multipart)
   - Show upload progress in preview screen (progress bar or percentage)
   - On success: send WS message with returned URLs → pop preview → show album in chat
   - On failure: show error snackbar, keep preview open for retry
   - If offline: cache images locally, queue for later, pop preview, show optimistic bubble

### Integration Points

- `MessageInputBar` — replace attach button stub with bottom sheet trigger
- `ChatScreen` — navigation to preview screen and full-screen viewer
- `ChatNotifier` — new `sendImageMessage()` / `sendAlbumMessage()` methods
- `ChatRepository` — new `uploadImages()` method using Dio multipart
- `image_picker` package — gallery multi-select
- `photo_view` package — pinch-to-zoom viewer

### Acceptance Criteria

- Tap attach → bottom sheet with Gallery option
- Select 3 images → preview screen shows with swipeable images and thumbnails
- Remove 1 image → thumbnail disappears, 2 images remain
- Type caption → caption preserved through send
- Tap Send → upload progress shown → message appears in chat with images
- Tap image in chat → full-screen viewer with zoom
- Swipe between images in viewer
- Select 11 images → snackbar "Tối đa 10 ảnh" and selection capped at 10
