import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nineteen_tech_app/core/database/app_database.dart';
import 'package:nineteen_tech_app/features/chat/data/chat_repository.dart';
import 'package:nineteen_tech_app/features/chat/data/conversation_encryption_key.dart';
import 'package:nineteen_tech_app/features/chat/data/conversation_key_repository.dart';
import 'package:nineteen_tech_app/features/chat/data/encrypted_message_adapter.dart';
import 'package:nineteen_tech_app/features/chat/providers/chat_providers.dart';
import 'package:nineteen_tech_app/features/chat/widgets/message_context_menu.dart';

class _MemoryConversationKeyStore implements ConversationKeyStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async {
    this.value = value;
  }
}

class _FakeChatRepository extends ChatRepository {
  _FakeChatRepository(this.payload) : super(Dio());

  final Map<String, dynamic> payload;
  int calls = 0;

  @override
  Future<Map<String, dynamic>> getConversationEncryptionKey(
    String convId,
  ) async {
    calls += 1;
    return payload;
  }
}

void main() {
  group('EncryptedMessageAdapter', () {
    test('encrypts and decrypts a text payload with stable AAD', () async {
      final adapter = EncryptedMessageAdapter();
      const key = ConversationEncryptionKey(
        convId: 'conv-1',
        keyId: 'key-1',
        algorithm: 'AES-256-GCM',
        version: 1,
        material: 'MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=',
      );

      final envelope = await adapter.encryptText(
        plaintext: 'hello encrypted world',
        key: key,
        messageId: 'msg-1',
        convId: 'conv-1',
      );

      final plaintext = await adapter.decryptText(
        envelope: envelope,
        key: key,
        messageId: 'msg-1',
        convId: 'conv-1',
      );

      expect(plaintext, 'hello encrypted world');
    });

    test('resolves encrypted local messages into UI-safe text', () async {
      final adapter = EncryptedMessageAdapter();
      const key = ConversationEncryptionKey(
        convId: 'conv-1',
        keyId: 'key-1',
        algorithm: 'AES-256-GCM',
        version: 1,
        material: 'MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=',
      );

      final envelope = await adapter.encryptText(
        plaintext: 'secret body',
        key: key,
        messageId: 'msg-1',
        convId: 'conv-1',
      );
      final metadata = adapter.buildMetadataJson(envelope: envelope);
      final message = LocalMessage(
        id: 'msg-1',
        convId: 'conv-1',
        senderId: 'user-1',
        type: 'text',
        content: null,
        replyToId: null,
        metadata: metadata,
        createdAt: DateTime(2026),
        editedAt: null,
        deletedAt: null,
        status: 'sent',
        retryCount: 0,
        forwardedFromId: null,
        forwardedFromSender: null,
      );

      final resolved = await adapter.resolveLocalMessageForUi(
        message,
        (convId, keyId) async => key,
      );

      expect(resolved.content, 'secret body');
      expect(
        copyableMessageText(
          LocalMessage(
            id: message.id,
            convId: message.convId,
            senderId: message.senderId,
            type: message.type,
            content: resolved.content,
            replyToId: message.replyToId,
            metadata: resolved.metadataJson,
            createdAt: message.createdAt,
            editedAt: message.editedAt,
            deletedAt: message.deletedAt,
            status: message.status,
            retryCount: message.retryCount,
            forwardedFromId: message.forwardedFromId,
            forwardedFromSender: message.forwardedFromSender,
          ),
        ),
        'secret body',
      );
    });

    test('returns stable placeholder when decrypt fails', () async {
      final adapter = EncryptedMessageAdapter();
      const key = ConversationEncryptionKey(
        convId: 'conv-1',
        keyId: 'key-1',
        algorithm: 'AES-256-GCM',
        version: 1,
        material: 'MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=',
      );

      final envelope = await adapter.encryptText(
        plaintext: 'secret body',
        key: key,
        messageId: 'msg-1',
        convId: 'conv-1',
      );
      final metadata = adapter.buildMetadataJson(envelope: envelope);
      final message = LocalMessage(
        id: 'msg-1',
        convId: 'conv-1',
        senderId: 'user-1',
        type: 'text',
        content: null,
        replyToId: null,
        metadata: metadata,
        createdAt: DateTime(2026),
        editedAt: null,
        deletedAt: null,
        status: 'sent',
        retryCount: 0,
        forwardedFromId: null,
        forwardedFromSender: null,
      );

      final resolved = await adapter.resolveLocalMessageForUi(
        message,
        (convId, keyId) async => ConversationEncryptionKey(
          convId: convId,
          keyId: keyId,
          algorithm: 'AES-256-GCM',
          version: 1,
          material: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
        ),
      );

      expect(resolved.content, encryptedMessageDecryptFailedPlaceholder);
    });

    test(
      'builds stable blind index tokens from normalized plaintext',
      () async {
        final adapter = EncryptedMessageAdapter();
        const key = ConversationEncryptionKey(
          convId: 'conv-1',
          keyId: 'key-1',
          algorithm: 'AES-256-GCM',
          version: 1,
          material: 'MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=',
        );

        final first = await adapter.buildBlindIndexTokens(
          plaintext: 'Hello, HELLO   team!',
          key: key,
        );
        final second = await adapter.buildBlindIndexTokens(
          plaintext: 'hello team',
          key: key,
        );

        expect(first, hasLength(2));
        expect(first, second);
      },
    );

    test(
      'embeds blind index payload into local metadata when requested',
      () async {
        final adapter = EncryptedMessageAdapter();
        const key = ConversationEncryptionKey(
          convId: 'conv-1',
          keyId: 'key-1',
          algorithm: 'AES-256-GCM',
          version: 1,
          material: 'MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=',
        );
        final blindIndex = await adapter.buildBlindIndexPayload(
          plaintext: 'Hop du an luc 10h30',
          key: key,
        );

        final metadataJson = adapter.buildMetadataJson(blindIndex: blindIndex);
        final extracted = adapter.blindIndexFromMetadata(metadataJson);

        expect(extracted?['algo'], EncryptedMessageAdapter.blindIndexAlgorithm);
        expect(extracted?['tokens'], isA<List<dynamic>>());
        expect((extracted?['tokens'] as List).isNotEmpty, isTrue);
      },
    );
  });

  group('ConversationKeyRepository', () {
    test('caches the active key and can look it up by key id', () async {
      final store = _MemoryConversationKeyStore();
      final repo = _FakeChatRepository({
        'conv_id': 'conv-1',
        'key_id': 'key-1',
        'alg': 'AES-256-GCM',
        'version': 1,
        'material': 'MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=',
      });
      final keyRepository = ConversationKeyRepository(repo, store);

      final active = await keyRepository.resolveActiveKey('conv-1');
      final byKeyId = await keyRepository.findKey(
        convId: 'conv-1',
        keyId: 'key-1',
      );

      expect(active.keyId, 'key-1');
      expect(byKeyId?.keyId, 'key-1');
      expect(repo.calls, 1);
      expect(store.value, isNotNull);
    });

    test('scopes cached keys by conv_id and key_id', () async {
      final store = _MemoryConversationKeyStore();
      store.value = ConversationEncryptionKey.encodeList([
        const ConversationEncryptionKey(
          convId: 'conv-1',
          keyId: 'shared-key',
          algorithm: 'AES-256-GCM',
          version: 1,
          material: 'MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=',
        ),
        const ConversationEncryptionKey(
          convId: 'conv-2',
          keyId: 'shared-key',
          algorithm: 'AES-256-GCM',
          version: 1,
          material: 'QUJDREVGR0hJSktMTU5PUFFSU1RVVldYWVo0NTY3ODk=',
        ),
      ]);
      final repo = _FakeChatRepository({
        'conv_id': 'conv-3',
        'key_id': 'key-3',
        'alg': 'AES-256-GCM',
        'version': 1,
        'material': 'MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=',
      });
      final keyRepository = ConversationKeyRepository(repo, store);

      final conv1 = await keyRepository.findKey(
        convId: 'conv-1',
        keyId: 'shared-key',
      );
      final conv2 = await keyRepository.findKey(
        convId: 'conv-2',
        keyId: 'shared-key',
      );

      expect(conv1?.convId, 'conv-1');
      expect(conv2?.convId, 'conv-2');
      expect(conv1?.material, isNot(equals(conv2?.material)));
    });
  });

  group('legacy fallback', () {
    test('falls back to plaintext when encryption endpoint is unavailable', () {
      final error = DioException(
        requestOptions: RequestOptions(
          path: '/conversations/conv-1/encryption-key',
        ),
        response: Response(
          requestOptions: RequestOptions(
            path: '/conversations/conv-1/encryption-key',
          ),
          statusCode: 404,
        ),
      );

      expect(shouldFallbackToLegacyPlaintext(error), isTrue);
    });

    test('does not swallow unrelated encryption failures', () {
      final error = StateError('boom');
      expect(shouldFallbackToLegacyPlaintext(error), isFalse);
    });
  });
}
