import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/theme_color_presets.dart';

/// An avatar widget with Hero animation support for smooth transitions between screens.
///
/// Automatically handles network image loading with caching and provides a fallback
/// icon when no image is available.
///
/// Example:
/// ```dart
/// // In source screen (chat list)
/// HeroAvatar(
///   tag: 'avatar_${userId}',
///   imageUrl: userAvatarUrl,
///   radius: 24,
/// )
///
/// // In destination screen (chat detail)
/// HeroAvatar(
///   tag: 'avatar_${userId}', // Same tag!
///   imageUrl: userAvatarUrl,
///   radius: 40,
/// )
/// ```
class HeroAvatar extends StatelessWidget {
  const HeroAvatar({
    super.key,
    required this.tag,
    this.imageUrl,
    this.radius = 20.0,
    this.fallbackIcon = Icons.person,
    this.backgroundColor,
    this.fallbackIconColor,
    this.borderRadius,
  });

  /// Unique tag for Hero animation. Must be the same across screens.
  final String tag;

  /// URL of the avatar image
  final String? imageUrl;

  /// Radius of the circular avatar
  final double radius;

  /// Icon to show when imageUrl is null
  final IconData fallbackIcon;

  /// Background color for the avatar
  final Color? backgroundColor;

  /// Icon color for fallback state
  final Color? fallbackIconColor;

  /// Custom border radius (overrides circular shape if provided)
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      // Prevent Hero from clipping during animation
      flightShuttleBuilder:
          (
            flightContext,
            animation,
            flightDirection,
            fromHeroContext,
            toHeroContext,
          ) {
            return Material(
              color: Colors.transparent,
              child: toHeroContext.widget,
            );
          },
      child: _buildAvatar(context),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    final palette = context.appPalette;
    final effectiveBackgroundColor = backgroundColor ?? palette.surfaceVariant;

    // Custom border radius
    if (borderRadius != null) {
      return Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          color: effectiveBackgroundColor,
        ),
        clipBehavior: Clip.antiAlias,
        child: _buildAvatarContent(context),
      );
    }

    // Circular avatar - wrap in ClipOval to ensure circular clipping
    return ClipOval(
      child: Container(
        width: radius * 2,
        height: radius * 2,
        color: effectiveBackgroundColor,
        child: _buildAvatarContent(context),
      ),
    );
  }

  Widget _buildAvatarContent(BuildContext context) {
    final palette = context.appPalette;
    final effectiveIconColor = fallbackIconColor ?? palette.primary;

    if (imageUrl == null || imageUrl!.isEmpty) {
      return Center(
        child: Icon(
          fallbackIcon,
          size: radius * 1.2,
          color: effectiveIconColor,
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl!,
      fit: BoxFit.cover,
      width: radius * 2,
      height: radius * 2,
      // Optimize memory usage
      memCacheWidth: (radius * 2 * 2).toInt(), // 2x for retina
      memCacheHeight: (radius * 2 * 2).toInt(),
      placeholder: (context, url) => Center(
        child: Icon(
          fallbackIcon,
          size: radius * 1.2,
          color: effectiveIconColor,
        ),
      ),
      errorWidget: (context, url, error) => Center(
        child: Icon(
          fallbackIcon,
          size: radius * 1.2,
          color: effectiveIconColor,
        ),
      ),
    );
  }
}
