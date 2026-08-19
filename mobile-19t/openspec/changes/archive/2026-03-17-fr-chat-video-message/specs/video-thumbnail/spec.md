# Video Thumbnail Generation

## Overview

Generates thumbnail images from video files on the client side using the `video_thumbnail` package. Thumbnails are extracted at 1 second (or video midpoint if shorter), resized to 320x240, and compressed as JPEG quality 70%.

## Requirements

### Functional

- **VT-001**: System generates thumbnail from video file after validation
- **VT-002**: Thumbnail extracted at 1 second timestamp (or midpoint if video <2s)
- **VT-003**: Thumbnail resized to max width 320px, preserving aspect ratio
- **VT-004**: Thumbnail compressed as JPEG with quality 70%
- **VT-005**: Thumbnail returned as `Uint8List` for upload
- **VT-006**: If thumbnail generation fails, use default video icon placeholder

### Non-Functional

- **VT-NFR-001**: Thumbnail generation completes within 3 seconds
- **VT-NFR-002**: Thumbnail file size ≤100KB
- **VT-NFR-003**: Thumbnail generation works on iOS, Android, and web

## User Flow

```
Video validated and preview screen opened
    ↓
System generates thumbnail in background
    ↓
[Success] → Thumbnail ready for upload
[Failure] → Use default placeholder icon
    ↓
User taps Send
    ↓
Upload video + thumbnail together
```

## Technical Details

### Flutter Implementation

**Location**: `apps/mobile/lib/features/chat/data/chat_repository.dart`

**Method**:
```dart
Future<Uint8List?> generateVideoThumbnail(String videoPath) async {
  try {
    final uint8list = await VideoThumbnail.thumbnailData(
      video: videoPath,
      imageFormat: ImageFormat.JPEG,
      maxWidth: 320,
      quality: 70,
      timeMs: 1000, // 1 second
    );
    return uint8list;
  } catch (e) {
    debugPrint('[Chat] Failed to generate thumbnail: $e');
    return null;
  }
}
```

**Usage in sendVideoMessage**:
```dart
Future<void> sendVideoMessage(XFile video, String? caption) async {
  // Generate thumbnail
  final thumbnailBytes = await repo.generateVideoThumbnail(video.path);
  
  // Upload video + thumbnail
  final uploaded = await repo.uploadVideo(video, thumbnailBytes);
  
  // Send message with metadata
  final metadata = {
    'url': uploaded['videoUrl'],
    'thumbnail': uploaded['thumbnailUrl'],
    'duration': duration,
    'size': size,
    'width': width,
    'height': height,
  };
  
  _sendMessage(type: 'video', metadata: metadata, content: caption);
}
```

**Dependencies**:
- `video_thumbnail: ^0.5.3`

### Thumbnail Specifications

- **Format**: JPEG
- **Max width**: 320px (height auto-calculated to preserve aspect ratio)
- **Quality**: 70% (balance between size and visual quality)
- **Extraction time**: 1000ms (1 second into video)
- **Fallback**: If video <2 seconds, extract at midpoint

### Error Handling

- If thumbnail generation fails (e.g., corrupted video, unsupported format):
  - Log error to console
  - Return `null`
  - Upload video without thumbnail
  - Backend can generate placeholder or use default icon

## Testing

### Unit Tests

- Test thumbnail generation with valid video → returns Uint8List
- Test thumbnail generation with invalid path → returns null
- Test thumbnail size is ≤100KB
- Test thumbnail dimensions are ≤320px width

### Integration Tests

- Test thumbnail generation for various video formats (mp4, mov, webm)
- Test thumbnail generation for short videos (<2s)
- Test thumbnail generation for long videos (>5min)

## Acceptance Criteria

- [ ] Thumbnail generated from video at 1 second mark
- [ ] Thumbnail resized to max 320px width
- [ ] Thumbnail compressed as JPEG quality 70%
- [ ] Thumbnail file size ≤100KB
- [ ] Thumbnail generation completes within 3 seconds
- [ ] Failed generation returns null without crashing
- [ ] Works on iOS, Android, and web platforms

