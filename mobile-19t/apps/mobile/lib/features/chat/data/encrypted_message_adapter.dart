import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import 'conversation_encryption_key.dart';

const encryptedMessagePreviewPlaceholder = 'Tin nhắn đã mã hóa';
const encryptedMessageDecryptFailedPlaceholder = 'Không thể giải mã tin nhắn';

class EncryptedMessageEnvelope {
  const EncryptedMessageEnvelope({
    required this.version,
    required this.algorithm,
    required this.keyId,
    required this.nonce,
    required this.ciphertext,
  });

  final int version;
  final String algorithm;
  final String keyId;
  final String nonce;
  final String ciphertext;

  Map<String, dynamic> toJson() => {
    'version': version,
    'alg': algorithm,
    'key_id': keyId,
    'nonce': nonce,
    'ciphertext': ciphertext,
  };

  factory EncryptedMessageEnvelope.fromJson(Map<String, dynamic> json) {
    return EncryptedMessageEnvelope(
      version: (json['version'] as num?)?.toInt() ?? 1,
      algorithm: json['alg'] as String? ?? 'AES-256-GCM',
      keyId: json['key_id'] as String,
      nonce: json['nonce'] as String,
      ciphertext: json['ciphertext'] as String,
    );
  }
}

class EncryptedTextPayload {
  const EncryptedTextPayload({
    required this.content,
    required this.metadataJson,
    required this.metadataMap,
  });

  final String? content;
  final String? metadataJson;
  final Map<String, dynamic>? metadataMap;
}

class EncryptedMessageAdapter {
  EncryptedMessageAdapter({AesGcm? algorithm})
    : _algorithm = algorithm ?? AesGcm.with256bits();

  static const envelopeMetadataKey = 'encrypted_content';
  static const blindIndexMetadataKey = 'blind_index_v1';
  static const blindIndexAlgorithm = 'hmac-sha256';
  static const blindIndexVersion = 1;
  final AesGcm _algorithm;

  Future<EncryptedMessageEnvelope> encryptText({
    required String plaintext,
    required ConversationEncryptionKey key,
    required String messageId,
    required String convId,
    String type = 'text',
  }) async {
    final secretKey = SecretKey(base64Decode(key.material));
    final nonce = _algorithm.newNonce();
    final secretBox = await _algorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: secretKey,
      nonce: nonce,
      aad: _buildAssociatedData(
        messageId: messageId,
        convId: convId,
        type: type,
      ),
    );

    final cipherBytes = Uint8List.fromList([
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ]);
    return EncryptedMessageEnvelope(
      version: key.version,
      algorithm: key.algorithm,
      keyId: key.keyId,
      nonce: base64Encode(secretBox.nonce),
      ciphertext: base64Encode(cipherBytes),
    );
  }

  Future<String> decryptText({
    required EncryptedMessageEnvelope envelope,
    required ConversationEncryptionKey key,
    required String messageId,
    required String convId,
    String type = 'text',
  }) async {
    final payload = base64Decode(envelope.ciphertext);
    if (payload.length < 16) {
      throw const FormatException('Ciphertext is missing MAC bytes.');
    }
    final cipherText = payload.sublist(0, payload.length - 16);
    final macBytes = payload.sublist(payload.length - 16);
    final secretBox = SecretBox(
      cipherText,
      nonce: base64Decode(envelope.nonce),
      mac: Mac(macBytes),
    );
    final clearBytes = await _algorithm.decrypt(
      secretBox,
      secretKey: SecretKey(base64Decode(key.material)),
      aad: _buildAssociatedData(
        messageId: messageId,
        convId: convId,
        type: type,
      ),
    );
    return utf8.decode(clearBytes);
  }

  Uint8List _buildAssociatedData({
    required String messageId,
    required String convId,
    required String type,
  }) => Uint8List.fromList(utf8.encode('$messageId|$convId|$type'));

  Map<String, dynamic>? decodeMetadata(String? metadataJson) {
    if (metadataJson == null || metadataJson.isEmpty) return null;
    try {
      return jsonDecode(metadataJson) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  String? encodeMetadata(Map<String, dynamic>? metadataMap) =>
      metadataMap == null || metadataMap.isEmpty
      ? null
      : jsonEncode(metadataMap);

  EncryptedMessageEnvelope? envelopeFromMetadata(String? metadataJson) {
    final metadata = decodeMetadata(metadataJson);
    final raw = metadata?[envelopeMetadataKey];
    if (raw is Map<String, dynamic>) {
      return EncryptedMessageEnvelope.fromJson(raw);
    }
    if (raw is Map) {
      return EncryptedMessageEnvelope.fromJson(Map<String, dynamic>.from(raw));
    }
    return null;
  }

  bool isEncryptedMetadata(String? metadataJson) =>
      envelopeFromMetadata(metadataJson) != null;

  bool isEncryptedPayload(Map<String, dynamic> payload) {
    final raw = payload['encrypted_content'];
    return raw is Map || raw is Map<String, dynamic>;
  }

  Map<String, dynamic>? blindIndexFromMetadata(String? metadataJson) {
    final metadata = decodeMetadata(metadataJson);
    final raw = metadata?[blindIndexMetadataKey];
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  Future<Map<String, dynamic>?> buildBlindIndexPayload({
    required String plaintext,
    required ConversationEncryptionKey key,
  }) async {
    final tokens = await buildBlindIndexTokens(plaintext: plaintext, key: key);
    if (tokens.isEmpty) return null;
    return {
      'version': blindIndexVersion,
      'algo': blindIndexAlgorithm,
      'tokens': tokens,
    };
  }

  Future<List<String>> buildBlindIndexTokens({
    required String plaintext,
    required ConversationEncryptionKey key,
  }) async {
    final normalizedTokens = normalizeBlindIndexTerms(plaintext);
    if (normalizedTokens.isEmpty) return const [];

    final hmac = Hmac.sha256();
    final secretKey = SecretKey(base64Decode(key.material));
    final hashedTokens = <String>[];

    for (final token in normalizedTokens) {
      final mac = await hmac.calculateMac(
        utf8.encode('chat-search-v1::$token'),
        secretKey: secretKey,
      );
      hashedTokens.add(_bytesToHex(mac.bytes));
    }

    return hashedTokens;
  }

  List<String> normalizeBlindIndexTerms(String plaintext) {
    final normalized = plaintext
        .toLowerCase()
        .replaceAll(RegExp(r'[^0-9A-Za-z\u00C0-\u024F\u1E00-\u1EFF]+'), ' ')
        .trim();
    if (normalized.isEmpty) return const [];

    final unique = <String>{};
    for (final token in normalized.split(RegExp(r'\s+'))) {
      final trimmed = token.trim();
      if (trimmed.length < 2) continue;
      unique.add(trimmed);
    }
    return unique.toList(growable: false);
  }

  Map<String, dynamic>? sanitizeOutgoingMetadata(
    Map<String, dynamic>? metadata,
  ) {
    if (metadata == null || metadata.isEmpty) return null;
    final sanitized = Map<String, dynamic>.from(metadata)
      ..remove(envelopeMetadataKey)
      ..remove(blindIndexMetadataKey);
    return sanitized.isEmpty ? null : sanitized;
  }

  String buildMetadataJson({
    Map<String, dynamic>? existingMetadata,
    EncryptedMessageEnvelope? envelope,
    Map<String, dynamic>? blindIndex,
    Map<String, dynamic>? replyTo,
  }) {
    final merged = <String, dynamic>{...?existingMetadata};
    if (replyTo != null) {
      merged['reply_to'] = replyTo;
    }
    if (envelope != null) {
      merged[envelopeMetadataKey] = envelope.toJson();
    }
    if (blindIndex != null) {
      merged[blindIndexMetadataKey] = blindIndex;
    }
    return jsonEncode(merged);
  }

  String safePreviewForMessage({
    required String type,
    String? content,
    String? metadataJson,
    DateTime? deletedAt,
  }) {
    if (deletedAt != null) return 'Tin nhan da duoc thu hoi';
    if (type != 'text') return content ?? encryptedMessagePreviewPlaceholder;
    if (content != null && content.trim().isNotEmpty) return content.trim();
    if (isEncryptedMetadata(metadataJson)) {
      return encryptedMessagePreviewPlaceholder;
    }
    return content ?? '';
  }

  static String getPreviewSnippet(String content) {
    final clean = content.replaceAll('\n', ' ').trim();
    if (clean.length <= 50) return clean;
    return '${clean.substring(0, 50)}...';
  }

  String _bytesToHex(List<int> bytes) {
    final buffer = StringBuffer();
    for (final byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  Future<EncryptedTextPayload> resolveLocalMessageForUi(
    LocalMessage message,
    Future<ConversationEncryptionKey?> Function(String convId, String keyId)
    findKey,
  ) async {
    if (message.type != 'text') {
      return EncryptedTextPayload(
        content: message.content,
        metadataJson: message.metadata,
        metadataMap: decodeMetadata(message.metadata),
      );
    }

    final metadata = decodeMetadata(message.metadata);
    final envelope = envelopeFromMetadata(message.metadata);
    if (envelope == null) {
      final resolvedMetadata = await _resolveReplySnapshotForUi(
        metadata: metadata,
        convId: message.convId,
        findKey: findKey,
      );
      return EncryptedTextPayload(
        content: message.content,
        metadataJson: resolvedMetadata == null
            ? message.metadata
            : jsonEncode(resolvedMetadata),
        metadataMap: resolvedMetadata,
      );
    }

    try {
      final key = await findKey(message.convId, envelope.keyId);
      if (key == null) {
        debugPrint(
          '[Chat][Decrypt] Missing key for message_id=${message.id} '
          'conv_id=${message.convId} key_id=${envelope.keyId}',
        );
        final resolvedMetadata = await _resolveReplySnapshotForUi(
          metadata: metadata,
          convId: message.convId,
          findKey: findKey,
        );
        return EncryptedTextPayload(
          content: encryptedMessagePreviewPlaceholder,
          metadataJson: resolvedMetadata == null
              ? message.metadata
              : jsonEncode(resolvedMetadata),
          metadataMap: resolvedMetadata,
        );
      }
      final decrypted = await decryptText(
        envelope: envelope,
        key: key,
        messageId: message.id,
        convId: message.convId,
        type: message.type,
      );
      final resolvedMetadata = await _resolveReplySnapshotForUi(
        metadata: metadata,
        convId: message.convId,
        findKey: findKey,
      );
      return EncryptedTextPayload(
        content: decrypted,
        metadataJson: resolvedMetadata == null
            ? message.metadata
            : jsonEncode(resolvedMetadata),
        metadataMap: resolvedMetadata,
      );
    } catch (error) {
      debugPrint(
        '[Chat][Decrypt] Failed for message_id=${message.id} '
        'conv_id=${message.convId} key_id=${envelope.keyId}: $error',
      );
      final resolvedMetadata = await _resolveReplySnapshotForUi(
        metadata: metadata,
        convId: message.convId,
        findKey: findKey,
      );
      return EncryptedTextPayload(
        content: encryptedMessageDecryptFailedPlaceholder,
        metadataJson: resolvedMetadata == null
            ? message.metadata
            : jsonEncode(resolvedMetadata),
        metadataMap: resolvedMetadata,
      );
    }
  }

  Future<Map<String, dynamic>?> _resolveReplySnapshotForUi({
    required Map<String, dynamic>? metadata,
    required String convId,
    required Future<ConversationEncryptionKey?> Function(
      String convId,
      String keyId,
    )
    findKey,
  }) async {
    if (metadata == null) return null;
    final replyRaw = metadata['reply_to'];
    if (replyRaw is! Map) return metadata;

    final resolvedMetadata = Map<String, dynamic>.from(metadata);
    final replyTo = Map<String, dynamic>.from(replyRaw);
    final deletedAt = replyTo['deleted_at'];
    final existingContent = (replyTo['content'] as String?)?.trim();
    final replyType = replyTo['type'] as String? ?? 'text';

    if (deletedAt == null &&
        (existingContent == null || existingContent.isEmpty)) {
      final encryptedRaw = replyTo['encrypted_content'];
      if (encryptedRaw is Map) {
        try {
          final envelope = EncryptedMessageEnvelope.fromJson(
            Map<String, dynamic>.from(encryptedRaw),
          );
          final replyId = replyTo['id'] as String?;
          if (replyId != null && replyId.isNotEmpty) {
            final key = await findKey(convId, envelope.keyId);
            if (key == null) {
              replyTo['content'] = encryptedMessagePreviewPlaceholder;
            } else {
              replyTo['content'] = await decryptText(
                envelope: envelope,
                key: key,
                messageId: replyId,
                convId: convId,
                type: replyType,
              );
            }
          } else {
            replyTo['content'] = encryptedMessagePreviewPlaceholder;
          }
        } catch (_) {
          replyTo['content'] = encryptedMessageDecryptFailedPlaceholder;
        }
      }
    }

    resolvedMetadata['reply_to'] = replyTo;
    return resolvedMetadata;
  }
}
