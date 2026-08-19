# Video Picking

## Overview

Enables users to select video files from gallery or record new videos using the device camera. Validates video duration (≤300 seconds) and file size (≤100MB) before proceeding to preview.

## Requirements

### Functional

- **VP-001**: User can tap attach button in MessageInputBar and select "Video" option
- **VP-002**: System opens video picker using `image_picker.pickVideo()` method
- **VP-003**: User can select video from gallery or record new video with camera
- **VP-004**: System validates video duration ≤300 seconds using `video_player` initialization
- **VP-005**: System validates video file size ≤100MB using file length
- **VP-006**: If validation fails, system shows error snackbar with specific message
- **VP-007**: If validation passes, system navigates to VideoPreviewScreen with selected video

### Non-Functional

- **VP-NFR-001**: Duration validation completes within 2 seconds
- **VP-NFR-002**: Error messages are user-friendly in Vietnamese
- **VP-NFR-003**: Video picker supports iOS, Android, and web platforms

## User Flow

```
User taps attach → Select "Video" option
    ↓
ImagePicker.pickVideo() opens
    ↓
User selects video or records new
    ↓
System validates duration (≤300s)
    ↓
System validates size (≤100MB)
    ↓
[Valid] → Navigate to VideoPreviewScreen
[Invalid] → Show error snackbar
```

## Technical Details

### Flutter Implementation

**Location**: `apps/mobile/lib/features/chat/widgets/message_input_bar.dart`

**Changes**:
- Update `_showAttachSheet()` method to show bottom sheet with options:
  - 📷 Camera (existing)
  - 🖼️ Gallery (existing)
  - 🎥 Video (new)
  - 📄 File (future)
- Add `_pickVideo()` method:
  ```dart
  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final video = await picker.pickVideo(source: ImageSource.gallery);
    if (video == null) return;
    
    // Validate size
    final file = File(video.path);
    final size = await file.length();
    if (size > 100 * 1024 * 1024) {
      _showError('Video quá lớn (tối đa 100MB)');
      return;
    }
    
    // Validate duration
    final controller = VideoPlayerController.file(file);
    await controller.initialize();
    final duration = controller.value.duration.inSeconds;
    await controller.dispose();
    
    if (duration > 300) {
      _showError('Video quá dài (tối đa 5 phút)');
      return;
    }
    
    widget.onAttachVideo?.call(video);
  }
  ```
- Add `onAttachVideo` callback parameter to `MessageInputBar` widget

**Dependencies**:
- `image_picker: ^1.0.0` (already exists)
- `video_player: ^2.8.0` (new)

### Error Messages

- Duration exceeded: "Video quá dài (tối đa 5 phút)"
- Size exceeded: "Video quá lớn (tối đa 100MB)"
- Permission denied: "Cần quyền truy cập thư viện để chọn video"
- Unknown error: "Không thể chọn video. Vui lòng thử lại."

## Testing

### Unit Tests

- Test duration validation with video >300s → shows error
- Test duration validation with video ≤300s → proceeds
- Test size validation with file >100MB → shows error
- Test size validation with file ≤100MB → proceeds

### Integration Tests

- Test video picker opens when "Video" option tapped
- Test navigation to VideoPreviewScreen after successful validation
- Test error snackbar appears on validation failure

## Acceptance Criteria

- [ ] User can tap attach button and see "Video" option
- [ ] Video picker opens and allows gallery/camera selection
- [ ] Videos >5 minutes show error message
- [ ] Videos >100MB show error message
- [ ] Valid videos navigate to preview screen
- [ ] Error messages are in Vietnamese and user-friendly

