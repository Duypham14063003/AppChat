# Video Upload

## Overview

Handles uploading video files and thumbnails to the backend server, sending video messages via WebSocket, and managing offline queue for videos. Extends existing upload infrastructure to support video media type.

## Requirements

### Functional

- **VU-001**: System uploads video file and thumbnail to backend via POST request
- **VU-002**: Upload shows progress indicator (0-100%)
- **VU-003**: Backend creates new `/chat/upload-video` endpoint accepting video + thumbnail
- **VU-004**: Backend validates video MIME type (mp4, mov, avi, mkv, webm)
- **VU-005**: Backend validates video file size ≤100MB
- **VU-006**: Backend saves video to `/uploads/chat/videos/` directory
- **VU-007**: Backend saves thumbnail to `/uploads/chat/thumbnails/` directory
- **VU-008**: Backend returns JSON with video URL and thumbnail URL
- **VU-009**: After upload, system sends WebSocket message with type "video" and metadata
- **VU-010**: If offline, system queues video in `PendingUploads` table
- **VU-011**: When reconnected, system processes pending video uploads

### Non-Functional

- **VU-NFR-001**: Upload progress updates at least every 500ms
- **VU-NFR-002**: Upload timeout set to 5 minutes for large files
- **VU-NFR-003**: Failed uploads retry up to 5 times with exponential backoff
- **VU-NFR-004**: Uploaded videos are accessible via HTTP GET

## User Flow

```
User taps Send in VideoPreviewScreen
    ↓
System creates optimistic message bubble (status: pending)
    ↓
[Online] → Upload video + thumbnail
    ↓
    Show progress bar (0-100%)
    ↓
    [Success] → Send WebSocket message
        ↓
        Update message status: sent
    ↓
    [Failure] → Show error, retry or queue
    ↓
[Offline] → Queue in PendingUploads table
    ↓
    Show "Đang chờ kết nối..." status
    ↓
    When reconnected → Process queue
```

## Technical Details

### Flutter Implementation

**Location**: `apps/mobile/lib/features/chat/data/chat_repository.dart`

**Method**:
```dart
Future<Map<String, dynamic>> uploadVideo(
  XFile video,
  Uint8List? thumbnailBytes, {
  void Function(int sent, int total)? onSendProgress,
}) async {
  final formData = FormData();
  
  // Add video file
  final videoBytes = await video.readAsBytes();
  final videoMimeType = video.mimeType ?? _guessVideoMimeType(video.name);
  formData.files.add(MapEntry(
    'video',
    MultipartFile.fromBytes(
      videoBytes,
      filename: video.name,
      contentType: MediaType.parse(videoMimeType),
    ),
  ));
  
  // Add thumbnail if available
  if (thumbnailBytes != null) {
    formData.files.add(MapEntry(
      'thumbnail',
      MultipartFile.fromBytes(
        thumbnailBytes,
        filename: 'thumbnail.jpg',
        contentType: MediaType.parse('image/jpeg'),
      ),
    ));
  }
  
  final res = await _dio.post(
    '/chat/upload-video',
    data: formData,
    onSendProgress: onSendProgress,
    options: Options(
      sendTimeout: Duration(minutes: 5),
      receiveTimeout: Duration(minutes: 5),
    ),
  );
  
  return res.data as Map<String, dynamic>;
}

static String _guessVideoMimeType(String filename) {
  final ext = filename.split('.').last.toLowerCase();
  return switch (ext) {
    'mp4' => 'video/mp4',
    'mov' => 'video/quicktime',
    'avi' => 'video/x-msvideo',
    'mkv' => 'video/x-matroska',
    'webm' => 'video/webm',
    _ => 'video/mp4',
  };
}
```

**Location**: `apps/mobile/lib/features/chat/providers/chat_providers.dart`

**Method**:
```dart
Future<void> sendVideoMessage(XFile video, String? caption) async {
  final dao = ref.read(chatDaoProvider);
  final wsManager = ref.read(webSocketManagerProvider);
  final repo = ref.read(chatRepositoryProvider);
  final authState = ref.read(authNotifierProvider);
  final userId = authState.valueOrNull?.user?.id ?? '';
  
  final id = _uuid.v4();
  final now = DateTime.now();
  
  // Get video metadata
  final file = File(video.path);
  final size = await file.length();
  final controller = VideoPlayerController.file(file);
  await controller.initialize();
  final duration = controller.value.duration.inSeconds;
  final width = controller.value.size.width.toInt();
  final height = controller.value.size.height.toInt();
  await controller.dispose();
  
  // Generate thumbnail
  final thumbnailBytes = await repo.generateVideoThumbnail(video.path);
  
  // Build optimistic metadata with local path
  final optimisticMeta = jsonEncode({
    'url': video.path,
    'thumbnail': null,
    'duration': duration,
    'size': size,
    'width': width,
    'height': height,
  });
  
  // Insert optimistic message
  try {
    await dao.insertMessage(LocalMessagesCompanion.insert(
      id: id,
      convId: arg,
      senderId: userId,
      createdAt: now,
      type: Value('video'),
      content: Value(caption),
      metadata: Value(optimisticMeta),
      status: const Value('pending'),
    ));
    state = AsyncData(await dao.getMessages(arg));
  } catch (e) {
    debugPrint('[Chat] Failed to insert optimistic video message: $e');
  }
  ref.invalidate(chatListProvider);
  
  // Check if online
  final isOnline = wsManager.state == WsConnectionState.connected;
  
  if (!isOnline) {
    // Offline: queue upload
    try {
      await dao.insertPendingUpload(PendingUploadsCompanion.insert(
        id: id,
        convId: arg,
        localPaths: jsonEncode([video.path]),
        caption: Value(caption),
        createdAt: now,
      ));
    } catch (e) {
      debugPrint('[Chat] Failed to queue pending video upload: $e');
    }
    return;
  }
  
  // Upload video + thumbnail
  try {
    final uploaded = await repo.uploadVideo(
      video,
      thumbnailBytes,
      onSendProgress: (sent, total) {
        // Update progress in UI (optional)
        final progress = sent / total;
        debugPrint('[Chat] Upload progress: ${(progress * 100).toStringAsFixed(0)}%');
      },
    );
    
    // Build final metadata with server URLs
    final finalMeta = {
      'url': uploaded['video']['url'],
      'thumbnail': uploaded['thumbnail']?['url'],
      'duration': duration,
      'size': size,
      'width': width,
      'height': height,
      'mimeType': uploaded['video']['mimeType'],
    };
    
    // Send WebSocket message
    _sendMessage(
      type: 'video',
      content: caption,
      metadata: finalMeta,
      id: id,
    );
    
    // Update local message with server URLs
    await dao.updateMessage(id, {
      'metadata': jsonEncode(finalMeta),
      'status': 'sent',
    });
    state = AsyncData(await dao.getMessages(arg));
  } catch (e) {
    debugPrint('[Chat] Failed to upload video: $e');
    await dao.updateMessage(id, {'status': 'failed'});
    state = AsyncData(await dao.getMessages(arg));
  }
}
```

### Backend Implementation

**Location**: `apps/api/src/modules/chat/upload.controller.ts`

**New Endpoint**:
```typescript
@Post('upload-video')
@ApiOperation({ summary: 'Upload video and thumbnail for chat messages' })
@ApiConsumes('multipart/form-data')
@UseInterceptors(
  FileFieldsInterceptor(
    [
      { name: 'video', maxCount: 1 },
      { name: 'thumbnail', maxCount: 1 },
    ],
    {
      storage: diskStorage({
        destination: (req, file, cb) => {
          const dir = file.fieldname === 'video' 
            ? join(UPLOAD_DIR, 'videos')
            : join(UPLOAD_DIR, 'thumbnails');
          mkdirSync(dir, { recursive: true });
          cb(null, dir);
        },
        filename: (_req, file, cb) => {
          const ext = extname(file.originalname).toLowerCase();
          const filename = `${uuidv4()}-${Date.now()}${ext}`;
          cb(null, filename);
        },
      }),
      fileFilter: (_req, file, cb) => {
        if (file.fieldname === 'video') {
          const allowedVideoTypes = [
            'video/mp4',
            'video/quicktime',
            'video/x-msvideo',
            'video/x-matroska',
            'video/webm',
          ];
          if (!allowedVideoTypes.includes(file.mimetype)) {
            cb(
              new BadRequestException(
                `Invalid video type: ${file.mimetype}`,
              ),
              false,
            );
            return;
          }
        } else if (file.fieldname === 'thumbnail') {
          const allowedImageTypes = ['image/jpeg', 'image/png', 'image/webp'];
          if (!allowedImageTypes.includes(file.mimetype)) {
            cb(
              new BadRequestException(
                `Invalid thumbnail type: ${file.mimetype}`,
              ),
              false,
            );
            return;
          }
        }
        cb(null, true);
      },
      limits: { fileSize: 100 * 1024 * 1024 }, // 100MB
    },
  ),
)
uploadVideo(
  @UploadedFiles()
  files: {
    video?: Express.Multer.File[];
    thumbnail?: Express.Multer.File[];
  },
) {
  if (!files.video || files.video.length === 0) {
    throw new BadRequestException('No video file provided');
  }

  const videoFile = files.video[0];
  const thumbnailFile = files.thumbnail?.[0];

  if (videoFile.size > 100 * 1024 * 1024) {
    throw new PayloadTooLargeException('Video exceeds 100MB limit');
  }

  this.logger.log(
    `Uploaded video: ${videoFile.filename} (${videoFile.size} bytes)`,
  );

  return {
    video: {
      url: `/uploads/chat/videos/${videoFile.filename}`,
      originalName: videoFile.originalname,
      size: videoFile.size,
      mimeType: videoFile.mimetype,
    },
    thumbnail: thumbnailFile
      ? {
          url: `/uploads/chat/thumbnails/${thumbnailFile.filename}`,
          size: thumbnailFile.size,
        }
      : null,
  };
}
```

**Constants**:
```typescript
const UPLOAD_DIR = join(__dirname, '..', '..', '..', 'uploads', 'chat');

// Ensure directories exist
mkdirSync(join(UPLOAD_DIR, 'videos'), { recursive: true });
mkdirSync(join(UPLOAD_DIR, 'thumbnails'), { recursive: true });
```

### Message Metadata Structure

```json
{
  "url": "/uploads/chat/videos/abc123-1234567890.mp4",
  "thumbnail": "/uploads/chat/thumbnails/abc123-1234567890.jpg",
  "duration": 154,
  "size": 45234567,
  "width": 1920,
  "height": 1080,
  "mimeType": "video/mp4"
}
```

### Offline Queue

Reuses existing `PendingUploads` table:
- `id`: message UUID
- `conv_id`: conversation UUID
- `local_paths`: JSON array with single video path
- `caption`: optional caption text
- `created_at`: timestamp

When reconnected, `OfflineQueueService` processes pending uploads:
1. Read video from local path
2. Generate thumbnail
3. Upload video + thumbnail
4. Send WebSocket message
5. Update local message status
6. Delete from pending queue

## Testing

### Unit Tests

- Test uploadVideo() with valid video → returns URLs
- Test uploadVideo() with invalid MIME type → throws error
- Test uploadVideo() with file >100MB → throws error
- Test sendVideoMessage() creates optimistic message
- Test sendVideoMessage() queues when offline

### Integration Tests

- Test full upload flow: pick → preview → send → upload → WS send
- Test upload progress callback updates
- Test offline queue: send offline → reconnect → upload
- Test backend endpoint accepts video + thumbnail
- Test backend validates MIME types and file size

### E2E Tests

- Test send video message between two users
- Test video message displays with thumbnail and play button
- Test tap video opens full-screen player
- Test offline video send and retry on reconnect

## Acceptance Criteria

- [ ] Video and thumbnail upload to backend successfully
- [ ] Upload progress indicator shows 0-100%
- [ ] Backend validates video MIME type and size
- [ ] Backend saves video to `/uploads/chat/videos/`
- [ ] Backend saves thumbnail to `/uploads/chat/thumbnails/`
- [ ] Backend returns video and thumbnail URLs
- [ ] WebSocket message sent with type "video" and metadata
- [ ] Offline videos queued in PendingUploads table
- [ ] Pending videos upload when reconnected
- [ ] Video messages display in chat with thumbnail
- [ ] Optimistic UI shows pending status during upload

