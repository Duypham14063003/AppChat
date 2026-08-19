import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'dart:io' show File;

class ClipboardImageReader {
  static const _imageFormats = [
    Formats.png,
    Formats.jpeg,
    Formats.gif,
    Formats.bmp,
    Formats.webp,
  ];

  static const _formatMeta = <SimpleFileFormat, (String ext, String mime)>{
    Formats.png: ('png', 'image/png'),
    Formats.jpeg: ('jpg', 'image/jpeg'),
    Formats.gif: ('gif', 'image/gif'),
    Formats.bmp: ('bmp', 'image/bmp'),
    Formats.webp: ('webp', 'image/webp'),
  };

  /// Reads an image from the system clipboard (native platforms only).
  /// On web, use [readImageFromReader] with a reader from [ClipboardReadEvent].
  static Future<XFile?> readImageFromClipboard() async {
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) return null;
    final reader = await clipboard.read();
    return readImageFromReader(reader);
  }

  /// Reads an image from an existing [ClipboardReader].
  /// Works on all platforms — use this on web with the reader from paste event.
  static Future<XFile?> readImageFromReader(ClipboardReader reader) async {
    for (final item in reader.items) {
      for (final format in _imageFormats) {
        if (!item.canProvide(format)) continue;

        final bytes = await _readFileBytes(item, format);
        if (bytes == null || bytes.isEmpty) continue;

        final meta = _formatMeta[format] ?? ('png', 'image/png');
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filename = 'clipboard_paste_$timestamp.${meta.$1}';

        if (kIsWeb) {
          return XFile.fromData(bytes, name: filename, mimeType: meta.$2);
        } else {
          final dir = await getTemporaryDirectory();
          final file = File('${dir.path}/$filename');
          await file.writeAsBytes(bytes);
          return XFile(file.path);
        }
      }
    }
    return null;
  }

  static Future<Uint8List?> _readFileBytes(
    ClipboardDataReader item,
    FileFormat format,
  ) async {
    final completer = Completer<Uint8List?>();
    final progress = item.getFile(
      format,
      (file) async {
        try {
          final bytes = await file.readAll();
          completer.complete(bytes);
        } catch (e) {
          completer.complete(null);
        }
      },
      onError: (error) {
        if (!completer.isCompleted) completer.complete(null);
      },
    );
    if (progress == null) return null;
    return completer.future;
  }
}
