import 'package:flutter/material.dart';
import '../../../core/theme/app_interaction.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/theme_color_presets.dart';
import '../../../shared/widgets/tappable_scale.dart';
import '../data/search_result.dart';
import 'chat_avatar.dart';
import 'highlighted_snippet.dart';

class SearchResultTile extends StatefulWidget {
  final SearchResult result;
  final VoidCallback onTap;

  const SearchResultTile({
    super.key,
    required this.result,
    required this.onTap,
  });

  @override
  State<SearchResultTile> createState() => _SearchResultTileState();
}

class _SearchResultTileState extends State<SearchResultTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final result = widget.result;
    final canHover = prefersDesktopUi(context);
    final hoverColor = canHover && _isHovered
        ? palette.surfaceVariant.withValues(alpha: 0.5)
        : Colors.transparent;
    final borderColor = canHover && _isHovered
        ? palette.surfaceVariant.withValues(alpha: 0.95)
        : Colors.transparent;

    final child = RepaintBoundary(
      child: AnimatedContainer(
        duration: AppMotion.instant,
        curve: AppMotion.standardCurve,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: hoverColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            ChatAvatar(
              radius: 22,
              displayName: result.convType == 'GROUP'
                  ? result.convName
                  : (result.senderName ?? 'Chat'),
              imageUrl: result.convAvatar,
              isGroup: result.convType == 'GROUP',
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          (result.convType == 'GROUP'
                                  ? result.convName
                                  : result.senderName) ??
                              'Chat',
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatTime(result.createdAt),
                        style: TextStyle(color: palette.textHint, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (result.convType == 'GROUP' && result.senderName != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 1),
                      child: Text(
                        '${result.senderName}:',
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  HighlightedSnippet(snippet: result.snippet),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: canHover ? (_) => setState(() => _isHovered = true) : null,
      onExit: canHover ? (_) => setState(() => _isHovered = false) : null,
      child: TappableScale(
        onTap: widget.onTap,
        scaleDown: 0.99,
        hoverScale: 1.003,
        duration: AppMotion.instant,
        child: child,
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inHours < 1) return '${diff.inMinutes}p';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.day}/${dt.month}';
  }
}
