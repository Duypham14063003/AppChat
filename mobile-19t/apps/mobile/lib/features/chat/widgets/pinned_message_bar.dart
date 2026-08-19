import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/encrypted_message_adapter.dart';
import '../providers/chat_providers.dart';
import '../../../core/theme/theme_color_presets.dart';

class PinnedMessageBar extends ConsumerStatefulWidget {
  final String conversationId;
  final VoidCallback onTap;

  const PinnedMessageBar({
    super.key,
    required this.conversationId,
    required this.onTap,
  });

  @override
  ConsumerState<PinnedMessageBar> createState() => _PinnedMessageBarState();
}

class _PinnedMessageBarState extends ConsumerState<PinnedMessageBar> {
  int _cycleIndex = 0;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final barColor = palette.isLight ? Colors.white : palette.surface;
    final borderColor = palette.isLight
        ? const Color(0xFFDCE4EE)
        : palette.surfaceVariant;
    final pinsAsync = ref.watch(pinnedMessagesProvider(widget.conversationId));
    final pins = pinsAsync.valueOrNull ?? [];
    if (pins.isEmpty) return const SizedBox.shrink();

    final safeIndex = _cycleIndex % pins.length;
    final current = pins[safeIndex];
    final senderName = current.senderName ?? '';
    final content =
        current.messageContent ?? encryptedMessagePreviewPlaceholder;

    return GestureDetector(
      onTap: () {
        setState(() => _cycleIndex = (safeIndex + 1) % pins.length);
        widget.onTap();
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: barColor,
            border: Border(
              bottom: BorderSide(color: borderColor, width: 1),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.push_pin, size: 16, color: palette.primary),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: palette.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${safeIndex + 1}/${pins.length}',
                  style: TextStyle(
                    color: palette.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  senderName.isNotEmpty ? '$senderName: $content' : content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, size: 16, color: palette.textHint),
            ],
          ),
        ),
      ),
    );
  }
}
