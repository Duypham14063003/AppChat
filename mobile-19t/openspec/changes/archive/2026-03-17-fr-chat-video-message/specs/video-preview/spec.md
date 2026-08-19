# Video Preview

## Overview

Provides a preview screen where users can watch the selected video, see metadata (duration, size, resolution), add an optional caption, and send the video message.

## Requirements

### Functional

- **VPR-001**: Screen displays video player with play/pause controls
- **VPR-002**: Screen shows video metadata: filename, duration, file size, resolution
- **VPR-003**: Screen provides TextField for optional caption input
- **VPR-004**: Screen has Send button in top-right corner
- **VPR-005**: Screen has Back button in top-left corner to cancel
- **VPR-006**: Video player preserves aspect ratio and fits screen width
- **VPR-007**: User can play/pause video to preview before sending
- **VPR-008**: Tapping Send triggers video upload and message send flow
- **VPR-009**: Tapping Back returns to chat screen without sending

### Non-Functional

- **VPR-NFR-001**: Video player initializes within 1 second
- **VPR-NFR-002**: UI is responsive and doesn't block during video loading
- **VPR-NFR-003**: Metadata displays in human-readable format (e.g., "45.2 MB", "2:34")

## User Flow

```
Navigate to VideoPreviewScreen with XFile
    ↓
System initializes video player
    ↓
System extracts metadata (duration, size, resolution)
    ↓
Display video player + metadata + caption field
    ↓
User previews video (optional)
    ↓
User enters caption (optional)
    ↓
User taps Send
    ↓
Navigate back to chat screen
    ↓
Trigger sendVideoMessage() in chat provider
```

## Technical Details

### Flutter Implementation

**Location**: `apps/mobile/lib/features/chat/screens/video_preview_screen.dart`

**Widget Structure**:
```dart
class VideoPreviewScreen extends StatefulWidget {
  final XFile video;
  
  const VideoPreviewScreen({required this.video});
}

class _VideoPreviewScreenState extends State<VideoPreviewScreen> {
  late VideoPlayerController _controller;
  final _captionController = TextEditingController();
  bool _isInitialized = false;
  
  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }
  
  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.file(File(widget.video.path));
    await _controller.initialize();
    setState(() => _isInitialized = true);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gửi video'),
        actions: [
          IconButton(
            icon: Icon(Icons.send),
            onPressed: _send,
          ),
        ],
      ),
      body: Column(
        children: [
          // Video player
          if (_isInitialized)
            AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
          // Play/pause button overlay
          // Metadata row
          _buildMetadata(),
          // Caption input
          TextField(
            controller: _captionController,
            decoration: InputDecoration(
              hintText: 'Thêm chú thích...',
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMetadata() {
    final duration = _controller.value.duration;
    final size = File(widget.video.path).lengthSync();
    final width = _controller.value.size.width.toInt();
    final height = _controller.value.size.height.toInt();
    
    return Row(
      children: [
        Icon(Icons.videocam),
        Text(widget.video.name),
        Text('${_formatSize(size)} • ${_formatDuration(duration)} • ${width}x${height}'),
      ],
    );
  }
  
  void _send() {
    Navigator.pop(context, VideoPreviewResult(
      video: widget.video,
      caption: _captionController.text.trim(),
    ));
  }
}

class VideoPreviewResult {
  final XFile video;
  final String? caption;
  
  VideoPreviewResult({required this.video, this.caption});
}
```

**Dependencies**:
- `video_player: ^2.8.0`

### Metadata Formatting

- **Duration**: Format as "M:SS" (e.g., "2:34", "12:05")
- **Size**: Format with units (e.g., "45.2 MB", "1.3 GB")
- **Resolution**: Format as "WxH" (e.g., "1920x1080", "1280x720")

### UI Layout

```
┌───────────────────────────────────────┐
│  [<] Gửi video              [Gửi]    │
├───────────────────────────────────────┤
│                                       │
│  ┌─────────────────────────────────┐  │
│  │                                 │  │
│  │        VIDEO PLAYER             │  │
│  │                                 │  │
│  │     [▶]  ━━━━●━━━━  2:34       │  │
│  │                                 │  │
│  └─────────────────────────────────┘  │
│                                       │
│  📹 vacation.mp4                      │
│  💾 45.2 MB • 2:34 • 1920x1080       │
│                                       │
│  ┌─────────────────────────────────┐  │
│  │ Thêm chú thích...               │  │
│  └─────────────────────────────────┘  │
└───────────────────────────────────────┘
```

## Testing

### Unit Tests

- Test metadata formatting (duration, size, resolution)
- Test caption input and retrieval
- Test VideoPreviewResult creation

### Widget Tests

- Test video player initialization
- Test Send button triggers navigation with result
- Test Back button cancels without result
- Test caption TextField accepts input

### Integration Tests

- Test full flow: pick video → preview → send → return to chat
- Test video playback in preview screen

## Acceptance Criteria

- [ ] Video player displays and can play/pause
- [ ] Metadata shows filename, duration, size, resolution
- [ ] Caption TextField accepts user input
- [ ] Send button returns to chat with video and caption
- [ ] Back button cancels and returns to chat
- [ ] Video aspect ratio is preserved
- [ ] UI is responsive during video loading

