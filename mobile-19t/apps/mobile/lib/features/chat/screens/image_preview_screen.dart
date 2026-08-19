import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/utils/web_attachment_preview.dart';
import '../../../core/theme/theme_color_presets.dart';

class ImagePreviewResult {
  final List<XFile> images;
  final String? caption;
  ImagePreviewResult({required this.images, this.caption});
}

class ImagePreviewScreen extends StatefulWidget {
  final List<XFile> images;

  const ImagePreviewScreen({super.key, required this.images});

  @override
  State<ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends State<ImagePreviewScreen> {
  late List<XFile> _images;
  late PageController _pageController;
  final _captionController = TextEditingController();
  int _currentIndex = 0;
  final Map<XFile, WebAttachmentPreviewHandle?> _previewHandles = {};

  @override
  void initState() {
    super.initState();
    _images = List.from(widget.images);
    _pageController = PageController();
    if (kIsWeb) {
      for (final image in _images) {
        _primePreviewHandle(image);
      }
    }
  }

  @override
  void dispose() {
    for (final handle in _previewHandles.values) {
      disposeWebAttachmentPreview(handle);
    }
    _pageController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  void _removeImage(int index) {
    setState(() {
      final removedImage = _images.removeAt(index);
      final removedHandle = _previewHandles.remove(removedImage);
      disposeWebAttachmentPreview(removedHandle);
      if (_images.isEmpty) {
        Navigator.of(context).pop();
        return;
      }
      if (_currentIndex >= _images.length) {
        _currentIndex = _images.length - 1;
      }
      _pageController.jumpToPage(_currentIndex);
    });
  }

  void _send() {
    final caption = _captionController.text.trim();
    Navigator.of(context).pop(
      ImagePreviewResult(
        images: _images,
        caption: caption.isEmpty ? null : caption,
      ),
    );
  }

  void _primePreviewHandle(XFile xFile) {
    if (_previewHandles.containsKey(xFile)) return;
    resolveWebAttachmentPreview(xFile).then((handle) {
      if (!mounted) {
        disposeWebAttachmentPreview(handle);
        return;
      }
      setState(() {
        _previewHandles[xFile] = handle;
      });
    });
  }

  Widget _buildXFileImage(
    XFile xFile, {
    BoxFit fit = BoxFit.contain,
    double? width,
    double? height,
  }) {
    if (kIsWeb) {
      _primePreviewHandle(xFile);
      final previewUrl = _previewHandles[xFile]?.url;
      if (previewUrl == null || previewUrl.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      return Image.network(previewUrl, fit: fit, width: width, height: height);
    }
    return Image.file(File(xFile.path), fit: fit, width: width, height: height);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final colorScheme = Theme.of(context).colorScheme;
    final closeChipColor = palette.isLight
        ? palette.background.withValues(alpha: 0.72)
        : Colors.black54;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        foregroundColor: palette.textPrimary,
        title: Text('${_currentIndex + 1}/${_images.length}'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _images.length,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  child: Center(child: _buildXFileImage(_images[index])),
                );
              },
            ),
          ),
          // Thumbnail strip
          if (_images.length > 1)
            Container(
              height: 72,
              color: palette.surface,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                itemCount: _images.length,
                itemBuilder: (context, index) {
                  final isActive = index == _currentIndex;
                  return GestureDetector(
                    onTap: () {
                      _pageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Container(
                      width: 56,
                      height: 56,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isActive
                              ? palette.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: _buildXFileImage(
                              _images[index],
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => _removeImage(index),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: closeChipColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close,
                                  size: 14,
                                  color: palette.surface,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          // Caption + Send
          Container(
            color: palette.surface,
            padding: EdgeInsets.only(
              left: 12,
              right: 8,
              top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: palette.surfaceVariant,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: TextField(
                      controller: _captionController,
                      style: TextStyle(color: palette.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Thêm chú thích...',
                        hintStyle: TextStyle(color: palette.textHint),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton.small(
                  backgroundColor: colorScheme.primary,
                  onPressed: _send,
                  child: Icon(
                    Icons.send_rounded,
                    color: colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
