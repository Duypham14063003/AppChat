import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../../../core/utils/web_attachment_preview.dart';
import '../../../core/theme/app_colors.dart';

class VideoPreviewResult {
  final XFile video;
  final String? caption;
  final int duration;
  final int width;
  final int height;
  final int fileSize;
  VideoPreviewResult({
    required this.video,
    this.caption,
    required this.duration,
    required this.width,
    required this.height,
    required this.fileSize,
  });
}

class VideoPreviewScreen extends StatefulWidget {
  final XFile video;

  const VideoPreviewScreen({super.key, required this.video});

  @override
  State<VideoPreviewScreen> createState() => _VideoPreviewScreenState();
}

class _VideoPreviewScreenState extends State<VideoPreviewScreen> {
  VideoPlayerController? _controller;
  final _captionController = TextEditingController();
  bool _isInitialized = false;
  int _fileSize = 0;
  WebAttachmentPreviewHandle? _previewHandle;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    if (kIsWeb) {
      _previewHandle = await resolveWebAttachmentPreview(widget.video);
      final previewUrl = _previewHandle?.url;
      if (previewUrl == null || previewUrl.isEmpty) {
        throw StateError('Missing video preview URL');
      }
      _controller = VideoPlayerController.networkUrl(Uri.parse(previewUrl));
    } else {
      _controller = VideoPlayerController.file(File(widget.video.path));
    }
    await _controller!.initialize();
    _fileSize = await widget.video.length();
    if (mounted) setState(() => _isInitialized = true);
  }

  @override
  void dispose() {
    _controller?.dispose();
    if (kIsWeb) {
      disposeWebAttachmentPreview(_previewHandle);
    }
    _captionController.dispose();
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      final controller = _controller;
      if (controller == null) return;
      controller.value.isPlaying ? controller.pause() : controller.play();
    });
  }
  // VIDEO_PREVIEW_CONTINUED

  void _send() {
    final controller = _controller;
    if (controller == null) return;
    controller.pause();
    final caption = _captionController.text.trim();
    Navigator.of(context).pop(
      VideoPreviewResult(
        video: widget.video,
        caption: caption.isEmpty ? null : caption,
        duration: controller.value.duration.inSeconds,
        width: controller.value.size.width.toInt(),
        height: controller.value.size.height.toInt(),
        fileSize: _fileSize,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Gửi video'),
        actions: [
          IconButton(
            icon: const Icon(Icons.send_rounded, color: AppColors.gold),
            tooltip: 'Gửi',
            onPressed: _send,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isInitialized
                ? GestureDetector(
                    onTap: _togglePlay,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: _controller!.value.aspectRatio,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            VideoPlayer(_controller!),
                            ValueListenableBuilder<VideoPlayerValue>(
                              valueListenable: _controller!,
                              builder: (context, value, child) {
                                if (!value.isPlaying) {
                                  return Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.5,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.play_arrow,
                                      color: Colors.white,
                                      size: 36,
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : const Center(child: CircularProgressIndicator()),
          ),
          // Metadata
          if (_isInitialized) _buildMetadata(),
          // Caption + Send
          Container(
            color: Colors.black87,
            padding: EdgeInsets.only(
              left: 12,
              right: 8,
              top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            child: TextField(
              controller: _captionController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Thêm chú thích...',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadata() {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();
    final duration = controller.value.duration;
    final width = controller.value.size.width.toInt();
    final height = controller.value.size.height.toInt();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.black87,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.videocam,
                color: AppColors.textSecondary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.video.name,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${_formatSize(_fileSize)} · ${_formatDuration(duration)} · ${width}x$height',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDuration(Duration d) {
    final mins = d.inMinutes;
    final secs = d.inSeconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
