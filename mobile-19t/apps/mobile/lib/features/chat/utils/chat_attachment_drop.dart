import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'chat_attachment_validation.dart';

enum ChatAttachmentDropKind { images, video, document }

enum ChatAttachmentDropRejectionReason { empty, unsupported, mixed }

@immutable
class ChatAttachmentDropCandidate {
  const ChatAttachmentDropCandidate({
    required this.name,
    required this.mimeType,
    required this.sizeInBytes,
  });

  final String name;
  final String mimeType;
  final int sizeInBytes;
}

@immutable
class ChatAttachmentDropFile extends ChatAttachmentDropCandidate {
  const ChatAttachmentDropFile({
    required super.name,
    required super.mimeType,
    required super.sizeInBytes,
    required this.bytes,
  });

  final Uint8List bytes;

  XFile toXFile() {
    return XFile.fromData(bytes, name: name, mimeType: mimeType);
  }
}

@immutable
class ChatAttachmentDropResult {
  const ChatAttachmentDropResult.accepted({
    required this.kind,
    required this.files,
  }) : rejectionReason = null;

  const ChatAttachmentDropResult.rejected({
    required this.rejectionReason,
    required this.files,
  }) : kind = null;

  final ChatAttachmentDropKind? kind;
  final ChatAttachmentDropRejectionReason? rejectionReason;
  final List<ChatAttachmentDropCandidate> files;

  bool get isAccepted => kind != null;
}

const _supportedImageExtensions = {
  'png',
  'jpg',
  'jpeg',
  'gif',
  'bmp',
  'webp',
  'heic',
  'heif',
};

const _supportedVideoExtensions = {'mp4', 'mov', 'm4v', 'webm', 'avi', 'mkv'};

ChatAttachmentDropResult classifyChatAttachmentDrop(
  List<ChatAttachmentDropCandidate> files,
) {
  if (files.isEmpty) {
    return const ChatAttachmentDropResult.rejected(
      rejectionReason: ChatAttachmentDropRejectionReason.empty,
      files: [],
    );
  }

  final imageFiles = files.where(_isImageCandidate).toList(growable: false);
  if (imageFiles.length == files.length) {
    return ChatAttachmentDropResult.accepted(
      kind: ChatAttachmentDropKind.images,
      files: imageFiles,
    );
  }

  if (files.length == 1) {
    final file = files.single;
    if (_isVideoCandidate(file)) {
      return ChatAttachmentDropResult.accepted(
        kind: ChatAttachmentDropKind.video,
        files: [file],
      );
    }
    if (_isSupportedDocumentCandidate(file)) {
      return ChatAttachmentDropResult.accepted(
        kind: ChatAttachmentDropKind.document,
        files: [file],
      );
    }
    return ChatAttachmentDropResult.rejected(
      rejectionReason: ChatAttachmentDropRejectionReason.unsupported,
      files: files,
    );
  }

  final anySupported = files.any((file) {
    return _isImageCandidate(file) ||
        _isVideoCandidate(file) ||
        _isSupportedDocumentCandidate(file);
  });

  return ChatAttachmentDropResult.rejected(
    rejectionReason: anySupported
        ? ChatAttachmentDropRejectionReason.mixed
        : ChatAttachmentDropRejectionReason.unsupported,
    files: files,
  );
}

String attachmentDropOverlayMessage(ChatAttachmentDropResult result) {
  if (result.isAccepted) {
    return switch (result.kind!) {
      ChatAttachmentDropKind.images => 'Thả để gửi ảnh',
      ChatAttachmentDropKind.video => 'Thả để gửi video',
      ChatAttachmentDropKind.document => 'Thả để gửi tài liệu',
    };
  }

  return switch (result.rejectionReason) {
    ChatAttachmentDropRejectionReason.mixed =>
      'Không thể thả nhiều loại tệp cùng lúc',
    ChatAttachmentDropRejectionReason.unsupported =>
      'Chỉ hỗ trợ ảnh, 1 video hoặc 1 tài liệu hợp lệ',
    ChatAttachmentDropRejectionReason.empty =>
      'Không có tệp hợp lệ để đính kèm',
    null => 'Không thể đính kèm tệp này',
  };
}

bool _isImageCandidate(ChatAttachmentDropCandidate file) {
  final mimeType = file.mimeType.toLowerCase();
  if (mimeType.startsWith('image/')) return true;
  return _supportedImageExtensions.contains(_fileExtension(file.name));
}

bool _isVideoCandidate(ChatAttachmentDropCandidate file) {
  final mimeType = file.mimeType.toLowerCase();
  if (mimeType.startsWith('video/')) return true;
  return _supportedVideoExtensions.contains(_fileExtension(file.name));
}

bool _isSupportedDocumentCandidate(ChatAttachmentDropCandidate file) {
  return isSupportedChatDocumentExtension(file.name) &&
      isSupportedChatDocumentSize(file.sizeInBytes);
}

String _fileExtension(String filename) {
  final trimmed = filename.trim();
  final dotIndex = trimmed.lastIndexOf('.');
  if (dotIndex <= 0 || dotIndex == trimmed.length - 1) return '';
  return trimmed.substring(dotIndex + 1).toLowerCase();
}
