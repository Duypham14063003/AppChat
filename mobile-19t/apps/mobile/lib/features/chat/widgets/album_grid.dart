import 'dart:io';
import 'dart:math' show min;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/optimized_network_image.dart';

class AlbumGrid extends StatelessWidget {
  final List<String> imageUrls;
  final void Function(int index)? onTap;
  final double maxHeight;
  final double gap;

  const AlbumGrid({
    super.key,
    required this.imageUrls,
    this.onTap,
    this.maxHeight = 300,
    this.gap = 2,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) return const SizedBox.shrink();
    final count = imageUrls.length;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: count == 1 ? maxHeight : min(maxHeight, 240),
        child: switch (count) {
          1 => _buildSingle(),
          2 => _buildTwo(),
          3 => _buildThree(),
          _ => _buildGrid(count),
        },
      ),
    );
  }

  Widget _buildSingle() {
    return GestureDetector(
      onTap: () => onTap?.call(0),
      child: _buildImage(imageUrls[0], useThumbnail: false),
    );
  }

  Widget _buildTwo() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => onTap?.call(0),
            child: _buildImage(imageUrls[0], useThumbnail: true),
          ),
        ),
        SizedBox(width: gap),
        Expanded(
          child: GestureDetector(
            onTap: () => onTap?.call(1),
            child: _buildImage(imageUrls[1], useThumbnail: true),
          ),
        ),
      ],
    );
  }

  Widget _buildThree() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: () => onTap?.call(0),
            child: _buildImage(imageUrls[0], useThumbnail: true),
          ),
        ),
        SizedBox(width: gap),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => onTap?.call(1),
                  child: _buildImage(imageUrls[1], useThumbnail: true),
                ),
              ),
              SizedBox(height: gap),
              Expanded(
                child: GestureDetector(
                  onTap: () => onTap?.call(2),
                  child: _buildImage(imageUrls[2], useThumbnail: true),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGrid(int count) {
    final showOverlay = count > 4;
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => onTap?.call(0),
                  child: _buildImage(imageUrls[0], useThumbnail: true),
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                child: GestureDetector(
                  onTap: () => onTap?.call(1),
                  child: _buildImage(imageUrls[1], useThumbnail: true),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: gap),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => onTap?.call(2),
                  child: _buildImage(imageUrls[2], useThumbnail: true),
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                child: GestureDetector(
                  onTap: () => onTap?.call(3),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildImage(imageUrls[min(3, imageUrls.length - 1)], useThumbnail: true),
                      if (showOverlay)
                        Container(
                          color: Colors.black54,
                          alignment: Alignment.center,
                          child: Text(
                            '+${count - 3}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _resolveUrl(String urlOrPath) {
    if (urlOrPath.startsWith('/uploads')) {
      return '${AppConfig.instance.apiUrl}$urlOrPath';
    }
    return urlOrPath;
  }

  Widget _buildImage(String urlOrPath, {bool useThumbnail = true}) {
    final resolved = _resolveUrl(urlOrPath);
    final isNetworkUrl =
        resolved.startsWith('http') || resolved.startsWith('blob:');

    if (kIsWeb) {
      return Image.network(
        resolved,
        fit: useThumbnail ? BoxFit.cover : BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        filterQuality: FilterQuality.none,
        isAntiAlias: false,
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        errorBuilder: (_, _, _) => Container(
          color: AppColors.surfaceVariant,
          child: const Icon(Icons.broken_image, color: AppColors.textHint),
        ),
      );
    }

    if (!isNetworkUrl) {
      return Image.file(
        File(urlOrPath),
        fit: useThumbnail ? BoxFit.cover : BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
      );
    }

    if (!useThumbnail) {
      return Image.network(
        resolved,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
      );
    }

    return ThumbnailImage(
      imageUrl: resolved,
      size: 150, // Grid thumbnail size
    );
  }
}
