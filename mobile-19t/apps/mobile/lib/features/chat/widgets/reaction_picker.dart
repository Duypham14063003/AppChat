import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/tappable_scale.dart';

const _quickEmojis = ['👍', '❤️', '😂', '😮', '😢', '🔥'];

class ReactionPicker extends StatefulWidget {
  final Offset anchorPosition;
  final double anchorWidth;
  final void Function(String emoji) onEmojiSelected;
  final VoidCallback onDismiss;

  const ReactionPicker({
    super.key,
    required this.anchorPosition,
    required this.anchorWidth,
    required this.onEmojiSelected,
    required this.onDismiss,
  });

  @override
  State<ReactionPicker> createState() => _ReactionPickerState();
}

class _ReactionPickerState extends State<ReactionPicker>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _emojiAnimations;
  bool _showFullPicker = false;
  // PLACEHOLDER_FLY_ANIMATION

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 280),
      vsync: this,
    );

    _emojiAnimations = List.generate(7, (i) {
      final start = (i * 18) / 280;
      final end = (start + 190 / 280).clamp(0.0, 1.0);
      return TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.04), weight: 58),
        TweenSequenceItem(tween: Tween(begin: 1.04, end: 1.0), weight: 42),
      ]).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(start, end, curve: AppMotion.enterCurve),
        ),
      );
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSelect(String emoji) {
    widget.onEmojiSelected(emoji);
  }

  void _openFullPicker() {
    _controller.forward(from: 0);
    setState(() => _showFullPicker = true);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dismiss backdrop
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onDismiss,
            behavior: HitTestBehavior.opaque,
            child: const ColoredBox(color: Colors.transparent),
          ),
        ),

        // Quick picker
        if (!_showFullPicker)
          Positioned(
            left: _pickerLeft(context),
            top: widget.anchorPosition.dy - 56,
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: _controller,
                curve: AppMotion.standardCurve,
              ),
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0, 0.08),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: _controller,
                        curve: AppMotion.enterCurve,
                      ),
                    ),
                child: Material(
                  elevation: 10,
                  borderRadius: BorderRadius.circular(28),
                  color: AppColors.surface,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int i = 0; i < _quickEmojis.length; i++)
                          ScaleTransition(
                            scale: _emojiAnimations[i],
                            child: _EmojiButton(
                              emoji: _quickEmojis[i],
                              onTap: () => _onSelect(_quickEmojis[i]),
                            ),
                          ),
                        ScaleTransition(
                          scale: _emojiAnimations[6],
                          child: _EmojiButton(
                            emoji: '⋯',
                            onTap: _openFullPicker,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

        if (_showFullPicker)
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: _controller,
                curve: AppMotion.standardCurve,
              ),
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0, 0.06),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: _controller,
                        curve: AppMotion.enterCurve,
                      ),
                    ),
                child: Material(
                  elevation: 10,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: SizedBox(
                    height: 300,
                    child: EmojiPicker(
                      onEmojiSelected: (_, emoji) {
                        _onSelect(emoji.emoji);
                      },
                      config: const Config(
                        height: 300,
                        emojiViewConfig: EmojiViewConfig(
                          columns: 8,
                          emojiSizeMax: 28,
                        ),
                        categoryViewConfig: CategoryViewConfig(
                          indicatorColor: AppColors.gold,
                          iconColorSelected: AppColors.gold,
                        ),
                        searchViewConfig: SearchViewConfig(
                          hintText: 'Tìm emoji...',
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  double _pickerLeft(BuildContext context) {
    const pickerWidth = 320.0;
    final screenWidth = MediaQuery.of(context).size.width;
    // Center on anchor, but clamp to screen
    final ideal =
        widget.anchorPosition.dx + (widget.anchorWidth / 2) - (pickerWidth / 2);
    return ideal.clamp(8.0, screenWidth - pickerWidth - 8);
  }
}

class _EmojiButton extends StatelessWidget {
  final String emoji;
  final VoidCallback onTap;

  const _EmojiButton({required this.emoji, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TappableScale(
      onTap: onTap,
      scaleDown: 0.9,
      duration: AppMotion.instant,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(emoji, style: const TextStyle(fontSize: 24)),
      ),
    );
  }
}
