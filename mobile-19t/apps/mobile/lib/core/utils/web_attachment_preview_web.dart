// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

import 'package:image_picker/image_picker.dart';

import 'web_attachment_preview_common.dart';

class WebAttachmentPreviewHandle {
  const WebAttachmentPreviewHandle({
    required this.url,
    this.isObjectUrl = false,
  });

  final String url;
  final bool isObjectUrl;
}

bool hasUsableWebAttachmentPreviewPath(XFile file) {
  return isReusableBrowserPreviewUrl(file.path);
}

Future<WebAttachmentPreviewHandle?> resolveWebAttachmentPreview(
  XFile file,
) async {
  if (hasUsableWebAttachmentPreviewPath(file)) {
    return WebAttachmentPreviewHandle(url: file.path);
  }

  final bytes = await file.readAsBytes();
  if (bytes.isEmpty) return null;
  final mimeType = file.mimeType ?? 'application/octet-stream';
  final url = html.Url.createObjectUrlFromBlob(html.Blob([bytes], mimeType));
  return WebAttachmentPreviewHandle(url: url, isObjectUrl: true);
}

void disposeWebAttachmentPreview(WebAttachmentPreviewHandle? handle) {
  if (handle == null || !handle.isObjectUrl) return;
  html.Url.revokeObjectUrl(handle.url);
}
