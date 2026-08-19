import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:super_clipboard/super_clipboard.dart';
import '../../../core/config/app_config.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/utils/browser_file_download_stub.dart'
    if (dart.library.html) '../../../core/utils/browser_file_download_web.dart';

class ImageViewerScreen extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const ImageViewerScreen({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;

  late final FocusNode _focusNode;
  final Dio _dio = Dio();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    if (index < 0 || index >= widget.imageUrls.length) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _goTo(_currentIndex - 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _goTo(_currentIndex + 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  static String _resolveUrl(String urlOrPath) {
    if (urlOrPath.startsWith('/uploads')) {
      return '${AppConfig.instance.apiUrl}$urlOrPath';
    }
    return urlOrPath;
  }

  ImageProvider _imageProvider(String urlOrPath) {
    final resolved = _resolveUrl(urlOrPath);
    if (kIsWeb) return NetworkImage(resolved);
    final isNetworkUrl =
        resolved.startsWith('http') || resolved.startsWith('blob:');
    if (!isNetworkUrl) return FileImage(File(urlOrPath));
    return CachedNetworkImageProvider(resolved);
  }

  String get _currentImageSource => widget.imageUrls[_currentIndex];

  Future<void> _showImageActions() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF222222),
      barrierColor: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 16),
                _ActionTile(
                  icon: Icons.download_rounded,
                  label: 'Lưu ảnh về máy',
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _saveCurrentImage();
                  },
                ),
                // _ActionTile(
                //   icon: Icons.share_rounded,
                //   label: 'Chia sẻ',
                //   onTap: () async {
                //     Navigator.of(sheetContext).pop();
                //     await _shareCurrentImage();
                //   },
                // ),
                _ActionTile(
                  icon: Icons.copy_rounded,
                  label: 'Copy',
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _copyCurrentImage();
                  },
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text(
                      'Hủy',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveCurrentImage() async {
    try {
      if (kIsWeb) {
        final bytes = await _loadImageBytes(_currentImageSource);
        await downloadBytesInBrowser(
          bytes: bytes,
          filename: _guessFileName(_resolveUrl(_currentImageSource)),
          mimeType: _mimeTypeForImagePath(_currentImageSource),
        );
        _showNotice('Đã tải ảnh về máy.');
        return;
      }

      final file = await _materializeImageFile(_currentImageSource);
      final result = await ImageGallerySaver.saveFile(
        file.path,
        name: p.basename(file.path),
      );
      final isSuccess =
          (result['isSuccess'] == true) || (result['success'] == true);
      _showNotice(
        isSuccess ? 'Đã lưu ảnh về máy.' : 'Không thể lưu ảnh về máy.',
      );
    } catch (_) {
      _showNotice('Không thể lưu ảnh về máy.');
    }
  }

  Future<void> _copyCurrentImage() async {
    try {
      final resolved = _resolveUrl(_currentImageSource);
      final format = _clipboardImageFormatForPath(resolved);
      final clipboard = SystemClipboard.instance;
      if (format == null || clipboard == null) {
        await _copyCurrentImageLink();
        return;
      }

      final bytes = await _loadImageBytes(_currentImageSource);
      if (bytes.isEmpty) {
        await _copyCurrentImageLink();
        return;
      }

      final item = DataWriterItem(suggestedName: _guessFileName(resolved));
      item.add(format(bytes));
      await clipboard.write([item]);
      _showNotice('Đã copy ảnh.');
    } catch (_) {
      await _copyCurrentImageLink();
    }
  }

  Future<void> _copyCurrentImageLink() async {
    final source = _currentImageSource;
    final resolved = _resolveUrl(source);
    await Clipboard.setData(
      ClipboardData(text: resolved.startsWith('http') ? resolved : source),
    );
    _showNotice('Không thể copy ảnh trực tiếp, đã copy liên kết ảnh.');
  }

  Future<File> _materializeImageFile(String urlOrPath) async {
    if (kIsWeb) {
      throw UnsupportedError('materializeImageFile is not supported on web');
    }
    final resolved = _resolveUrl(urlOrPath);
    if (!kIsWeb &&
        !resolved.startsWith('http') &&
        !resolved.startsWith('blob:')) {
      return File(urlOrPath);
    }

    final tempDir = await getTemporaryDirectory();
    final filename = _guessFileName(resolved);
    final file = File('${tempDir.path}/$filename');
    final response = await _dio.get<List<int>>(
      resolved,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw Exception('Image download failed');
    }
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<Uint8List> _loadImageBytes(String urlOrPath) async {
    final resolved = _resolveUrl(urlOrPath);
    if (!kIsWeb &&
        !resolved.startsWith('http') &&
        !resolved.startsWith('blob:')) {
      return File(urlOrPath).readAsBytes();
    }

    final response = await _dio.get<List<int>>(
      resolved,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw Exception('Image download failed');
    }
    return Uint8List.fromList(bytes);
  }

  String _guessFileName(String url) {
    final uri = Uri.tryParse(url);
    final fromPath = uri?.pathSegments.isNotEmpty == true
        ? uri!.pathSegments.last
        : '';
    if (fromPath.isNotEmpty) {
      return fromPath;
    }
    return 'shared_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
  }

  FileFormat? _clipboardImageFormatForPath(String path) {
    switch (p.extension(path).toLowerCase()) {
      case '.png':
        return Formats.png;
      case '.jpg':
      case '.jpeg':
        return Formats.jpeg;
      case '.gif':
        return Formats.gif;
      case '.bmp':
        return Formats.bmp;
      case '.webp':
        return Formats.webp;
      default:
        return null;
    }
  }

  String _mimeTypeForImagePath(String path) {
    switch (p.extension(path).toLowerCase()) {
      case '.png':
        return 'image/png';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.gif':
        return 'image/gif';
      case '.bmp':
        return 'image/bmp';
      case '.webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }

  void _showNotice(String message) {
    if (!mounted) return;
    showTopSnackBar(context, message: message);
  }

  Widget _buildWebGallery() {
    return PageView.builder(
      controller: _pageController,
      itemCount: widget.imageUrls.length,
      onPageChanged: (index) => setState(() => _currentIndex = index),
      itemBuilder: (context, index) {
        return LayoutBuilder(
          builder: (context, constraints) {
            return InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              panEnabled: true,
              child: Center(
                child: Image.network(
                  _resolveUrl(widget.imageUrls[index]),
                  fit: BoxFit.contain,
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  filterQuality: FilterQuality.none,
                  isAntiAlias: false,
                  webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white54,
                        size: 40,
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPress: _showImageActions,
              child: kIsWeb
                  ? _buildWebGallery()
                  : PhotoViewGallery.builder(
                      pageController: _pageController,
                      itemCount: widget.imageUrls.length,
                      onPageChanged: (i) => setState(() => _currentIndex = i),
                      builder: (context, index) {
                        return PhotoViewGalleryPageOptions(
                          imageProvider: _imageProvider(
                            widget.imageUrls[index],
                          ),
                          minScale: PhotoViewComputedScale.contained,
                          maxScale: PhotoViewComputedScale.covered * 3,
                        );
                      },
                      backgroundDecoration: const BoxDecoration(
                        color: Colors.black,
                      ),
                      scrollPhysics: const BouncingScrollPhysics(),
                    ),
            ),
            // Close button
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            // Image counter
            if (widget.imageUrls.length > 1)
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    '${_currentIndex + 1}/${widget.imageUrls.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            // Navigation arrows (web/desktop)
            if (widget.imageUrls.length > 1) ...[
              if (_currentIndex > 0)
                Positioned(
                  left: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton(
                      icon: const Icon(
                        Icons.chevron_left,
                        color: Colors.white70,
                        size: 36,
                      ),
                      onPressed: () => _goTo(_currentIndex - 1),
                    ),
                  ),
                ),
              if (_currentIndex < widget.imageUrls.length - 1)
                Positioned(
                  right: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton(
                      icon: const Icon(
                        Icons.chevron_right,
                        color: Colors.white70,
                        size: 36,
                      ),
                      onPressed: () => _goTo(_currentIndex + 1),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: Icon(icon, color: Colors.white),
          title: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
