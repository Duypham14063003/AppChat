## 1. Backend: Upload Endpoint & Static File Serving

- [x] 1.1 Add `ALBUM = 'album'` to `MessageType` enum in `apps/api/src/modules/chat/dto/chat.dto.ts`
- [x] 1.2 Create `uploads/chat/` directory structure. Add `uploads/` to `.gitignore`
- [x] 1.3 Register `ServeStaticModule` in `AppModule` to serve `uploads/` directory at `/uploads/` path
- [x] 1.4 Create `UploadController` at `apps/api/src/modules/chat/upload.controller.ts`:
  - `POST /chat/upload` with `@UseInterceptors(FilesInterceptor('files', 10))` (multer)
  - Validate MIME type (`image/jpeg`, `image/png`, `image/webp`, `image/gif`)
  - Validate file size (max 20MB per file)
  - Save files to `uploads/chat/` with naming `{uuid}-{timestamp}.{ext}`
  - Return `{ files: [{ url, originalName, size, mimeType }] }`
  - Protected by `JwtAuthGuard`
- [x] 1.5 Register `UploadController` in `ChatModule` controllers array
- [ ] 1.6 Verify: upload 1 image → file saved, URL accessible via GET
- [ ] 1.7 Verify: upload 10 images → all succeed
- [ ] 1.8 Verify: upload non-image or >20MB → rejected with appropriate error

## 2. Flutter: Add Packages

- [x] 2.1 Add `image_picker` to `pubspec.yaml`
- [x] 2.2 Add `cached_network_image` to `pubspec.yaml`
- [x] 2.3 Add `photo_view` to `pubspec.yaml`
- [x] 2.4 Run `flutter pub get` to verify all packages resolve

## 3. Flutter: Chat Repository — Upload Method

- [x] 3.1 Add `uploadImages(List<File> files)` method to `ChatRepository`:
  - Create `FormData` with `MultipartFile` entries
  - POST to `/chat/upload`
  - Return list of uploaded file metadata (url, originalName, size, mimeType)
  - Support `onSendProgress` callback for progress tracking

## 4. Flutter: Image Picker & Attach Button

- [x] 4.1 Update `MessageInputBar` — change `onSend` callback signature to also support media:
  - Add `onAttachImages` callback: `void Function(List<XFile> images)`
  - Replace attach button stub with bottom sheet showing "Chọn ảnh" option
  - On "Chọn ảnh" tap → call `ImagePicker().pickMultiImage(limit: 10)`
  - If >10 images selected, show snackbar "Tối đa 10 ảnh" and take first 10
  - Call `onAttachImages` with selected files

## 5. Flutter: Image Preview Screen

- [x] 5.1 Create `ImagePreviewScreen` at `lib/features/chat/screens/image_preview_screen.dart`:
  - Accept `List<XFile>` images and optional initial caption
  - `PageView` for swiping between images (full-screen display)
  - Bottom thumbnail strip (horizontal `ListView`) with active indicator (gold border)
  - Remove button (X icon) on each thumbnail
  - If all removed → pop back
  - Caption `TextField` at bottom
  - Send button (gold) → return `{ images, caption }` result via `Navigator.pop`
- [x] 5.2 Wire preview screen: `MessageInputBar.onAttachImages` → navigate to `ImagePreviewScreen` → on result, trigger send flow in `ChatScreen`

## 6. Flutter: Album Bubble Widget

- [x] 6.1 Create `AlbumGrid` widget at `lib/features/chat/widgets/album_grid.dart`:
  - Accept list of image URLs (or local file paths for optimistic UI)
  - Render mosaic grid based on count:
    - 1: single image, full width, max height 300
    - 2: row of 2, equal width, 2px gap
    - 3: 1 large left (2/3) + 2 stacked right (1/3), 2px gap
    - 4: 2×2 grid, 2px gap
    - 5+: 2×2 grid, "+N" overlay on 4th position
  - Use `cached_network_image` for network URLs, `Image.file` for local paths
  - Clip to rounded corners
  - `onTap(int index)` callback for each image
- [x] 6.2 Update `MessageBubble._buildBubble()` — add type branching:
  - If `message.type == 'image'`: render single image from metadata URL
  - If `message.type == 'album'`: parse metadata JSON, render `AlbumGrid`
  - Keep text rendering for `type == 'text'` (existing)
  - Show caption below image/grid if present in metadata
  - Overlay timestamp + status on image bottom-right (semi-transparent background)
- [x] 6.3 Handle upload progress state in album bubble:
  - If message status is `pending` and metadata contains `localPaths`: show images from local files with circular progress overlay
  - On upload complete: metadata updated with server URLs, rebuild with `cached_network_image`

## 7. Flutter: Full-Screen Image Viewer

- [x] 7.1 Create `ImageViewerScreen` at `lib/features/chat/screens/image_viewer_screen.dart`:
  - Accept list of image URLs and initial index
  - `PageView` with `PhotoView` widget for each image (pinch-to-zoom, pan)
  - Dark background (black)
  - Image counter "1/5" at top center
  - Close button (X) at top-left
  - Swipe between images
- [x] 7.2 Wire viewer: tap image in `AlbumGrid` → navigate to `ImageViewerScreen` with image list and tapped index

## 8. Flutter: Send Image Flow in ChatNotifier

- [x] 8.1 Add `sendImageMessage(String convId, List<XFile> images, String? caption)` to `ChatNotifier`:
  - Generate message UUID
  - Determine type: `'image'` for 1 image, `'album'` for 2+
  - Build metadata with local file paths (for optimistic UI)
  - Insert optimistic message to Drift with `status: 'pending'`
  - Upload images via `ChatRepository.uploadImages()`
  - On success: build metadata with server URLs, send WS `send_message` event, update local message metadata
  - On failure: update message status to `failed`
- [x] 8.2 Wire in `ChatScreen`: receive result from `ImagePreviewScreen` → call `ChatNotifier.sendImageMessage()`

## 9. Flutter: Offline Media Queue

- [x] 9.1 Add `PendingUploads` table to `lib/core/database/tables.dart`:
  - id (text PK), convId (text), localPaths (text — JSON array), caption (text nullable), status (text default 'queued'), retryCount (integer default 0), createdAt (dateTime)
- [x] 9.2 Add `PendingUploads` DAO methods to `ChatDao`:
  - `insertPendingUpload()`, `getPendingUploads()`, `updatePendingUploadStatus()`, `deletePendingUpload()`
- [x] 9.3 Run `dart run build_runner build --delete-conflicting-outputs` to regenerate Drift code
- [x] 9.4 Update `sendImageMessage` in `ChatNotifier` — detect offline state:
  - If offline: copy images to app cache dir, insert `PendingUploads` record, show optimistic bubble with local paths
  - If online: proceed with upload as normal
- [x] 9.5 Extend `OfflineQueueService` to process pending uploads on reconnect:
  - Query `PendingUploads` with status `queued`
  - For each: upload files → send WS message → update local message → delete pending record → delete cached files
  - On failure: increment retryCount, re-queue. After 5 failures → set status `failed`
- [x] 9.6 Add retry support: tap retry on failed image message → reset pending upload, re-queue

## 10. Flutter: Conversation List — Image Preview in Last Message

- [x] 10.1 Update `ConversationTile` — if last message type is `image` or `album`, show "📷 Ảnh" or "📷 N ảnh" instead of text content
- [x] 10.2 Update `ChatListNotifier._refreshFromApi()` to handle image/album message types in last message preview

## 11. Integration & Verification

- [ ] 11.1 Verify: select 3 images → preview screen → send → album appears in chat with mosaic grid
- [ ] 11.2 Verify: tap image in album → full-screen viewer with zoom and swipe
- [ ] 11.3 Verify: send image while offline → optimistic bubble shown → upload on reconnect
- [ ] 11.4 Verify: upload fails 5 times → "Gửi thất bại" with retry button
- [ ] 11.5 Verify: conversation list shows "📷 Ảnh" for image messages
- [ ] 11.6 Verify: recipient receives image message in real-time via WebSocket
- [x] 11.7 Run `npm run lint && npm run build` in apps/api — no errors
- [x] 11.8 Run `flutter analyze` in apps/mobile — no errors
