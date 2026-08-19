import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'chat_repository.dart';
import 'conversation_encryption_key.dart';

abstract class ConversationKeyStore {
  Future<String?> read();
  Future<void> write(String value);
}

class SecureConversationKeyStore implements ConversationKeyStore {
  SecureConversationKeyStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _storageKey = 'chat_conversation_keys_v1';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _storageKey);

  @override
  Future<void> write(String value) =>
      _storage.write(key: _storageKey, value: value);
}

class ConversationKeyRepository {
  ConversationKeyRepository(this._chatRepository, this._store);

  final ChatRepository _chatRepository;
  final ConversationKeyStore _store;

  final Map<String, ConversationEncryptionKey> _activeByConversation = {};
  final Map<String, ConversationEncryptionKey> _byConversationAndKeyId = {};
  bool _loaded = false;

  Future<ConversationEncryptionKey> resolveActiveKey(String convId) async {
    await _ensureLoaded();
    final cached = _activeByConversation[convId];
    if (cached != null) return cached;
    return refreshActiveKey(convId);
  }

  Future<ConversationEncryptionKey> refreshActiveKey(String convId) async {
    final payload = await _chatRepository.getConversationEncryptionKey(convId);
    final key = ConversationEncryptionKey.fromJson(payload);
    _activeByConversation[convId] = key;
    _byConversationAndKeyId[key.cacheKey] = key;
    await _persist();
    return key;
  }

  Future<ConversationEncryptionKey?> findKey({
    required String convId,
    required String keyId,
    bool refreshIfMissing = false,
  }) async {
    await _ensureLoaded();
    final cached = _byConversationAndKeyId['$convId::$keyId'];
    if (cached != null) return cached;

    if (!refreshIfMissing) return null;
    final refreshed = await refreshActiveKey(convId);
    if (refreshed.keyId == keyId) return refreshed;
    return _byConversationAndKeyId['$convId::$keyId'];
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    final raw = await _store.read();
    if (raw == null || raw.isEmpty) return;

    try {
      final keys = ConversationEncryptionKey.decodeList(raw);
      for (final key in keys) {
        _activeByConversation[key.convId] = key;
        _byConversationAndKeyId[key.cacheKey] = key;
      }
    } catch (_) {
      await _store.write(jsonEncode(const <Map<String, dynamic>>[]));
    }
  }

  Future<void> _persist() async {
    await _store.write(
      ConversationEncryptionKey.encodeList(
        _activeByConversation.values.toList(),
      ),
    );
  }
}
