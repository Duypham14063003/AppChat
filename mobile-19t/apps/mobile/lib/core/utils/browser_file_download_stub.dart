import 'dart:typed_data';

Future<void> downloadBytesInBrowser({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) async {
  throw UnsupportedError('Browser download is only available on web.');
}
