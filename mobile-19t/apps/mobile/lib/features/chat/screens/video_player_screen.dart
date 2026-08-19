import 'dart:math' as math;
import 'dart:io';
import 'dart:typed_data';
import 'package:chewie/chewie.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import '../../../core/config/app_config.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/utils/browser_file_download_stub.dart'
    if (dart.library.html) '../../../core/utils/browser_file_download_web.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerScreen({super.key, required this.videoUrl});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  String? _error;
  bool _isSaving = false;
  final Dio _dio = Dio();

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      final resolvedUrl = _resolveUrl(widget.videoUrl);
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(resolvedUrl),
      );
      await _videoController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: false,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        placeholder: const Center(child: CircularProgressIndicator()),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              'Không thể phát video\n$errorMessage',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          );
        },
      );

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _showNotice(String message) {
    if (!mounted) return;
    showTopSnackBar(context, message: message);
  }

  String _guessFileName(String url) {
    final uri = Uri.tryParse(url);
    final fromPath = uri?.pathSegments.isNotEmpty == true
        ? uri!.pathSegments.last
        : '';
    if (fromPath.isNotEmpty) {
      return fromPath;
    }
    return 'shared_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
  }

  Future<void> _saveVideo() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final resolvedUrl = _resolveUrl(widget.videoUrl);

      if (kIsWeb) {
        final response = await _dio.get<List<int>>(
          resolvedUrl,
          options: Options(responseType: ResponseType.bytes),
        );
        final bytes = response.data;
        if (bytes == null || bytes.isEmpty) {
          throw Exception('Video download failed');
        }
        await downloadBytesInBrowser(
          bytes: Uint8List.fromList(bytes),
          filename: _guessFileName(resolvedUrl),
          mimeType: 'video/mp4',
        );
        _showNotice('Đã tải video về máy.');
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final filename = _guessFileName(resolvedUrl);
      final file = File('${tempDir.path}/$filename');

      await _dio.download(resolvedUrl, file.path);

      final result = await ImageGallerySaver.saveFile(
        file.path,
        name: filename,
      );
      final isSuccess =
          (result['isSuccess'] == true) || (result['success'] == true);
      _showNotice(
        isSuccess ? 'Đã lưu video về máy.' : 'Không thể lưu video về máy.',
      );
    } catch (e) {
      _showNotice('Không thể lưu video về máy.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  static String _resolveUrl(String urlOrPath) {
    if (urlOrPath.startsWith('/uploads')) {
      return '${AppConfig.instance.apiUrl}$urlOrPath';
    }
    return urlOrPath;
  }

  Widget _buildOverlayButton({
    required IconData icon,
    required VoidCallback onPressed,
    String? tooltip,
    Widget? child,
  }) {
    return Material(
      color: Colors.black.withValues(alpha: 0.46),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: child ?? Icon(icon, color: Colors.white),
      ),
    );
  }

  Widget _buildPlayerContent() {
    if (_error != null) {
      return const Text(
        'Không thể phát video',
        style: TextStyle(color: Colors.white70),
      );
    }

    if (_chewieController == null) {
      return const CircularProgressIndicator();
    }

    return Chewie(controller: _chewieController!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            final horizontalPadding = isWide ? 32.0 : 0.0;
            final verticalPadding = isWide ? 32.0 : 0.0;
            final maxPlayerWidth = isWide
                ? math
                      .min(
                        constraints.maxWidth - (horizontalPadding * 2),
                        1280.0,
                      )
                      .toDouble()
                : constraints.maxWidth;
            final maxPlayerHeight = isWide
                ? math
                      .min(
                        constraints.maxHeight - (verticalPadding * 2) - 36,
                        820.0,
                      )
                      .toDouble()
                : constraints.maxHeight;
            final controller = _videoController;
            final aspectRatio =
                controller != null &&
                    controller.value.isInitialized &&
                    controller.value.aspectRatio > 0
                ? controller.value.aspectRatio
                : 16 / 9;

            var playerWidth = maxPlayerWidth;
            var playerHeight = playerWidth / aspectRatio;
            if (playerHeight > maxPlayerHeight) {
              playerHeight = maxPlayerHeight;
              playerWidth = playerHeight * aspectRatio;
            }

            final playerSurface = SizedBox(
              width: playerWidth,
              height: playerHeight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(isWide ? 24 : 0),
                child: ColoredBox(
                  color: Colors.black,
                  child: _buildPlayerContent(),
                ),
              ),
            );

            return Stack(
              fit: StackFit.expand,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF070707), Color(0xFF111111)],
                    ),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: verticalPadding,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(isWide ? 28 : 0),
                        boxShadow: isWide
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.42),
                                  blurRadius: 36,
                                  spreadRadius: 8,
                                ),
                              ]
                            : const [],
                      ),
                      child: playerSurface,
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: _buildOverlayButton(
                    icon: Icons.close,
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: _isSaving
                      ? _buildOverlayButton(
                          icon: Icons.download_rounded,
                          tooltip: 'Đang tải',
                          onPressed: () {},
                          child: const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : _buildOverlayButton(
                          icon: Icons.download_rounded,
                          tooltip: 'Tải xuống',
                          onPressed: _saveVideo,
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
