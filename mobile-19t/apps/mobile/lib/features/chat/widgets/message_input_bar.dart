import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart'
    show
        TargetPlatform,
        debugPrint,
        defaultTargetPlatform,
        kIsWeb,
        visibleForTesting;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_color_presets.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/clipboard_image_reader.dart';
import '../../../core/utils/web_attachment_preview.dart';
import 'package:super_clipboard/super_clipboard.dart';
import '../utils/chat_attachment_drop.dart';
import '../utils/chat_attachment_validation.dart' as chat_attachment_validation;
import '../models/link_preview.dart';
import '../providers/chat_drafts_provider.dart';
import 'link_preview_card.dart';
import 'reply_preview_bar.dart';
import 'web_chat_drop_target.dart';

const _uuid = Uuid();
const _maxRecordDuration = Duration(minutes: 5);
final _urlRegex = RegExp(r'https?://[^\s]+');
const List<Color> _composerMentionPalette = AppColors.senderColors;

@visibleForTesting
bool isSupportedChatDocumentSize(int sizeInBytes) {
  return chat_attachment_validation.isSupportedChatDocumentSize(sizeInBytes);
}

@visibleForTesting
bool isSupportedChatDocumentExtension(String filename) {
  return chat_attachment_validation.isSupportedChatDocumentExtension(filename);
}

@visibleForTesting
KeyEventResult handleComposerKeyEvent({
  required KeyEvent event,
  required bool isSending,
  required bool isShiftPressed,
  required VoidCallback insertNewline,
  required VoidCallback send,
}) {
  if (isSending) return KeyEventResult.handled;
  if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
    if (isShiftPressed) {
      insertNewline();
      return KeyEventResult.handled;
    }
    send();
    return KeyEventResult.handled;
  }
  return KeyEventResult.ignored;
}

@visibleForTesting
Color composerMentionColorForUserId(String userId) {
  if (userId.isEmpty) return _composerMentionPalette.first;
  final index = userId.hashCode.abs() % _composerMentionPalette.length;
  return _composerMentionPalette[index];
}

@visibleForTesting
ChatAttachmentDropResult classifyMessageInputBarDrop(
  List<ChatAttachmentDropCandidate> files,
) {
  return classifyChatAttachmentDrop(files);
}

@visibleForTesting
Future<ChatAttachmentDropResult> dispatchMessageInputBarDrop({
  required List<ChatAttachmentDropFile> files,
  required Future<bool> Function(XFile video) validateVideo,
  void Function(List<XFile> images)? onAttachImages,
  void Function(XFile video)? onAttachVideo,
  void Function(XFile file)? onAttachFile,
}) async {
  final result = classifyMessageInputBarDrop(files);
  if (!result.isAccepted) return result;

  final droppedFiles = files
      .map((file) => file.toXFile())
      .toList(growable: false);
  switch (result.kind!) {
    case ChatAttachmentDropKind.images:
      onAttachImages?.call(droppedFiles);
      break;
    case ChatAttachmentDropKind.video:
      final video = droppedFiles.single;
      final isValid = await validateVideo(video);
      if (isValid) {
        onAttachVideo?.call(video);
      }
      break;
    case ChatAttachmentDropKind.document:
      onAttachFile?.call(droppedFiles.single);
      break;
  }

  return result;
}

@visibleForTesting
List<Map<String, dynamic>> recalculateComposerMentions({
  required List<Map<String, dynamic>> mentions,
  required String oldText,
  required String newText,
}) {
  if (mentions.isEmpty || oldText == newText) {
    return mentions
        .map((mention) => Map<String, dynamic>.from(mention))
        .toList(growable: true);
  }

  final minLength = oldText.length < newText.length
      ? oldText.length
      : newText.length;
  var prefixLength = 0;
  while (prefixLength < minLength &&
      oldText[prefixLength] == newText[prefixLength]) {
    prefixLength++;
  }

  var oldSuffixStart = oldText.length;
  var newSuffixStart = newText.length;
  while (oldSuffixStart > prefixLength &&
      newSuffixStart > prefixLength &&
      oldText[oldSuffixStart - 1] == newText[newSuffixStart - 1]) {
    oldSuffixStart--;
    newSuffixStart--;
  }

  final oldChangedEnd = oldSuffixStart;
  final delta = newText.length - oldText.length;
  final updatedMentions = <Map<String, dynamic>>[];

  for (final mention in mentions) {
    final copy = Map<String, dynamic>.from(mention);
    final offset = copy['offset'] as int?;
    final length = copy['length'] as int?;
    if (offset == null || length == null || offset < 0 || length <= 0) {
      continue;
    }

    final end = offset + length;
    if (end < prefixLength) {
      updatedMentions.add(copy);
      continue;
    }

    if (offset >= oldChangedEnd) {
      final shiftedOffset = offset + delta;
      if (shiftedOffset >= 0 && shiftedOffset + length <= newText.length) {
        copy['offset'] = shiftedOffset;
        updatedMentions.add(copy);
      }
      continue;
    }
  }

  return updatedMentions.toList(growable: true);
}

class _MentionTextEditingController extends TextEditingController {
  List<Map<String, dynamic>> _mentions = const [];
  Color Function(String userId) _mentionColorResolver =
      composerMentionColorForUserId;

  void updateMentionStyles({
    required List<Map<String, dynamic>> mentions,
    required Color Function(String userId) mentionColorResolver,
  }) {
    _mentions = mentions
        .map((mention) => Map<String, dynamic>.from(mention))
        .toList(growable: false);
    _mentionColorResolver = mentionColorResolver;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? const TextStyle();
    if (_mentions.isEmpty || text.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: baseStyle,
        withComposing: withComposing,
      );
    }

    final spans = <InlineSpan>[];
    final sortedMentions =
        _mentions
            .where(
              (mention) =>
                  mention['offset'] is int &&
                  mention['length'] is int &&
                  (mention['offset'] as int) >= 0 &&
                  (mention['length'] as int) > 0,
            )
            .toList(growable: false)
          ..sort((a, b) => (a['offset'] as int).compareTo(b['offset'] as int));

    var currentIndex = 0;
    for (final mention in sortedMentions) {
      final offset = mention['offset'] as int;
      final length = mention['length'] as int;
      final end = offset + length;
      if (offset < currentIndex || end > text.length) {
        continue;
      }

      if (offset > currentIndex) {
        spans.add(TextSpan(text: text.substring(currentIndex, offset)));
      }

      final userId = mention['user_id'] as String? ?? '';
      spans.add(
        TextSpan(
          text: text.substring(offset, end),
          style: baseStyle.copyWith(
            color: _mentionColorResolver(userId),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      currentIndex = end;
    }

    if (currentIndex < text.length) {
      spans.add(TextSpan(text: text.substring(currentIndex)));
    }

    return TextSpan(style: baseStyle, children: spans);
  }
}

class MessageInputBar extends ConsumerStatefulWidget {
  final String conversationId;
  final FutureOr<void> Function(
    String text, {
    LinkPreview? linkPreview,
    List<Map<String, dynamic>>? mentions,
  })
  onSend;
  final void Function(List<XFile> images)? onAttachImages;
  final void Function(XFile video)? onAttachVideo;
  final void Function(XFile file)? onAttachFile;
  final void Function(String path, double duration, List<double> waveform)?
  onVoiceRecorded;
  final Future<LinkPreview?> Function(String url)? onFetchLinkPreview;
  final VoidCallback? onTyping;
  final bool isGroup;
  final Map<String, Map<String, String?>>? members;
  final String? currentUserId;
  final String? currentUserRole;
  final LocalMessage? replyTo;
  final LocalMessage? editingMessage;
  final String? replyToSenderName;
  final Color? replyToSenderColor;
  final VoidCallback? onCancelReply;
  final VoidCallback? onCancelEdit;

  const MessageInputBar({
    super.key,
    required this.conversationId,
    required this.onSend,
    this.onAttachImages,
    this.onAttachVideo,
    this.onAttachFile,
    this.onVoiceRecorded,
    this.onFetchLinkPreview,
    this.onTyping,
    this.isGroup = false,
    this.members,
    this.currentUserId,
    this.currentUserRole,
    this.replyTo,
    this.editingMessage,
    this.replyToSenderName,
    this.replyToSenderColor,
    this.onCancelReply,
    this.onCancelEdit,
  });

  @override
  ConsumerState<MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends ConsumerState<MessageInputBar> {
  late final _MentionTextEditingController _controller;
  final _focusNode = FocusNode();
  final _textFieldScrollController = ScrollController();
  bool _hasText = false;
  bool _showEmojiPicker = false;
  bool _isSending = false;

  // Recording state
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  List<double> _waveformSamples = [];
  double _cancelDragOffset = 0;
  bool _isCancelZone = false;
  Timer? _durationTimer;
  AudioRecorder? _recorder;
  StreamSubscription? _amplitudeSub;
  String? _recordingPath;

  // Link preview state
  Timer? _linkDebounceTimer;
  String? _currentUrl;
  LinkPreview? _currentPreview;
  bool _isLoadingPreview = false;
  WebChatDropVisualState _webDropState = WebChatDropVisualState.idle;
  String? _webDropMessage;

  // Typing throttle
  Timer? _typingThrottleTimer;

  // Mention state
  List<Map<String, dynamic>> _mentions = [];
  int? _mentionStartIndex;
  OverlayEntry? _overlayEntry;
  String _mentionQuery = '';
  String _previousText = '';
  // INPUT_BAR_CONTINUED

  @override
  void initState() {
    super.initState();
    _controller = _MentionTextEditingController();

    // Load draft if not editing a message
    if (widget.editingMessage == null) {
      final draft = ref.read(chatDraftsProvider)[widget.conversationId];
      if (draft != null && draft.isNotEmpty) {
        _controller.text = draft;
        _previousText = draft;
        _hasText = draft.trim().isNotEmpty;
      }
    }

    _controller.addListener(_onControllerChanged);
    _focusNode.addListener(_handleFocusNodeChange);
    if (widget.editingMessage != null) {
      final text = widget.editingMessage?.content ?? '';
      _controller.text = text;
      _previousText = text;
      _hasText = text.trim().isNotEmpty;
    }
    if (kIsWeb) {
      _focusNode.onKeyEvent = _handleKeyEvent;
      ClipboardEvents.instance?.registerPasteEventListener(_onWebPaste);
    }
    _syncComposerMentionStyling();
  }

  void _onControllerChanged() {
    if (widget.editingMessage == null) {
      ref
          .read(chatDraftsProvider.notifier)
          .setDraft(widget.conversationId, _controller.text);
    }
  }

  @override
  void didUpdateWidget(covariant MessageInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldEditingId = oldWidget.editingMessage?.id;
    final newEditingId = widget.editingMessage?.id;
    if (oldEditingId != newEditingId) {
      final text = widget.editingMessage?.content ?? '';
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      setState(() {
        _hasText = text.trim().isNotEmpty;
        _currentPreview = null;
        _currentUrl = null;
        _isLoadingPreview = false;
        _mentions = [];
        _mentionStartIndex = null;
        _mentionQuery = '';
        _previousText = text;
      });
      _syncComposerMentionStyling();
      if (widget.editingMessage != null) {
        _focusNode.requestFocus();
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _focusNode.removeListener(_handleFocusNodeChange);
    if (kIsWeb) {
      ClipboardEvents.instance?.unregisterPasteEventListener(_onWebPaste);
    }
    _controller.dispose();
    _focusNode.dispose();
    _textFieldScrollController.dispose();
    _durationTimer?.cancel();
    _amplitudeSub?.cancel();
    _recorder?.dispose();
    _linkDebounceTimer?.cancel();
    _typingThrottleTimer?.cancel();
    _dismissMentionOverlay();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (_controller.value.composing.isValid) {
      return KeyEventResult.ignored;
    }
    return handleComposerKeyEvent(
      event: event,
      isSending: _isSending,
      isShiftPressed: HardwareKeyboard.instance.isShiftPressed,
      insertNewline: () => _insertTextAtCursor('\n'),
      send: _send,
    );
  }

  void _handleFocusNodeChange() {
    if (_focusNode.hasFocus) return;
    _dismissTransientComposerUi();
  }

  void _dismissTransientComposerUi() {
    final shouldDismissMentionOverlay = _overlayEntry != null;
    final shouldResetMentionState =
        _mentionStartIndex != null || _mentionQuery.isNotEmpty;
    final shouldHideEmojiPicker = _showEmojiPicker;
    if (!shouldDismissMentionOverlay &&
        !shouldResetMentionState &&
        !shouldHideEmojiPicker) {
      return;
    }

    _dismissMentionOverlay();
    if (shouldResetMentionState || shouldHideEmojiPicker) {
      setState(() {
        if (shouldResetMentionState) {
          _mentionStartIndex = null;
          _mentionQuery = '';
        }
        if (shouldHideEmojiPicker) {
          _showEmojiPicker = false;
        }
      });
    }
  }

  /// Web paste handler — called by ClipboardEvents paste listener.
  void _onWebPaste(ClipboardReadEvent event) {
    if (!mounted || !_focusNode.hasFocus) return;
    _handleWebPaste(event);
  }

  Future<void> _handleWebPaste(ClipboardReadEvent event) async {
    try {
      final reader = await event.getClipboardReader();
      final xFile = await ClipboardImageReader.readImageFromReader(reader);
      if (xFile != null) {
        widget.onAttachImages?.call([xFile]);
        return;
      }
      // No image — read text from the reader
      final text = await reader.readValue(Formats.plainText);
      if (text != null && text.isNotEmpty) {
        _insertTextAtCursor(text);
      }
    } catch (e) {
      debugPrint('[MessageInputBar] Web paste failed: $e');
    }
  }

  /// Native paste handler — called by Actions/PasteTextIntent.
  Future<void> _handlePaste() async {
    try {
      final xFile = await ClipboardImageReader.readImageFromClipboard();
      if (xFile != null) {
        widget.onAttachImages?.call([xFile]);
        return;
      }
    } catch (e) {
      debugPrint('[MessageInputBar] Clipboard image read failed: $e');
    }
    // No image — perform default text paste
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null && data!.text!.isNotEmpty) {
      _insertTextAtCursor(data.text!);
    }
  }

  void _insertTextAtCursor(String pasteText) {
    final oldText = _controller.text;
    final selection = _controller.selection;
    final start = selection.isValid ? selection.start : oldText.length;
    final end = selection.isValid ? selection.end : oldText.length;
    final newText = oldText.replaceRange(start, end, pasteText);
    final newSelectionOffset = start + pasteText.length;
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newSelectionOffset),
    );
    setState(() => _hasText = _controller.text.trim().isNotEmpty);
    _detectUrl(newText);
    _recalcMentionOffsets(oldText, newText);
    _previousText = newText;
    _detectMention(newText);
    _syncTextFieldScrollWithTextAfterFrame(newText, newSelectionOffset);
  }

  void _syncTextFieldScrollWithTextAfterFrame(
    String text,
    int selectionOffset,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_textFieldScrollController.hasClients) return;
      if (text.isEmpty) {
        _textFieldScrollController.jumpTo(0);
        return;
      }
      if (selectionOffset < text.length) return;
      final maxScrollExtent =
          _textFieldScrollController.position.maxScrollExtent;
      if (maxScrollExtent <= 0) return;
      _textFieldScrollController.jumpTo(maxScrollExtent);
    });
  }

  Future<void> _send() async {
    if (_isSending) return;
    final rawText = _controller.text;
    if (rawText.trim().isEmpty) return;
    setState(() => _isSending = true);
    try {
      await widget.onSend(
        rawText.trim(),
        linkPreview: _currentPreview,
        mentions: _mentions.isNotEmpty ? List.from(_mentions) : null,
      );
      _controller.clear();
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
    setState(() {
      _hasText = false;
      _showEmojiPicker = false;
      _currentPreview = null;
      _currentUrl = null;
      _isLoadingPreview = false;
      _mentions = [];
      _mentionStartIndex = null;
      _mentionQuery = '';
      _previousText = '';
    });
    _syncComposerMentionStyling();
    _dismissMentionOverlay();
    _linkDebounceTimer?.cancel();
    _focusNode.requestFocus();
  }

  void _onEmojiSelected(Category? category, Emoji emoji) {
    final text = _controller.text;
    final selection = _controller.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final newText = text.replaceRange(start, end, emoji.emoji);
    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(
      offset: start + emoji.emoji.length,
    );
    _previousText = newText;
    _syncComposerMentionStyling();
    setState(() => _hasText = _controller.text.trim().isNotEmpty);
  }

  Future<void> _showAttachSheet() async {
    final palette = context.appPalette;
    final isWide = MediaQuery.of(context).size.width >= 768;
    String? choice;

    if (isWide) {
      final buttonRenderBox = context.findRenderObject() as RenderBox?;
      final overlay =
          Navigator.of(context).overlay?.context.findRenderObject()
              as RenderBox?;
      if (buttonRenderBox != null && overlay != null) {
        final position = RelativeRect.fromRect(
          Rect.fromPoints(
            buttonRenderBox.localToGlobal(Offset.zero, ancestor: overlay),
            buttonRenderBox.localToGlobal(
              buttonRenderBox.size.bottomRight(Offset.zero),
              ancestor: overlay,
            ),
          ),
          Offset.zero & overlay.size,
        );

        choice = await showMenu<String>(
          context: context,
          position: position,
          items: [
            PopupMenuItem(
              value: 'images',
              child: Row(
                children: [
                  Icon(Icons.photo_library, color: palette.primary, size: 20),
                  const SizedBox(width: 12),
                  Text('Ảnh', style: TextStyle(color: palette.textPrimary)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'video',
              child: Row(
                children: [
                  Icon(Icons.videocam, color: palette.primary, size: 20),
                  const SizedBox(width: 12),
                  Text('Video', style: TextStyle(color: palette.textPrimary)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'file',
              child: Row(
                children: [
                  Icon(
                    Icons.attach_file_rounded,
                    color: palette.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Tài liệu',
                    style: TextStyle(color: palette.textPrimary),
                  ),
                ],
              ),
            ),
          ],
        );
      }
    } else {
      choice = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: palette.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_library, color: palette.primary),
                title: Text(
                  'Ảnh',
                  style: TextStyle(color: palette.textPrimary),
                ),
                onTap: () => Navigator.pop(ctx, 'images'),
              ),
              ListTile(
                leading: Icon(Icons.videocam, color: palette.primary),
                title: Text(
                  'Video',
                  style: TextStyle(color: palette.textPrimary),
                ),
                onTap: () => Navigator.pop(ctx, 'video'),
              ),
              ListTile(
                leading: Icon(
                  Icons.attach_file_rounded,
                  color: palette.primary,
                ),
                title: Text(
                  'Tài liệu',
                  style: TextStyle(color: palette.textPrimary),
                ),
                onTap: () => Navigator.pop(ctx, 'file'),
              ),
            ],
          ),
        ),
      );
    }

    if (choice == null || !mounted) return;

    if (choice == 'images') {
      await _pickImages();
    } else if (choice == 'video') {
      await _pickVideo();
    } else if (choice == 'file') {
      await _pickDocument();
    }
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    if (images.isEmpty) return;
    if (!mounted) return;

    widget.onAttachImages?.call(images);
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final video = await picker.pickVideo(source: ImageSource.gallery);
    if (video == null || !mounted) return;

    final isValid = await _validateVideoBeforeAttach(video);
    if (!isValid || !mounted) return;

    widget.onAttachVideo?.call(video);
  }

  Future<bool> _validateVideoBeforeAttach(XFile video) async {
    VideoPlayerController? controller;
    WebAttachmentPreviewHandle? previewHandle;
    try {
      if (kIsWeb) {
        previewHandle = await resolveWebAttachmentPreview(video);
        final previewUrl = previewHandle?.url;
        if (previewUrl == null || previewUrl.isEmpty) {
          throw StateError('Missing preview URL');
        }
        controller = VideoPlayerController.networkUrl(Uri.parse(previewUrl));
      } else {
        controller = VideoPlayerController.file(File(video.path));
      }
      await controller.initialize();
      final duration = controller.value.duration.inSeconds;

      if (duration > 300) {
        if (mounted) {
          showTopSnackBar(context, message: 'Video quá dài (tối đa 5 phút)');
        }
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('[Video] Duration validation failed: $e');
      if (mounted) {
        showTopSnackBar(
          context,
          message: 'Không thể đọc video. Vui lòng thử lại.',
        );
      }
      return false;
    } finally {
      await controller?.dispose();
      if (kIsWeb) {
        disposeWebAttachmentPreview(previewHandle);
      }
    }
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
        withData: kIsWeb,
      );
      if (result == null || result.files.isEmpty || !mounted) return;

      final selected = result.files.first;
      final size = selected.size;
      if (!isSupportedChatDocumentExtension(selected.name)) {
        _showAttachmentError('Định dạng tệp chưa được hỗ trợ.');
        return;
      }
      if (!isSupportedChatDocumentSize(size)) {
        _showAttachmentError('Tệp không hợp lệ.');
        return;
      }

      final xFile = await _platformFileToXFile(selected);
      if (xFile == null) {
        _showAttachmentError('Không thể đọc tệp. Vui lòng thử lại.');
        return;
      }

      widget.onAttachFile?.call(xFile);
    } catch (e) {
      debugPrint('[MessageInputBar] Document pick failed: $e');
      if (mounted) {
        _showAttachmentError('Không thể chọn tệp. Vui lòng thử lại.');
      }
    }
  }

  Future<XFile?> _platformFileToXFile(PlatformFile file) async {
    if (file.path != null && file.path!.isNotEmpty) {
      return XFile(file.path!, name: file.name);
    }

    final Uint8List? bytes = file.bytes;
    if (bytes == null) return null;

    return XFile.fromData(
      bytes,
      name: file.name,
      mimeType: _mimeTypeForDocumentName(file.name),
    );
  }

  String _mimeTypeForDocumentName(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return switch (ext) {
      'pdf' => 'application/pdf',
      'txt' => 'text/plain',
      'md' => 'text/markdown',
      'csv' => 'text/csv',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls' => 'application/vnd.ms-excel',
      'xlsx' =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'ppt' => 'application/vnd.ms-powerpoint',
      'pptx' =>
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'rtf' => 'application/rtf',
      'zip' => 'application/zip',
      'rar' => 'application/vnd.rar',
      _ => 'application/octet-stream',
    };
  }

  void _showAttachmentError(String message) {
    showTopSnackBar(context, message: message);
  }

  void _handleWebDropStateChanged(WebChatDropVisualState state) {
    if (!mounted) return;
    if (state == WebChatDropVisualState.idle) {
      if (_webDropState == WebChatDropVisualState.idle &&
          _webDropMessage == null) {
        return;
      }
      setState(() {
        _webDropState = WebChatDropVisualState.idle;
        _webDropMessage = null;
      });
      return;
    }

    setState(() {
      _webDropState = state;
    });
  }

  Future<void> _handleWebDrop(List<ChatAttachmentDropFile> files) async {
    final result = await dispatchMessageInputBarDrop(
      files: files,
      validateVideo: _validateVideoBeforeAttach,
      onAttachImages: widget.onAttachImages,
      onAttachVideo: widget.onAttachVideo,
      onAttachFile: widget.onAttachFile,
    );
    if (!result.isAccepted) {
      _showAttachmentError(attachmentDropOverlayMessage(result));
    }
  }

  // --- Recording ---

  Future<void> _startRecording() async {
    try {
      _recorder = AudioRecorder();
      final hasPermission = await _recorder!.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          showTopSnackBar(
            context,
            message: 'Cần quyền truy cập microphone để ghi âm',
          );
        }
        _recorder?.dispose();
        _recorder = null;
        return;
      }

      final dir = await getTemporaryDirectory();
      _recordingPath = '${dir.path}/voice_${_uuid.v4()}.m4a';
      _waveformSamples = [];
      _recordingDuration = Duration.zero;
      _cancelDragOffset = 0;
      _isCancelZone = false;

      await _recorder!.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: _recordingPath!,
      );

      _amplitudeSub = _recorder!
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((amp) {
            if (!mounted) return;
            final normalized = ((amp.current + 160) / 160).clamp(0.0, 1.0);
            setState(() => _waveformSamples.add(normalized));
          });

      _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _recordingDuration += const Duration(seconds: 1);
        });
        if (_recordingDuration >= _maxRecordDuration) {
          _stopAndSend();
        }
      });

      setState(() => _isRecording = true);
    } catch (e) {
      debugPrint('[Voice] Recording failed to start: $e');
      _recorder?.dispose();
      _recorder = null;
      if (mounted) {
        showTopSnackBar(context, message: 'Không thể ghi âm trên thiết bị này');
      }
    }
  }
  // INPUT_BAR_STOP_SEND

  Future<void> _stopAndSend() async {
    _durationTimer?.cancel();
    _amplitudeSub?.cancel();
    final path = await _recorder?.stop();
    _recorder?.dispose();
    _recorder = null;

    if (!mounted) return;

    final duration = _recordingDuration.inMilliseconds / 1000.0;
    final waveform = _downsampleWaveform(_waveformSamples);

    setState(() {
      _isRecording = false;
      _recordingDuration = Duration.zero;
      _waveformSamples = [];
    });

    if (_isCancelZone || path == null) {
      // Cancelled — delete temp file
      if (path != null) {
        try {
          await File(path).delete();
        } catch (_) {}
      }
      return;
    }

    if (duration < 0.5) {
      // Too short
      try {
        await File(path).delete();
      } catch (_) {}
      if (mounted) {
        showTopSnackBar(context, message: 'Giữ lâu hơn để ghi âm');
      }
      return;
    }

    widget.onVoiceRecorded?.call(path, duration, waveform);
  }

  Future<void> _cancelRecording() async {
    _durationTimer?.cancel();
    _amplitudeSub?.cancel();
    final path = await _recorder?.stop();
    _recorder?.dispose();
    _recorder = null;

    if (path != null) {
      try {
        await File(path).delete();
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordingDuration = Duration.zero;
        _waveformSamples = [];
        _isCancelZone = false;
      });
    }
  }

  List<double> _downsampleWaveform(List<double> samples) {
    if (samples.length <= 100) return List.from(samples);
    final result = <double>[];
    for (int i = 0; i < 100; i++) {
      final idx = (i * samples.length / 100).floor().clamp(
        0,
        samples.length - 1,
      );
      result.add(samples[idx]);
    }
    return result;
  }

  String _formatRecordingDuration(Duration d) {
    final mins = d.inMinutes.toString().padLeft(1, '0');
    final secs = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }
  // INPUT_BAR_LINK_PREVIEW

  void _detectUrl(String text) {
    final match = _urlRegex.firstMatch(text);
    final url = match?.group(0);

    if (url != _currentUrl) {
      _currentUrl = url;
      _linkDebounceTimer?.cancel();

      if (url == null) {
        setState(() {
          _currentPreview = null;
          _isLoadingPreview = false;
        });
      } else {
        setState(() => _isLoadingPreview = true);
        _linkDebounceTimer = Timer(const Duration(milliseconds: 500), () {
          _fetchLinkPreview(url);
        });
      }
    }
  }

  Future<void> _fetchLinkPreview(String url) async {
    if (widget.onFetchLinkPreview == null) {
      setState(() => _isLoadingPreview = false);
      return;
    }
    try {
      final preview = await widget.onFetchLinkPreview!(url);
      if (mounted && _currentUrl == url) {
        setState(() {
          _currentPreview = preview;
          _isLoadingPreview = false;
        });
      }
    } catch (e) {
      debugPrint('[MessageInputBar] Failed to fetch link preview: $e');
      if (mounted) {
        setState(() {
          _currentPreview = null;
          _isLoadingPreview = false;
        });
      }
    }
  }

  // INPUT_BAR_MENTION_METHODS

  void _detectMention(String text) {
    if (!widget.isGroup || widget.members == null) {
      _dismissMentionOverlay();
      return;
    }

    final cursor = _controller.selection.baseOffset;
    if (cursor < 0) {
      _dismissMentionOverlay();
      return;
    }

    // Find the last '@' before cursor that is at position 0 or preceded by whitespace
    int? atIndex;
    for (int i = cursor - 1; i >= 0; i--) {
      if (text[i] == '@') {
        if (i == 0 || text[i - 1] == ' ' || text[i - 1] == '\n') {
          atIndex = i;
        }
        break;
      }
      // If we hit a space before finding @, no active mention
      if (text[i] == ' ' || text[i] == '\n') break;
    }

    if (atIndex == null) {
      _dismissMentionOverlay();
      _mentionStartIndex = null;
      _mentionQuery = '';
      return;
    }

    _mentionStartIndex = atIndex;
    _mentionQuery = text.substring(atIndex + 1, cursor).toLowerCase();
    _showMentionOverlay();
  }

  void _showMentionOverlay() {
    _dismissMentionOverlay();
    if (widget.members == null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        final filtered = _getFilteredMembers();
        if (filtered.isEmpty) return const SizedBox.shrink();

        final renderBox = this.context.findRenderObject() as RenderBox?;
        if (renderBox == null) return const SizedBox.shrink();
        final offset = renderBox.localToGlobal(Offset.zero);
        final barTop = offset.dy;
        final mediaQuery = MediaQuery.of(context);
        final isDesktopLayout =
            kIsWeb ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux;
        const horizontalInset = 8.0;
        const overlayGap = 4.0;
        const overlayMaxHeight = 200.0;
        const mentionRowHeight = 56.0;
        const overlayVerticalPadding = 5.0;
        final estimatedOverlayHeight =
            (filtered.length * mentionRowHeight) + overlayVerticalPadding;
        final overlayHeight = estimatedOverlayHeight.clamp(
          mentionRowHeight,
          overlayMaxHeight,
        );
        final availableHeightAboveComposer =
            barTop - mediaQuery.padding.top - overlayGap;

        final overlayChild = TextFieldTapRegion(
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            color: AppColors.surface,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: isDesktopLayout
                    ? overlayMaxHeight
                    : availableHeightAboveComposer.clamp(
                        overlayHeight,
                        overlayMaxHeight,
                      ),
              ),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.surfaceVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: filtered.length,
                itemBuilder: (ctx, i) {
                  final member = filtered[i];
                  final isAll = member['user_id'] == 'all';
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.surfaceVariant,
                      child: isAll
                          ? const Icon(
                              Icons.groups,
                              size: 16,
                              color: AppColors.gold,
                            )
                          : Text(
                              (member['name'] as String? ?? '?')[0]
                                  .toUpperCase(),
                              style: const TextStyle(
                                color: AppColors.gold,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                    title: Text(
                      member['name'] as String? ?? '',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    onTap: () => _selectMention(member),
                  );
                },
              ),
            ),
          ),
        );

        if (isDesktopLayout) {
          return Positioned(
            left: horizontalInset,
            right: horizontalInset,
            bottom: mediaQuery.size.height - barTop + overlayGap,
            child: overlayChild,
          );
        }

        final mobileTop = (barTop - overlayHeight - overlayGap).clamp(
          mediaQuery.padding.top + 8,
          mediaQuery.size.height,
        );

        return Positioned(
          left: horizontalInset,
          right: horizontalInset,
          top: mobileTop,
          child: overlayChild,
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  List<Map<String, dynamic>> _getFilteredMembers() {
    final result = <Map<String, dynamic>>[];

    // Add @all for admin/creator
    final role = widget.currentUserRole;
    if (role == 'admin' || role == 'creator') {
      if ('tất cả'.contains(_mentionQuery) ||
          'all'.contains(_mentionQuery) ||
          _mentionQuery.isEmpty) {
        result.add({'user_id': 'all', 'name': 'Tất cả'});
      }
    }

    // Filter members
    final members = widget.members ?? {};
    for (final entry in members.entries) {
      if (entry.key == widget.currentUserId) continue;
      final name = entry.value['name'] ?? '';
      if (_mentionQuery.isEmpty || name.toLowerCase().contains(_mentionQuery)) {
        result.add({'user_id': entry.key, 'name': name});
      }
    }
    return result;
  }

  void _selectMention(Map<String, dynamic> member) {
    if (_mentionStartIndex == null) return;

    final userId = member['user_id'] as String;
    final displayName = userId == 'all'
        ? 'Tất cả'
        : (member['name'] as String? ?? '');
    final insertText = '@$displayName ';
    final text = _controller.text;
    final cursor = _controller.selection.baseOffset;

    // Replace @query with @DisplayName
    final newText = text.replaceRange(_mentionStartIndex!, cursor, insertText);
    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(
      offset: _mentionStartIndex! + insertText.length,
    );
    _previousText = newText;

    final updatedMentions = recalculateComposerMentions(
      mentions: _mentions,
      oldText: text,
      newText: newText,
    );
    _mentions = updatedMentions;

    // Add new mention entity
    _mentions.add({
      'offset': _mentionStartIndex!,
      'length': insertText
          .trim()
          .length, // "@DisplayName" without trailing space
      'user_id': userId,
      'name': displayName,
    });
    _syncComposerMentionStyling();

    setState(() {
      _hasText = _controller.text.trim().isNotEmpty;
      _mentionStartIndex = null;
      _mentionQuery = '';
    });
    _dismissMentionOverlay();
  }

  void _dismissMentionOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _recalcMentionOffsets(String oldText, String newText) {
    if (_mentions.isEmpty) return;
    _mentions = recalculateComposerMentions(
      mentions: _mentions,
      oldText: oldText,
      newText: newText,
    );
    _syncComposerMentionStyling();
  }

  void _syncComposerMentionStyling() {
    _controller.updateMentionStyles(
      mentions: _mentions,
      mentionColorResolver: composerMentionColorForUserId,
    );
  }

  // INPUT_BAR_BUILD

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final topBorderColor = palette.isLight
        ? const Color(0xFFDCE4EE)
        : palette.surfaceVariant;
    final composer = Stack(
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSize(
              duration: AppMotion.medium,
              curve: AppMotion.enterCurve,
              child: widget.editingMessage != null
                  ? _EditPreviewBar(
                      message: widget.editingMessage!,
                      onClose: () => widget.onCancelEdit?.call(),
                    )
                  : widget.replyTo != null
                  ? ReplyPreviewBar(
                      message: widget.replyTo!,
                      senderName: widget.replyToSenderName ?? '',
                      senderNameColor: widget.replyToSenderColor,
                      onClose: () => widget.onCancelReply?.call(),
                    )
                  : const SizedBox.shrink(),
            ),
            Container(
              padding: EdgeInsets.only(
                left: 8,
                right: 8,
                top: 8,
                bottom: _showEmojiPicker
                    ? 8
                    : MediaQuery.of(context).padding.bottom + 8,
              ),
              decoration: BoxDecoration(
                color: palette.surface,
                border: Border(top: BorderSide(color: topBorderColor)),
              ),
              child: TextFieldTapRegion(
                child: _isRecording ? _buildRecordingUI() : _buildNormalUI(),
              ),
            ),
            if (_isLoadingPreview && !_isRecording)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: palette.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Đang tải preview...',
                      style: TextStyle(fontSize: 12, color: palette.textHint),
                    ),
                  ],
                ),
              ),
            if (_currentPreview != null && !_isRecording)
              LinkPreviewCard(
                preview: _currentPreview!,
                onRemove: () {
                  setState(() {
                    _currentPreview = null;
                    _currentUrl = null;
                  });
                },
              ),
            if (_showEmojiPicker && !_isRecording)
              SizedBox(
                height: 250,
                child: EmojiPicker(
                  onEmojiSelected: _onEmojiSelected,
                  config: Config(
                    height: 250,
                    emojiViewConfig: EmojiViewConfig(
                      backgroundColor: palette.surface,
                      columns: 8,
                      emojiSizeMax: 28,
                    ),
                    categoryViewConfig: CategoryViewConfig(
                      backgroundColor: palette.surface,
                      indicatorColor: palette.primary,
                      iconColorSelected: palette.primary,
                      iconColor: palette.textHint,
                    ),
                    searchViewConfig: SearchViewConfig(
                      backgroundColor: palette.surface,
                      hintText: 'Tìm emoji...',
                      buttonIconColor: palette.textSecondary,
                    ),
                    bottomActionBarConfig: BottomActionBarConfig(
                      backgroundColor: palette.surface,
                      buttonColor: palette.primary,
                      buttonIconColor: palette.isLight
                          ? Colors.white
                          : palette.background,
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (_webDropState != WebChatDropVisualState.idle)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedContainer(
                duration: AppMotion.fast,
                decoration: BoxDecoration(
                  color:
                      (_webDropState == WebChatDropVisualState.rejected
                              ? AppColors.danger
                              : palette.primary)
                          .withValues(alpha: 0.14),
                  border: Border.all(
                    color: _webDropState == WebChatDropVisualState.rejected
                        ? AppColors.danger
                        : palette.primary,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: palette.surface.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _webDropMessage ?? 'Thả tệp để đính kèm',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _webDropState == WebChatDropVisualState.rejected
                            ? AppColors.danger
                            : palette.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    return WebChatDropTarget(
      classifier: (files) {
        final result = classifyMessageInputBarDrop(files);
        final nextMessage = attachmentDropOverlayMessage(result);
        final nextState = result.isAccepted
            ? WebChatDropVisualState.active
            : WebChatDropVisualState.rejected;
        if (_webDropState != nextState || _webDropMessage != nextMessage) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _webDropState = nextState;
              _webDropMessage = nextMessage;
            });
          });
        }
        return result;
      },
      onDragStateChanged: _handleWebDropStateChanged,
      onDrop: _handleWebDrop,
      child: composer,
    );
  }
  // INPUT_BAR_NORMAL_UI

  Widget _buildTextField() {
    final palette = context.appPalette;
    final textField = TextField(
      controller: _controller,
      focusNode: _focusNode,
      scrollController: _textFieldScrollController,
      style: TextStyle(color: palette.textPrimary),
      maxLines: 4,
      minLines: 1,
      textInputAction: kIsWeb ? TextInputAction.none : TextInputAction.newline,
      decoration: InputDecoration(
        hintText: widget.editingMessage != null
            ? 'Chỉnh sửa tin nhắn...'
            : 'Nhập tin nhắn...',
        hintStyle: TextStyle(color: palette.textHint),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
      ),
      onChanged: (text) {
        setState(() => _hasText = text.trim().isNotEmpty);
        _detectUrl(text);
        _recalcMentionOffsets(_previousText, text);
        _previousText = text;
        _detectMention(text);
        _syncTextFieldScrollWithTextAfterFrame(
          text,
          _controller.selection.extentOffset,
        );
        _typingThrottleTimer?.cancel();
        if (text.trim().isNotEmpty) {
          _typingThrottleTimer = Timer(
            const Duration(seconds: 3),
            () => widget.onTyping?.call(),
          );
        }
      },
      onTap: () {
        if (_showEmojiPicker) {
          setState(() => _showEmojiPicker = false);
        }
      },
      onTapOutside: (_) {},
    );

    // On web, paste is handled by ClipboardEvents listener (_onWebPaste).
    // On native, intercept PasteTextIntent via Actions widget.
    if (kIsWeb) return textField;
    return Actions(
      actions: <Type, Action<Intent>>{
        PasteTextIntent: CallbackAction<PasteTextIntent>(
          onInvoke: (_) {
            _handlePaste();
            return null;
          },
        ),
      },
      child: textField,
    );
  }

  Widget _buildNormalUI() {
    final palette = context.appPalette;
    final composerFill = palette.isLight
        ? const Color(0xFFF2F4F8)
        : palette.surfaceVariant;
    final composerRadius = BorderRadius.circular(22);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        IconButton(
          icon: Icon(
            _showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions_outlined,
            color: palette.textSecondary,
          ),
          tooltip: 'Emoji',
          onPressed: () {
            setState(() {
              _showEmojiPicker = !_showEmojiPicker;
              if (!_showEmojiPicker) _focusNode.requestFocus();
            });
          },
        ),
        const SizedBox(width: 2),
        Expanded(
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: composerFill,
              borderRadius: composerRadius,
            ),
            child: _buildTextField(),
          ),
        ),
        const SizedBox(width: 2),
        IconButton(
          icon: Icon(Icons.attach_file, color: palette.textSecondary),
          tooltip: 'Đính kèm',
          onPressed: widget.editingMessage != null ? null : _showAttachSheet,
        ),
        // Send button
        IconButton(
          onPressed:
              ((_hasText || widget.editingMessage != null) && !_isSending)
              ? _send
              : null,
          tooltip: widget.editingMessage != null ? 'Lưu' : 'Gửi',
          icon: Icon(
            Icons.send_rounded,
            color: (_hasText || widget.editingMessage != null)
                ? palette.primary
                : palette.textHint,
          ),
        ),
      ],
    );
  }
  // INPUT_BAR_RECORDING_UI

  Widget _buildRecordingUI() {
    final visibleSamples = _waveformSamples.length > 30
        ? _waveformSamples.sublist(_waveformSamples.length - 30)
        : _waveformSamples;

    return Row(
      children: [
        // Pulsing red dot + timer
        const _PulsingDot(),
        const SizedBox(width: 8),
        Text(
          _formatRecordingDuration(_recordingDuration),
          style: const TextStyle(color: AppColors.danger, fontSize: 14),
        ),
        const SizedBox(width: 12),
        // Live waveform
        Expanded(
          child: SizedBox(
            height: 32,
            child: CustomPaint(
              painter: _LiveWaveformPainter(
                samples: visibleSamples,
                color: AppColors.gold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Cancel hint
        Text(
          _isCancelZone ? 'Thả để hủy' : '< Trượt để hủy',
          style: TextStyle(
            color: _isCancelZone ? AppColors.danger : AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

class _EditPreviewBar extends StatelessWidget {
  final LocalMessage message;
  final VoidCallback onClose;

  const _EditPreviewBar({required this.message, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.surfaceVariant.withValues(alpha: 0.75),
        border: Border(top: BorderSide(color: palette.surfaceVariant)),
      ),
      child: Row(
        children: [
          Icon(Icons.edit_outlined, size: 18, color: palette.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Đang sửa tin nhắn',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if ((message.content ?? '').isNotEmpty)
                  Text(
                    message.content!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: Icon(Icons.close, color: palette.textSecondary, size: 18),
            tooltip: 'Hủy sửa',
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: 0.4 + _controller.value * 0.6,
          child: Transform.scale(
            scale: 0.88 + (_controller.value * 0.18),
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppColors.danger,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LiveWaveformPainter extends CustomPainter {
  final List<double> samples;
  final Color color;

  _LiveWaveformPainter({required this.samples, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;
    const barWidth = 2.0;
    const gap = 2.0;
    final paint = Paint()..color = color;

    for (int i = 0; i < samples.length; i++) {
      final x = i * (barWidth + gap);
      if (x > size.width) break;
      final barHeight = 4.0 + samples[i] * (size.height - 4);
      final y = (size.height - barHeight) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          const Radius.circular(1),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LiveWaveformPainter oldDelegate) =>
      oldDelegate.samples.length != samples.length;
}
