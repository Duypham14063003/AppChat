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
  final path = file.path;
  if (path.isEmpty) return null;
  return WebAttachmentPreviewHandle(url: path);
}

void disposeWebAttachmentPreview(WebAttachmentPreviewHandle? handle) {}
