import 'package:flutter/widgets.dart';

import '../utils/chat_attachment_drop.dart';

enum WebChatDropVisualState { idle, active, rejected }

typedef WebChatDropClassifier =
    ChatAttachmentDropResult Function(List<ChatAttachmentDropCandidate> files);

class WebChatDropTarget extends StatelessWidget {
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
  Widget build(BuildContext context) => child;
}
