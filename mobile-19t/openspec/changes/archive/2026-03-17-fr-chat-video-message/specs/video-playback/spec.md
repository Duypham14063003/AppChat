# Video Playback

## Overview

Provides full-screen video playback experience when user taps on a video message bubble. Uses `chewie` package for video player UI with standard controls (play/pause, seek, volume, fullscreen).

## Requirements

### Functional

- **VPB-001**: User can tap video message bubble to open full-screen player
- **VPB-002**: Video player displays with standard controls (play/pause, seek bar, volume)
- **VPB-003**: Video player supports landscape and portrait orientations
- **VPB-004**: Close button (X) in top-left corner exits player
- **VPB-005**: Video starts paused (user must tap play)
- **VPB-006**: Seek bar shows current position and total duration
- **VPB-007**: Video player handles loading states with spinner
- **VPB-008**: Video player handles errors with error message

### Non-Functional

- **VPB-NFR-001**: Video starts playing within 2 seconds of tapping play
- **VPB-NFR-002**: Seek operations are smooth and responsive
- **VPB-NFR-003**: Player works on iOS, Android, and web platforms
- **VPB-NFR-004**: Player releases resources when closed

## User Flow

```
User taps video message bubble
    ↓
Navigate to VideoPlayerScreen with video URL
    ↓
System initializes video player
    ↓
Display player with controls (paused state)
    ↓
User taps play button
    ↓
Video plays with controls visible
    ↓
User can seek, pause, adjust volume
    ↓
User taps close button
    ↓
Navigate back to chat screen
```

## Technical Details

### Flutter Implementation

**Location**: `apps/mobile/lib/features/chat/screens/video_player_screen.dart`

**Widget Structure**:
```dart
class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  
  const VideoPlayerScreen({required this.videoUrl});
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  
  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }
  
  Future<void> _initializePlayer() async {
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
    );
    await _videoController.initialize();
    
    _chewieController = ChewieController(
      videoPlayerController: _videoController,
      autoPlay: false,
      looping: false,
      allowFullScreen: true,
      allowMuting: true,
      showControls: true,
      placeholder: Center(child: CircularProgressIndicator()),
      errorBuilder: (context, errorMessage) {
        return Center(
          child: Text(
            'Không thể phát video\n$errorMessage',
            textAlign: TextAlign.center,
          ),
        );
      },
    );
    
    setState(() {});
  }
  
  @override
  void dispose() {
    _videoController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: _chewieController != null
            ? Chewie(controller: _chewieController!)
            : CircularProgressIndicator(),
      ),
    );
  }
}
```

**Dependencies**:
- `video_player: ^2.8.0`
- `chewie: ^1.7.0`

### Video Message Bubble Integration

**Location**: `apps/mobile/lib/features/chat/widgets/message_bubble.dart`

**Changes**:
```dart
// In MessageBubble widget
if (message.type == 'video') {
  return VideoThumbnailWidget(
    thumbnailUrl: metadata['thumbnail'],
    duration: metadata['duration'],
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoPlayerScreen(
            videoUrl: metadata['url'],
          ),
        ),
      );
    },
  );
}
```

### VideoThumbnailWidget

**Location**: `apps/mobile/lib/features/chat/widgets/video_thumbnail_widget.dart`

```dart
class VideoThumbnailWidget extends StatelessWidget {
  final String thumbnailUrl;
  final int duration; // seconds
  final VoidCallback onTap;
  
  const VideoThumbnailWidget({
    required this.thumbnailUrl,
    required this.duration,
    required this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          // Thumbnail image
          Image.network(
            thumbnailUrl,
            fit: BoxFit.cover,
            width: double.infinity,
          ),
          // Play button overlay (center)
          Center(
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
          // Duration badge (bottom-left)
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _formatDuration(duration),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }
}
```

### UI Layout

**Video Message Bubble**:
```
┌─────────────────────────────────┐
│  ┌───────────────────────────┐  │
│  │░░░░░░░░░░░░░░░░░░░░░░░░░░░│  │
│  │░░░░░░░░░░░░░░░░░░░░░░░░░░░│  │
│  │░░░░░░ THUMBNAIL ░░░░░░░░░░│  │
│  │░░░░░░░░░░░░░░░░░░░░░░░░░░░│  │
│  │░░░░░░░  ┌─────┐  ░░░░░░░░░│  │
│  │░░░░░░░  │  ▶  │  ░░░░░░░░░│  │
│  │░░░░░░░  └─────┘  ░░░░░░░░░│  │
│  │ 2:34                      │  │
│  └───────────────────────────┘  │
│  Check out this video!           │
│                      12:34 ✓✓   │
└─────────────────────────────────┘
```

**Full-Screen Player**:
```
┌───────────────────────────────────────┐
│  [×]                                  │
│                                       │
│                                       │
│          VIDEO PLAYING                │
│                                       │
│                                       │
│  ━━━━━━━━●━━━━━━━━━━━━━━━━━━━━━━━   │
│  [▶] 1:23 / 2:34            [🔊] [⛶] │
└───────────────────────────────────────┘
```

## Testing

### Unit Tests

- Test duration formatting (e.g., 154s → "2:34")
- Test VideoPlayerController initialization
- Test ChewieController configuration

### Widget Tests

- Test VideoThumbnailWidget renders thumbnail, play button, duration
- Test tap on VideoThumbnailWidget triggers onTap callback
- Test VideoPlayerScreen renders player and close button

### Integration Tests

- Test full flow: tap bubble → player opens → video plays → close → return to chat
- Test video playback with network URL
- Test error handling for invalid video URL

## Acceptance Criteria

- [ ] Tapping video bubble opens full-screen player
- [ ] Video player displays with play/pause/seek controls
- [ ] Video starts paused (user must tap play)
- [ ] Close button exits player and returns to chat
- [ ] Duration badge shows on video bubble
- [ ] Play button overlay visible on thumbnail
- [ ] Player supports landscape and portrait
- [ ] Player handles loading and error states
- [ ] Player releases resources on close

