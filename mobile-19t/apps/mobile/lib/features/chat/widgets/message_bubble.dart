import 'dart:convert';
import 'dart:math' show min;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/app_config.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/app_interaction.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_color_presets.dart';
import '../data/encrypted_message_adapter.dart';
import '../models/link_preview.dart';
import 'album_grid.dart';
import 'chat_avatar.dart';
import 'link_preview_bubble.dart';
import 'video_thumbnail_widget.dart';
import 'voice_bubble.dart';

const double _messageBubbleFontSize = 15;
const double _messageBubbleLineHeight = 1.8;
const StrutStyle _messageBubbleStrutStyle = StrutStyle(
  fontSize: _messageBubbleFontSize,
  height: _messageBubbleLineHeight,
  forceStrutHeight: true,
);

@visibleForTesting
double maxMessageBubbleWidthForAvailableWidth(double availableWidth) {
  if (availableWidth >= 720) {
    return min(availableWidth * 0.68, 640);
  }
  return min(availableWidth * 0.75, 480);
}

@visibleForTesting
String formatChatBubbleTimestamp(DateTime messageTime, {DateTime? now}) {
  final localNow = now ?? DateTime.now();
  final isSameDay =
      messageTime.year == localNow.year &&
      messageTime.month == localNow.month &&
      messageTime.day == localNow.day;
  final timePart =
      '${messageTime.hour.toString().padLeft(2, '0')}:${messageTime.minute.toString().padLeft(2, '0')}';

  if (isSameDay) {
    return timePart;
  }

  final datePart =
      '${messageTime.day.toString().padLeft(2, '0')}/${messageTime.month.toString().padLeft(2, '0')}';
  if (messageTime.year == localNow.year) {
    return '$datePart $timePart';
  }

  final yearPart = messageTime.year.toString().padLeft(4, '0');
  return '$datePart/$yearPart $timePart';
}

class MessageBubble extends StatefulWidget {
  final LocalMessage message;
  final bool isMine;
  final String? senderName;
  final String? senderAvatar;
  final Color? senderNameColor;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final bool showAvatar;
  final bool showSenderName;
  final bool isHighlighted;
  final void Function(List<String> urls, int index)? onImageTap;
  final void Function(String videoUrl)? onVideoTap;
  final String? replyToSenderName;
  final String? replyToContent;
  final String? replyToType;
  final Color? replyToSenderColor;
  final VoidCallback? onReplyTap;
  final bool isBookmarked;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.senderName,
    this.senderAvatar,
    this.senderNameColor,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
    this.showAvatar = true,
    this.showSenderName = true,
    this.isHighlighted = false,
    this.onImageTap,
    this.onVideoTap,
    this.replyToSenderName,
    this.replyToContent,
    this.replyToType,
    this.replyToSenderColor,
    this.onReplyTap,
    this.isBookmarked = false,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _highlightController;
  late Animation<double> _highlightAnimation;
  Map<String, dynamic>? _cachedMetadata;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _highlightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _highlightAnimation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 160),
          TweenSequenceItem(tween: ConstantTween(1), weight: 760),
          TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 480),
        ]).animate(
          CurvedAnimation(
            parent: _highlightController,
            curve: AppMotion.standardCurve,
          ),
        );
    _cachedMetadata = _parseMetadata();
  }

  @override
  void didUpdateWidget(covariant MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isHighlighted && !oldWidget.isHighlighted) {
      _highlightController.forward(from: 0);
    }
    if (widget.message.metadata != oldWidget.message.metadata) {
      _cachedMetadata = _parseMetadata();
    }
  }

  @override
  void dispose() {
    _highlightController.dispose();
    super.dispose();
  }

  bool get _isMediaType =>
      widget.message.type == 'image' || widget.message.type == 'album';

  bool get _isVoiceType => widget.message.type == 'voice';

  bool get _isVideoType => widget.message.type == 'video';

  bool get _isFileType => widget.message.type == 'file';

  bool get _isRecalled => widget.message.deletedAt != null;

  bool get _isEdited =>
      widget.message.editedAt != null && widget.message.deletedAt == null;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final topMargin = widget.isFirstInGroup ? 8.0 : 1.0;
    final shouldShowIncomingSenderChrome =
        !widget.isMine && (widget.showAvatar || widget.showSenderName);

    Widget bubble;
    if (shouldShowIncomingSenderChrome) {
      bubble = Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.only(top: topMargin, bottom: 1),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (widget.showAvatar && widget.isLastInGroup)
                ChatAvatar(
                  radius: 14,
                  displayName: widget.senderName ?? '?',
                  imageUrl: widget.senderAvatar,
                )
              else
                const SizedBox(width: 28),
              const SizedBox(width: 6),
              Flexible(
                child: _buildBubble(
                  context,
                  showName: widget.showSenderName && widget.isFirstInGroup,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      bubble = Align(
        alignment: widget.isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.only(top: topMargin, bottom: 1),
          child: _buildBubble(context),
        ),
      );
    }

    if (widget.isHighlighted) {
      return AnimatedBuilder(
        animation: _highlightAnimation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              color: palette.primary.withValues(
                alpha: 0.15 * _highlightAnimation.value,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: child,
          );
        },
        child: bubble,
      );
    }

    return bubble;
  }

  Map<String, dynamic>? _parseMetadata() {
    if (widget.message.metadata == null) return null;
    try {
      return jsonDecode(widget.message.metadata!) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  List<String> _extractImageUrls(Map<String, dynamic>? meta) {
    if (meta == null) return [];
    if (widget.message.type == 'album') {
      final images = meta['images'] as List?;
      if (images == null) return [];
      return images
          .map((img) => (img as Map<String, dynamic>)['url'] as String? ?? '')
          .where((u) => u.isNotEmpty)
          .toList();
    }
    // Single image
    final url = meta['url'] as String?;
    if (url != null && url.isNotEmpty) return [url];
    // Check localPaths for optimistic UI
    final localPaths = meta['localPaths'] as List?;
    if (localPaths != null) return localPaths.cast<String>();
    return [];
  }

  Widget _buildBubble(BuildContext context, {bool showName = false}) {
    final palette = context.appPalette;
    final canHover = prefersDesktopUi(context);
    final tailRadius = widget.isLastInGroup ? 4.0 : 12.0;
    final meta = _cachedMetadata;
    final isMedia = _isMediaType;
    final isVideo = _isVideoType;
    final isFile = _isFileType;
    final imageUrls = isMedia ? _extractImageUrls(meta) : <String>[];
    final caption = (isMedia || isVideo)
        ? (meta?['caption'] as String? ?? widget.message.content)
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth =
            constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        final borderRadius = BorderRadius.only(
          topLeft: Radius.circular(
            widget.isFirstInGroup || widget.isMine ? 16 : 4,
          ),
          topRight: Radius.circular(
            widget.isFirstInGroup || !widget.isMine ? 16 : 4,
          ),
          bottomLeft: Radius.circular(widget.isMine ? 16 : tailRadius),
          bottomRight: Radius.circular(widget.isMine ? tailRadius : 16),
        );

        return MouseRegion(
          cursor: canHover ? SystemMouseCursors.click : MouseCursor.defer,
          onEnter: canHover ? (_) => setState(() => _isHovered = true) : null,
          onExit: canHover ? (_) => setState(() => _isHovered = false) : null,
          child: RepaintBoundary(
            child: AnimatedContainer(
              duration: AppMotion.instant,
              curve: AppMotion.standardCurve,
              constraints: BoxConstraints(
                minWidth: 120,
                maxWidth: maxMessageBubbleWidthForAvailableWidth(
                  availableWidth,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: widget.isMine
                    ? (palette.isLight ? palette.primaryPale : palette.primary)
                    : palette.card,
                borderRadius: borderRadius,
                border: canHover && _isHovered
                    ? Border.all(
                        color: widget.isMine
                            ? palette.primary.withValues(alpha: 0.18)
                            : palette.surfaceVariant.withValues(alpha: 0.92),
                      )
                    : null,
                boxShadow: canHover && _isHovered
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: palette.isLight ? 0.045 : 0.15,
                          ),
                          blurRadius: 14,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : const [],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_isRecalled) _buildForwardHeader(),
                  _buildQuotedReply(),
                  if (showName && widget.senderName != null)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 12,
                        top: 8,
                        bottom: 2,
                      ),
                      child: Text(
                        widget.senderName!,
                        style: TextStyle(
                          color:
                              widget.senderNameColor ?? palette.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (_isRecalled) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tin nhắn đã được thu hồi',
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 15,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 2),
                          _buildTimestampRow(),
                        ],
                      ),
                    ),
                  ] else if (isMedia && imageUrls.isNotEmpty) ...[
                    AlbumGrid(
                      imageUrls: imageUrls,
                      onTap: (index) =>
                          widget.onImageTap?.call(imageUrls, index),
                    ),
                    if (caption != null && caption.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                        child: Text(
                          caption,
                          strutStyle: _messageBubbleStrutStyle,
                          style: _messageTextStyle(palette.textPrimary),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                      child: _buildTimestampRow(),
                    ),
                  ] else if (isVideo && meta != null) ...[
                    VideoThumbnailWidget(
                      thumbnailUrl: meta['thumbnail'] as String?,
                      duration: (meta['duration'] as num?)?.toInt() ?? 0,
                      onTap: () {
                        final url = meta['url'] as String?;
                        if (url != null) widget.onVideoTap?.call(url);
                      },
                    ),
                    if (caption != null && caption.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                        child: Text(
                          caption,
                          strutStyle: _messageBubbleStrutStyle,
                          style: _messageTextStyle(palette.textPrimary),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                      child: _buildTimestampRow(),
                    ),
                  ] else if (_isVoiceType) ...[
                    VoiceBubble(message: widget.message, isMine: widget.isMine),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: _buildTimestampRow(),
                    ),
                  ] else if (isFile && meta != null) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                      child: _buildFileAttachment(meta),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: _buildTimestampRow(),
                    ),
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildRichText(
                            (widget.message.content?.isNotEmpty ?? false)
                                ? widget.message.content!
                                : encryptedMessagePreviewPlaceholder,
                          ),
                          if (_hasLinkPreview(meta))
                            LinkPreviewBubble(
                              preview: LinkPreview.fromJson(
                                meta!['linkPreview'] as Map<String, dynamic>,
                              ),
                            ),
                          const SizedBox(height: 2),
                          _buildTimestampRow(),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildForwardHeader() {
    final palette = context.appPalette;
    final forwardedFromId = widget.message.forwardedFromId;
    if (forwardedFromId == null) return const SizedBox.shrink();

    final sender = widget.message.forwardedFromSender;
    final text = sender != null
        ? '↪ Chuyển tiếp từ $sender'
        : '↪ Tin nhắn chuyển tiếp';

    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 8, right: 12, bottom: 2),
      child: Text(
        text,
        style: TextStyle(
          color: widget.isMine
              ? (palette.isLight ? palette.primaryDark : Colors.white70)
              : palette.primary,
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildQuotedReply() {
    final palette = context.appPalette;
    if (widget.replyToSenderName == null) return const SizedBox.shrink();

    String previewText;
    switch (widget.replyToType) {
      case 'image':
        previewText = 'Ảnh';
      case 'album':
        previewText = 'Ảnh';
      case 'video':
        previewText = 'Video';
      case 'voice':
        previewText = 'Tin nhắn thoại';
      case 'file':
        previewText = widget.replyToContent ?? 'Tệp đính kèm';
      default:
        previewText = widget.replyToContent ?? '';
    }

    return GestureDetector(
      onTap: widget.onReplyTap,
      child: Container(
        margin: const EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: widget.isMine
              ? (palette.isLight
                    ? palette.primary.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.15))
              : palette.surfaceVariant.withValues(
                  alpha: palette.isLight ? 1 : 0.6,
                ),
          border: Border(
            left: BorderSide(
              color: widget.isMine
                  ? (palette.isLight ? palette.primary : Colors.white)
                  : palette.primary,
              width: 4,
            ),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.replyToSenderName!,
              style: TextStyle(
                color: widget.isMine
                    ? (palette.isLight ? palette.primaryDark : Colors.white)
                    : (widget.replyToSenderColor ?? palette.primary),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              previewText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: widget.isMine
                    ? (palette.isLight ? palette.textSecondary : Colors.white70)
                    : palette.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimestampRow() {
    final palette = context.appPalette;
    final hintColor = widget.isMine && !palette.isLight
        ? Colors.white70
        : palette.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatTime(widget.message.createdAt),
          style: TextStyle(color: hintColor, fontSize: 11),
        ),
        if (_isEdited) ...[
          const SizedBox(width: 4),
          Text('Đã sửa', style: TextStyle(color: hintColor, fontSize: 11)),
        ],
        if (widget.isBookmarked) ...[
          const SizedBox(width: 4),
          Icon(
            Icons.bookmark,
            size: 13,
            color: widget.isMine
                ? (palette.isLight ? palette.primary : Colors.white)
                : palette.primary,
          ),
        ],
        if (widget.isMine) ...[
          const SizedBox(width: 4),
          _buildStatusIcon(palette),
        ],
      ],
    );
  }

  Widget _buildStatusIcon(AppThemePalette palette) {
    final defaultColor = palette.isLight
        ? palette.textSecondary
        : Colors.white70;
    switch (widget.message.status) {
      case 'pending':
        return Icon(Icons.access_time, size: 14, color: defaultColor);
      // case 'sent':
      //   return Icon(Icons.check, size: 14, color: defaultColor);
      // case 'delivered':
      //   return Icon(Icons.done_all, size: 14, color: defaultColor);
      // case 'read':
      //   return Icon(Icons.done_all, size: 14, color: readColor);
      case 'failed':
        return const Icon(
          Icons.error_outline,
          size: 14,
          color: AppColors.danger,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  String _formatTime(DateTime dateTime) {
    return formatChatBubbleTimestamp(dateTime);
  }

  bool _hasLinkPreview(Map<String, dynamic>? meta) {
    if (meta == null) return false;
    final lp = meta['linkPreview'];
    return lp != null && lp is Map<String, dynamic>;
  }

  static final _urlRegex = RegExp(r'https?://[^\s]+');

  Widget _buildRichText(String text) {
    final palette = context.appPalette;
    final textColor = widget.isMine && !palette.isLight
        ? Colors.white
        : palette.textPrimary;
    final linkColor = widget.isMine
        ? (palette.isLight ? palette.primaryDark : Colors.white)
        : palette.primary;
    // Check for mentions first
    final meta = _cachedMetadata;
    final mentions = _renderableMentions(text, _parseMentions(meta));
    if (mentions.isNotEmpty) {
      return SelectableText.rich(
        _buildMentionText(text, mentions),
        strutStyle: _messageBubbleStrutStyle,
        showCursor: false,
        enableInteractiveSelection: true,
      );
    }

    final matches = _urlRegex.allMatches(text).toList();
    if (matches.isEmpty) {
      return SelectableText(
        text,
        strutStyle: _messageBubbleStrutStyle,
        style: _messageTextStyle(textColor),
        showCursor: false,
        enableInteractiveSelection: true,
      );
    }

    final spans = <TextSpan>[];
    int currentIndex = 0;

    for (final match in matches) {
      if (match.start > currentIndex) {
        spans.add(TextSpan(text: text.substring(currentIndex, match.start)));
      }
      final url = match.group(0)!;
      spans.add(
        TextSpan(
          text: url,
          style: _messageTextStyle(linkColor).copyWith(
            decoration: TextDecoration.underline,
            decorationColor: linkColor,
          ),
          recognizer: TapGestureRecognizer()..onTap = () => _openUrl(url),
        ),
      );
      currentIndex = match.end;
    }

    if (currentIndex < text.length) {
      spans.add(TextSpan(text: text.substring(currentIndex)));
    }

    return SelectableText.rich(
      TextSpan(style: _messageTextStyle(textColor), children: spans),
      strutStyle: _messageBubbleStrutStyle,
      showCursor: false,
      enableInteractiveSelection: true,
    );
  }

  List<Map<String, dynamic>> _parseMentions(Map<String, dynamic>? meta) {
    if (meta == null) return [];
    final mentions = meta['mentions'];
    if (mentions is! List) return [];
    try {
      return mentions
          .map((m) => m as Map<String, dynamic>)
          .where(
            (m) =>
                m['offset'] is int &&
                m['length'] is int &&
                m['offset'] >= 0 &&
                m['length'] > 0,
          )
          .toList()
        ..sort((a, b) => (a['offset'] as int).compareTo(b['offset'] as int));
    } catch (_) {
      return [];
    }
  }

  List<Map<String, dynamic>> _renderableMentions(
    String text,
    List<Map<String, dynamic>> mentions,
  ) {
    final renderable = <Map<String, dynamic>>[];
    var currentIndex = 0;

    for (final mention in mentions) {
      final offset = mention['offset'] as int;
      final length = mention['length'] as int;
      final end = offset + length;
      if (offset < currentIndex || offset >= text.length || end > text.length) {
        continue;
      }
      renderable.add(mention);
      currentIndex = end;
    }

    return renderable;
  }

  TextSpan _buildMentionText(String text, List<Map<String, dynamic>> mentions) {
    final palette = context.appPalette;
    final textColor = widget.isMine && !palette.isLight
        ? Colors.white
        : palette.textPrimary;
    final mentionColor = widget.isMine
        ? (palette.isLight ? palette.primaryDark : Colors.white)
        : palette.primary;
    final spans = <InlineSpan>[];
    int currentIndex = 0;

    for (final mention in mentions) {
      final offset = mention['offset'] as int;
      final length = mention['length'] as int;
      final end = offset + length;

      // Add normal text before mention
      if (offset > currentIndex) {
        spans.add(TextSpan(text: text.substring(currentIndex, offset)));
      }

      // Add styled mention span
      spans.add(
        TextSpan(
          text: text.substring(offset, end),
          style: _messageTextStyle(mentionColor, fontWeight: FontWeight.w700),
        ),
      );

      currentIndex = end;
    }

    // Add remaining text
    if (currentIndex < text.length) {
      spans.add(TextSpan(text: text.substring(currentIndex)));
    }

    return TextSpan(style: _messageTextStyle(textColor), children: spans);
  }

  TextStyle _messageTextStyle(Color color, {FontWeight? fontWeight}) {
    return TextStyle(
      color: color,
      fontSize: _messageBubbleFontSize,
      height: _messageBubbleLineHeight,
      fontWeight: fontWeight,
    );
  }

  Widget _buildFileAttachment(Map<String, dynamic> meta) {
    final palette = context.appPalette;
    final originalName =
        ((meta['originalName'] as String?)?.trim().isNotEmpty ?? false)
        ? meta['originalName'] as String
        : ((widget.message.content?.trim().isNotEmpty ?? false)
              ? widget.message.content!
              : 'Tệp đính kèm');
    final mimeType = meta['mimeType'] as String? ?? '';
    final size = (meta['size'] as num?)?.toInt();
    final fileUrl = meta['url'] as String?;
    final localPath = meta['localPath'] as String?;
    final subtitleParts = <String>[
      if (mimeType.isNotEmpty) _fileLabelForMimeType(mimeType, originalName),
      if (size != null && size > 0) _formatFileSize(size),
    ];

    return GestureDetector(
      onTap: () => _openAttachment(fileUrl, localPath: localPath),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.isMine
              ? (palette.isLight
                    ? Colors.white.withValues(alpha: 0.72)
                    : Colors.black.withValues(alpha: 0.16))
              : palette.surfaceVariant.withValues(
                  alpha: palette.isLight ? 0.78 : 0.5,
                ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.isMine
                ? palette.primary.withValues(alpha: 0.18)
                : palette.textHint.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _fileAccentColor(mimeType, originalName),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(
                _fileIconForMimeType(mimeType, originalName),
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    originalName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _messageTextStyle(
                      widget.isMine && !palette.isLight
                          ? Colors.white
                          : palette.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitleParts.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitleParts.join(' • '),
                      style: TextStyle(
                        color: widget.isMine && !palette.isLight
                            ? Colors.white70
                            : palette.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.open_in_new_rounded,
              size: 18,
              color: widget.isMine && !palette.isLight
                  ? Colors.white70
                  : palette.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  String _resolveAttachmentUrl(String urlOrPath) {
    if (urlOrPath.startsWith('/uploads')) {
      return '${AppConfig.instance.apiUrl}$urlOrPath';
    }
    return urlOrPath;
  }

  String _fileLabelForMimeType(String mimeType, String filename) {
    final ext = _fileExtension(filename).toUpperCase();
    if (ext.isNotEmpty) return ext;
    final slashIndex = mimeType.indexOf('/');
    if (slashIndex >= 0 && slashIndex < mimeType.length - 1) {
      return mimeType.substring(slashIndex + 1).toUpperCase();
    }
    return 'FILE';
  }

  String _fileExtension(String filename) {
    if (!filename.contains('.')) return '';
    return filename.split('.').last.toLowerCase();
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(bytes < 10 * 1024 ? 1 : 0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(bytes < 10 * 1024 * 1024 ? 1 : 0)} MB';
  }

  Color _fileAccentColor(String mimeType, String filename) {
    final ext = _fileExtension(filename);
    if (mimeType.contains('pdf') || ext == 'pdf') {
      return const Color(0xFFD84315);
    }
    if (mimeType.contains('word') ||
        mimeType.contains('document') ||
        ext == 'doc' ||
        ext == 'docx') {
      return const Color(0xFF1565C0);
    }
    if (mimeType.contains('sheet') ||
        mimeType.contains('excel') ||
        ext == 'xls' ||
        ext == 'xlsx' ||
        ext == 'csv') {
      return const Color(0xFF2E7D32);
    }
    if (mimeType.contains('presentation') ||
        mimeType.contains('powerpoint') ||
        ext == 'ppt' ||
        ext == 'pptx') {
      return const Color(0xFFEF6C00);
    }
    if (mimeType.contains('zip') ||
        mimeType.contains('rar') ||
        ext == 'zip' ||
        ext == 'rar' ||
        ext == '7z' ||
        ext == 'tar' ||
        ext == 'gz') {
      return const Color(0xFF6D4C41);
    }
    if (mimeType.startsWith('text/') ||
        ext == 'txt' ||
        ext == 'md' ||
        ext == 'rtf' ||
        ext == 'json' ||
        ext == 'xml' ||
        ext == 'yaml' ||
        ext == 'yml' ||
        ext == 'toml' ||
        ext == 'ini' ||
        ext == 'log') {
      return const Color(0xFF546E7A);
    }
    if (mimeType.startsWith('image/') ||
        ext == 'psd' ||
        ext == 'fig' ||
        ext == 'sketch' ||
        ext == 'xd' ||
        ext == 'ai' ||
        ext == 'svg') {
      return const Color(0xFF8E24AA);
    }
    if (mimeType.startsWith('audio/')) return const Color(0xFF00897B);
    if (mimeType.startsWith('video/')) return const Color(0xFFC2185B);
    if (ext == 'apk' || ext == 'ipa' || ext == 'aab' || ext == 'exe') {
      return const Color(0xFF3949AB);
    }
    return const Color(0xFF546E7A);
  }

  IconData _fileIconForMimeType(String mimeType, String filename) {
    final ext = _fileExtension(filename);
    if (mimeType.contains('pdf') || ext == 'pdf') {
      return Icons.picture_as_pdf_rounded;
    }
    if (mimeType.contains('word') || ext == 'doc' || ext == 'docx') {
      return Icons.description_rounded;
    }
    if (mimeType.contains('sheet') || ext == 'xls' || ext == 'xlsx') {
      return Icons.table_chart_rounded;
    }
    if (mimeType.contains('presentation') || ext == 'ppt' || ext == 'pptx') {
      return Icons.slideshow_rounded;
    }
    if (ext == 'zip' || ext == 'rar') {
      return Icons.folder_zip_rounded;
    }
    if (ext == 'txt' ||
        ext == 'md' ||
        ext == 'rtf' ||
        ext == 'csv' ||
        ext == 'json' ||
        ext == 'xml' ||
        ext == 'yaml' ||
        ext == 'yml' ||
        ext == 'toml' ||
        ext == 'ini' ||
        ext == 'log') {
      return Icons.article_rounded;
    }
    if (mimeType.startsWith('image/') ||
        ext == 'psd' ||
        ext == 'fig' ||
        ext == 'sketch' ||
        ext == 'xd' ||
        ext == 'ai' ||
        ext == 'svg') {
      return Icons.image_rounded;
    }
    if (mimeType.startsWith('audio/')) return Icons.audio_file_rounded;
    if (mimeType.startsWith('video/')) return Icons.video_file_rounded;
    if (ext == 'apk' || ext == 'ipa' || ext == 'aab' || ext == 'exe') {
      return Icons.android_rounded;
    }
    return Icons.attach_file_rounded;
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(_resolveAttachmentUrl(url));
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Silently fail
    }
  }

  Future<void> _openAttachment(String? url, {String? localPath}) async {
    Uri? uri;
    if (localPath != null &&
        localPath.isNotEmpty &&
        !localPath.startsWith('blob:')) {
      uri = Uri.file(localPath);
    } else if (url != null && url.isNotEmpty) {
      uri = Uri.tryParse(_resolveAttachmentUrl(url));
    }
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Silently fail
    }
  }
}
