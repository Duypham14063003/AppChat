import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class HighlightedSnippet extends StatelessWidget {
  final String snippet;
  final double fontSize;

  const HighlightedSnippet({
    super.key,
    required this.snippet,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    final spans = _parseSnippet(snippet);
    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: TextStyle(color: AppColors.textSecondary, fontSize: fontSize),
        children: spans,
      ),
    );
  }

  List<TextSpan> _parseSnippet(String text) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'<mark>(.*?)</mark>');
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          backgroundColor: AppColors.gold.withOpacity(0.3),
        ),
      ));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return spans;
  }
}
