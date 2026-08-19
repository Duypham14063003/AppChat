import 'dart:convert';

class ConversationEncryptionKey {
  const ConversationEncryptionKey({
    required this.convId,
    required this.keyId,
    required this.algorithm,
    required this.version,
    required this.material,
  });

  final String convId;
  final String keyId;
  final String algorithm;
  final int version;
  final String material;

  String get cacheKey => '$convId::$keyId';

  Map<String, dynamic> toJson() => {
    'conv_id': convId,
    'key_id': keyId,
    'alg': algorithm,
    'version': version,
    'material': material,
  };

  factory ConversationEncryptionKey.fromJson(Map<String, dynamic> json) {
    return ConversationEncryptionKey(
      convId: json['conv_id'] as String,
      keyId: json['key_id'] as String,
      algorithm: json['alg'] as String? ?? 'AES-256-GCM',
      version: (json['version'] as num?)?.toInt() ?? 1,
      material: json['material'] as String,
    );
  }

  static String encodeList(List<ConversationEncryptionKey> keys) =>
      jsonEncode(keys.map((key) => key.toJson()).toList());

  static List<ConversationEncryptionKey> decodeList(String raw) {
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map(
          (item) =>
              ConversationEncryptionKey.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }
}
