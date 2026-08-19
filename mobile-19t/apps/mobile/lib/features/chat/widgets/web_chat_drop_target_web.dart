// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../utils/chat_attachment_drop.dart';
import 'web_chat_drop_target_common.dart';

enum WebChatDropVisualState { idle, active, rejected }

typedef WebChatDropClassifier =
    ChatAttachmentDropResult Function(List<ChatAttachmentDropCandidate> files);

class WebChatDropTarget extends StatefulWidget {
  const WebChatDropTarget({
    super.key,
    required this.child,
    required this.classifier,
    required this.onDragStateChanged,
    required this.onDrop,
  });

  final Widget child;
  final WebChatDropClassifier classifier;
  final ValueChanged<WebChatDropVisualState> onDragStateChanged;
  final Future<void> Function(List<ChatAttachmentDropFile> files) onDrop;

  @override
  State<WebChatDropTarget> createState() => _WebChatDropTargetState();
}

class _WebChatDropTargetState extends State<WebChatDropTarget> {
  StreamSubscription<html.MouseEvent>? _dragEnterSubscription;
  StreamSubscription<html.MouseEvent>? _dragOverSubscription;
  StreamSubscription<html.MouseEvent>? _dragLeaveSubscription;
  StreamSubscription<html.MouseEvent>? _dragEndSubscription;
  StreamSubscription<html.MouseEvent>? _dropSubscription;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _dragEnterSubscription = html.document.onDragEnter.listen(_handleDragMove);
    _dragOverSubscription = html.document.onDragOver.listen(_handleDragMove);
    _dragLeaveSubscription = html.document.onDragLeave.listen(_handleDragLeave);
    _dragEndSubscription = html.document.onDragEnd.listen(_handleDragEnd);
    _dropSubscription = html.document.onDrop.listen(_handleDrop);
  }

  @override
  void dispose() {
    _dragEnterSubscription?.cancel();
    _dragOverSubscription?.cancel();
    _dragLeaveSubscription?.cancel();
    _dragEndSubscription?.cancel();
    _dropSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  void _handleDragMove(html.MouseEvent event) {
    if (!mounted) return;
    final transfer = event.dataTransfer;
    if (!_containsPoint(event.client.x.toDouble(), event.client.y.toDouble())) {
      if (_isHovering) {
        _isHovering = false;
        widget.onDragStateChanged(WebChatDropVisualState.idle);
      }
      return;
    }

    final candidates = _extractCandidates(transfer);
    if (candidates.isEmpty) {
      _isHovering = true;
      event.preventDefault();
      widget.onDragStateChanged(WebChatDropVisualState.active);
      return;
    }

    final result = widget.classifier(candidates);
    _isHovering = true;
    event.preventDefault();
    widget.onDragStateChanged(
      result.isAccepted
          ? WebChatDropVisualState.active
          : WebChatDropVisualState.rejected,
    );
  }

  void _handleDragLeave(html.MouseEvent event) {
    if (!_isHovering) return;
    final x = event.client.x.toDouble();
    final y = event.client.y.toDouble();
    if (_containsPoint(x, y)) return;
    _isHovering = false;
    widget.onDragStateChanged(WebChatDropVisualState.idle);
  }

  void _handleDragEnd(html.MouseEvent event) {
    if (!_isHovering) return;
    _isHovering = false;
    widget.onDragStateChanged(WebChatDropVisualState.idle);
  }

  Future<void> _handleDrop(html.MouseEvent event) async {
    final transfer = event.dataTransfer;
    final x = event.client.x.toDouble();
    final y = event.client.y.toDouble();
    if (!_containsPoint(x, y)) return;

    event.preventDefault();
    _isHovering = false;
    widget.onDragStateChanged(WebChatDropVisualState.idle);

    final files = await _extractFiles(transfer);
    if (!mounted) return;
    await widget.onDrop(files);
  }

  List<ChatAttachmentDropCandidate> _extractCandidates(
    html.DataTransfer transfer,
  ) {
    final files = transfer.files ?? const <html.File>[];
    return files
        .map(
          (file) => ChatAttachmentDropCandidate(
            name: file.name,
            mimeType: file.type,
            sizeInBytes: file.size,
          ),
        )
        .toList(growable: false);
  }

  Future<List<ChatAttachmentDropFile>> _extractFiles(
    html.DataTransfer transfer,
  ) async {
    final files = transfer.files ?? const <html.File>[];
    final result = <ChatAttachmentDropFile>[];
    for (final file in files) {
      final bytes = await _readBytes(file);
      if (bytes == null) continue;
      result.add(
        ChatAttachmentDropFile(
          name: file.name,
          mimeType: file.type.isEmpty ? 'application/octet-stream' : file.type,
          sizeInBytes: file.size,
          bytes: bytes,
        ),
      );
    }
    return result;
  }

  Future<Uint8List?> _readBytes(html.File file) {
    final completer = Completer<Uint8List?>();
    final reader = html.FileReader();
    reader.onLoadEnd.listen((_) {
      completer.complete(bytesFromBrowserFileReaderResult(reader.result));
    });
    reader.onError.listen((_) => completer.complete(null));
    reader.readAsArrayBuffer(file);
    return completer.future;
  }

  bool _containsPoint(double x, double y) {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return false;
    final topLeft = renderObject.localToGlobal(Offset.zero);
    final rect = topLeft & renderObject.size;
    return rect.contains(Offset(x, y));
  }
}
