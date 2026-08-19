import 'dart:typed_data';

Uint8List? bytesFromBrowserFileReaderResult(Object? result) {
  if (result is ByteBuffer) return result.asUint8List();
  if (result is Uint8List) return result;
  if (result is ByteData) {
    return Uint8List.view(
      result.buffer,
      result.offsetInBytes,
      result.lengthInBytes,
    );
  }
  if (result is List<int>) return Uint8List.fromList(result);
  return null;
}
