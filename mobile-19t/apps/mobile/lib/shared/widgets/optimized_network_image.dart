import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Optimized image widget with memory-efficient caching
///
/// Automatically limits decoded image size to prevent memory bloat
/// and provides smooth loading transitions.
class OptimizedNetworkImage extends StatelessWidget {
  const OptimizedNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.fadeInDuration = const Duration(milliseconds: 150),
    this.memCacheWidth,
    this.memCacheHeight,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Duration fadeInDuration;
  final int? memCacheWidth;
  final int? memCacheHeight;

  @override
  Widget build(BuildContext context) {
    // Auto-calculate memory cache size based on display size
    final effectiveMemWidth = memCacheWidth ??
        (width != null ? (width! * 2).toInt() : 800); // 2x for retina
    final effectiveMemHeight = memCacheHeight ??
        (height != null ? (height! * 2).toInt() : 800);

    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: fadeInDuration,
      // Limit memory cache size - critical for performance
      memCacheWidth: effectiveMemWidth,
      memCacheHeight: effectiveMemHeight,
      // Also limit disk cache
      maxWidthDiskCache: effectiveMemWidth,
      maxHeightDiskCache: effectiveMemHeight,
      placeholder: (context, url) =>
          placeholder ??
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      errorWidget: (context, url, error) =>
          errorWidget ??
          Container(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Icon(
              Icons.broken_image,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
    );
  }
}

/// Thumbnail image for grids and lists
class ThumbnailImage extends StatelessWidget {
  const ThumbnailImage({
    super.key,
    required this.imageUrl,
    this.size = 100,
  });

  final String imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    return OptimizedNetworkImage(
      imageUrl: imageUrl,
      width: size,
      height: size,
      memCacheWidth: (size * 2).toInt(),
      memCacheHeight: (size * 2).toInt(),
      fit: BoxFit.cover,
    );
  }
}
