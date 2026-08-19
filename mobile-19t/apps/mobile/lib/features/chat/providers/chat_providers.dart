import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../data/chat_avatar_resolver.dart';
import '../data/chat_repository.dart';
import '../data/conversation_key_repository.dart';
import '../data/encrypted_message_adapter.dart';
import '../data/user_repository.dart';
import '../data/search_result.dart';
import '../models/bookmarked_message.dart';
import '../models/link_preview.dart';
import '../models/message_seen_by.dart';
import '../models/reaction_group.dart';
import '../../auth/providers/auth_notifier.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/chat_dao.dart';
import '../../../core/network/websocket_manager.dart';
import '../../../core/network/websocket_provider.dart';
import '../../../core/notifications/badge_sync_service.dart';
import '../../../core/router/chat_route_utils.dart';

export '../models/bookmarked_message.dart';
export '../models/message_seen_by.dart';

const _uuid = Uuid();
const _chatListReconciliationDelay = Duration(milliseconds: 350);
const chatConversationPreviewMessageLimit = 30;
const _globalBookmarkPageSize = 20;

typedef MessageSeenByRequest = ({String convId, String messageId});

/// Exception thrown when editing a message fails due to validation or
/// permission errors from the server.
class EditMessageException implements Exception {
  const EditMessageException({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => message;
}

class ConversationSeenByPlacementRequest {
  const ConversationSeenByPlacementRequest({
    required this.convId,
    required this.messageIdsNewestFirst,
    required this.currentUserId,
  });

  final String convId;
  final List<String> messageIdsNewestFirst;
  final String currentUserId;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConversationSeenByPlacementRequest &&
        other.convId == convId &&
        other.currentUserId == currentUserId &&
        listEquals(other.messageIdsNewestFirst, messageIdsNewestFirst);
  }

  @override
  int get hashCode =>
      Object.hash(convId, currentUserId, Object.hashAll(messageIdsNewestFirst));
}

Future<String> currentUserIdFromAuth(Ref ref) async {
  final cachedUserId =
      ref.read(authNotifierProvider).valueOrNull?.user?.id ?? '';
  if (cachedUserId.isNotEmpty) {
    return cachedUserId;
  }

  final authState = await ref.read(authNotifierProvider.future);
  return authState.user?.id ?? '';
}

enum ChatConversationEntryMode { full, preview }

@visibleForTesting
bool shouldMarkConversationReadForEntry(ChatConversationEntryMode mode) {
  return mode == ChatConversationEntryMode.full;
}

@visibleForTesting
List<LocalMessage> normalizeConversationPreviewMessages(
  Iterable<LocalMessage> messages, {
  int limit = chatConversationPreviewMessageLimit,
}) {
  final sorted = messages.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return sorted.take(limit).toList().reversed.toList();
}

@visibleForTesting
String? buildConversationPreviewText({
  required String type,
  String? content,
  dynamic metadata,
  DateTime? deletedAt,
}) {
  if (deletedAt != null) {
    return 'Tin nhắn đã được thu hồi';
  }
  switch (type) {
    case 'image':
      return 'Ảnh${content != null && content.isNotEmpty ? ' - $content' : ''}';
    case 'album':
      var count = 1;
      if (metadata is Map<String, dynamic>) {
        count = (metadata['images'] as List?)?.length ?? 1;
      }
      return '$count ảnh${content != null && content.isNotEmpty ? ' - $content' : ''}';
    case 'voice':
      return 'Tin nhắn thoại';
    case 'video':
      return 'Video${content != null && content.isNotEmpty ? ' - $content' : ''}';
    case 'file':
      return content != null && content.isNotEmpty ? content : 'Tệp đính kèm';
    case 'system':
      return null;
    default:
      if (metadata is Map<String, dynamic> &&
          metadata.containsKey(EncryptedMessageAdapter.envelopeMetadataKey) &&
          (content == null || content.isEmpty)) {
        return encryptedMessagePreviewPlaceholder;
      }
      return content;
  }
}

Map<String, dynamic>? _decodeMessageMetadata(String? metadata) {
  if (metadata == null || metadata.isEmpty) return null;
  try {
    final decoded = jsonDecode(metadata);
    if (decoded is Map<String, dynamic>) return decoded;
  } catch (_) {}
  return null;
}

@visibleForTesting
String? buildConversationPreviewFromLocalMessage(LocalMessage message) {
  return buildConversationPreviewText(
    type: message.type,
    content: message.content,
    metadata: _decodeMessageMetadata(message.metadata),
    deletedAt: message.deletedAt,
  );
}

Future<String?> _resolveConversationPreviewFromApiMessage(
  Ref ref,
  Map<String, dynamic>? lastMsg, {
  required String convId,
}) async {
  if (lastMsg == null) return null;

  final type = lastMsg['type'] as String? ?? 'text';
  final content = lastMsg['content'] as String?;
  final deletedAt = _parseApiDateTime(lastMsg['deleted_at']);
  final metadata = lastMsg['metadata'];

  if (type != 'text' || deletedAt != null) {
    return buildConversationPreviewText(
      type: type,
      content: content,
      metadata: metadata,
      deletedAt: deletedAt,
    );
  }

  Map<String, dynamic>? metadataMap;
  if (metadata is Map<String, dynamic>) {
    metadataMap = metadata;
  } else if (metadata is Map) {
    metadataMap = Map<String, dynamic>.from(metadata);
  } else if (metadata is String && metadata.isNotEmpty) {
    metadataMap = _decodeMessageMetadata(metadata);
  }

  final adapter = ref.read(encryptedMessageAdapterProvider);
  final envelopeRaw = metadataMap?[EncryptedMessageAdapter.envelopeMetadataKey];
  if (envelopeRaw is Map && (content == null || content.isEmpty)) {
    try {
      final envelope = EncryptedMessageEnvelope.fromJson(
        Map<String, dynamic>.from(envelopeRaw),
      );
      final keyRepository = ref.read(conversationKeyRepositoryProvider);
      final key = await keyRepository.findKey(
        convId: convId,
        keyId: envelope.keyId,
        refreshIfMissing: true,
      );

      if (key != null) {
        final decrypted = await adapter.decryptText(
          envelope: envelope,
          key: key,
          messageId: lastMsg['id'] as String,
          convId: convId,
          type: type,
        );
        return buildConversationPreviewText(
          type: type,
          content: decrypted,
          metadata: metadataMap,
          deletedAt: deletedAt,
        );
      }
    } catch (e) {
      debugPrint('[ChatList] Failed to decrypt last message preview: $e');
    }
  }

  return buildConversationPreviewText(
    type: type,
    content: content,
    metadata: metadataMap ?? metadata,
    deletedAt: deletedAt,
  );
}

String? _decorateConversationListPreview({
  required String conversationType,
  required String? preview,
  required Map<String, dynamic>? lastMsg,
  required String currentUserId,
}) {
  if (preview == null || preview.isEmpty) return preview;
  if (conversationType != 'GROUP') return preview;

  final messageType = lastMsg?['type'] as String? ?? 'text';
  if (messageType == 'system') {
    return preview;
  }

  final senderId = lastMsg?['sender_id'] as String?;
  if (senderId != null &&
      senderId.isNotEmpty &&
      currentUserId.isNotEmpty &&
      senderId == currentUserId) {
    return 'Bạn: $preview';
  }

  final senderName = lastMsg?['sender_name'] as String?;
  if (senderName != null && senderName.trim().isNotEmpty) {
    return '${senderName.trim()}: $preview';
  }

  return preview;
}

@visibleForTesting
Future<bool> syncConversationPreviewFromLatestMessage(
  ChatDao dao, {
  required String convId,
  String? changedMessageId,
}) async {
  final conversation = await dao.getConversation(convId);
  if (conversation == null) return false;

  final latestMessages = await dao.getMessages(convId, limit: 1);
  if (latestMessages.isEmpty) return false;

  final latestMessage = latestMessages.first;
  if (changedMessageId != null && latestMessage.id != changedMessageId) {
    return false;
  }

  await dao.updateConversation(
    convId,
    LocalConversationsCompanion(
      lastMessageAt: Value(latestMessage.createdAt),
      lastMessageContent: Value(
        buildConversationPreviewFromLocalMessage(latestMessage),
      ),
      lastMessageSenderId: Value(latestMessage.senderId),
    ),
  );
  return true;
}

bool shouldTreatConversationAsRead(
  DateTime? lastViewedAt,
  DateTime? lastMessageAt,
) {
  if (lastViewedAt == null) return false;
  if (lastMessageAt == null) return true;
  return !lastMessageAt.isAfter(lastViewedAt);
}

bool isConversationActivelyViewed({
  required String conversationId,
  required String? activeConversationId,
}) {
  if (activeConversationId == null || activeConversationId.isEmpty) {
    return false;
  }
  return activeConversationId == conversationId;
}

bool shouldForceReadForActiveConversation({
  required String conversationId,
  required String? activeConversationId,
  required DateTime? lastViewedAt,
  required DateTime? lastMessageAt,
}) {
  if (!isConversationActivelyViewed(
    conversationId: conversationId,
    activeConversationId: activeConversationId,
  )) {
    return false;
  }
  return shouldTreatConversationAsRead(lastViewedAt, lastMessageAt);
}

int resolveConversationUnreadCount({
  required String conversationId,
  required String? activeConversationId,
  required DateTime? lastViewedAt,
  required DateTime? lastMessageAt,
  required int serverUnreadCount,
}) {
  final shouldForceRead = shouldForceReadForActiveConversation(
    conversationId: conversationId,
    activeConversationId: activeConversationId,
    lastViewedAt: lastViewedAt,
    lastMessageAt: lastMessageAt,
  );
  return shouldForceRead ? 0 : serverUnreadCount;
}

int resolveConversationUnreadMentionCount({
  required String conversationId,
  required String? activeConversationId,
  required DateTime? lastViewedAt,
  required DateTime? lastMessageAt,
  required int serverUnreadMentionCount,
}) {
  final shouldForceRead = shouldForceReadForActiveConversation(
    conversationId: conversationId,
    activeConversationId: activeConversationId,
    lastViewedAt: lastViewedAt,
    lastMessageAt: lastMessageAt,
  );
  return shouldForceRead ? 0 : serverUnreadMentionCount;
}

bool shouldIncrementUnreadForInboundMessage({
  required String conversationId,
  required String? activeConversationId,
  required String senderId,
  required String currentUserId,
}) {
  if (currentUserId.isNotEmpty && senderId == currentUserId) {
    return false;
  }
  return !isConversationActivelyViewed(
    conversationId: conversationId,
    activeConversationId: activeConversationId,
  );
}

int nextUnreadCountForInboundMessage({
  required int currentUnreadCount,
  required String conversationId,
  required String? activeConversationId,
  required String senderId,
  required String currentUserId,
}) {
  final shouldIncrement = shouldIncrementUnreadForInboundMessage(
    conversationId: conversationId,
    activeConversationId: activeConversationId,
    senderId: senderId,
    currentUserId: currentUserId,
  );
  if (!shouldIncrement) return currentUnreadCount;
  return currentUnreadCount + 1;
}

bool shouldScheduleChatListReconciliation({
  required String? conversationId,
  required bool hasRefreshInFlight,
}) {
  if (conversationId == null || conversationId.isEmpty) return false;
  return !hasRefreshInFlight;
}

DateTime? _parseApiDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

String? _buildMessageMetadata(
  Map<String, dynamic> data, {
  Map<String, dynamic>? existingMetadata,
}) {
  final encryptedEnvelope = data['encrypted_content'];
  if (data['metadata'] == null &&
      encryptedEnvelope == null &&
      data['reply_to'] == null &&
      existingMetadata == null) {
    return null;
  }

  final metaMap = <String, dynamic>{...?existingMetadata};
  final oldEnvelope = metaMap[EncryptedMessageAdapter.envelopeMetadataKey];
  final oldReplyTo = metaMap['reply_to'];

  if (data['metadata'] != null) {
    metaMap
      ..clear()
      ..addAll(
        data['metadata'] is String
            ? jsonDecode(data['metadata'] as String) as Map<String, dynamic>
            : Map<String, dynamic>.from(data['metadata'] as Map),
      );
  }

  if (encryptedEnvelope != null) {
    metaMap[EncryptedMessageAdapter.envelopeMetadataKey] =
        encryptedEnvelope is Map<String, dynamic>
        ? encryptedEnvelope
        : Map<String, dynamic>.from(encryptedEnvelope as Map);
  } else if (oldEnvelope != null &&
      !metaMap.containsKey(EncryptedMessageAdapter.envelopeMetadataKey)) {
    metaMap[EncryptedMessageAdapter.envelopeMetadataKey] = oldEnvelope;
  }

  if (data['reply_to'] != null) {
    metaMap['reply_to'] = data['reply_to'];
  } else if (oldReplyTo != null && !metaMap.containsKey('reply_to')) {
    metaMap['reply_to'] = oldReplyTo;
  }

  return metaMap.isEmpty ? null : jsonEncode(metaMap);
}

Map<String, dynamic>? _safeReplySnapshot(LocalMessage message) {
  final metadata = _decodeMessageMetadata(message.metadata);
  final isEncrypted =
      message.type == 'text' &&
      metadata != null &&
      metadata.containsKey(EncryptedMessageAdapter.envelopeMetadataKey);

  final content = isEncrypted
      ? (message.content ?? encryptedMessagePreviewPlaceholder)
      : message.content;

  return {
    'id': message.id,
    'sender_id': message.senderId,
    'sender_name': null,
    'content': content,
    'type': message.type,
  };
}

Future<LocalMessage> _resolveLocalMessageForUi(
  Ref ref,
  LocalMessage message,
) async {
  final adapter = ref.read(encryptedMessageAdapterProvider);
  final keyRepository = ref.read(conversationKeyRepositoryProvider);
  final resolved = await adapter.resolveLocalMessageForUi(message, (
    convId,
    keyId,
  ) async {
    final key = await keyRepository.findKey(
      convId: convId,
      keyId: keyId,
      refreshIfMissing: true,
    );
    return key;
  });

  return LocalMessage(
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
  );
}

Future<List<LocalMessage>> _resolveLocalMessagesForUi(
  Ref ref,
  Iterable<LocalMessage> messages,
) async {
  return Future.wait(
    messages.map((message) => _resolveLocalMessageForUi(ref, message)),
  );
}

final reminderSourcePreviewProvider =
    FutureProvider.family<String?, ({String convId, String messageId})>((
      ref,
      request,
    ) async {
      if (request.messageId.isEmpty) return null;
      final dao = ref.read(chatDaoProvider);
      var source = await dao.getMessage(request.messageId);
      if (source == null) {
        try {
          final repo = ref.read(chatRepositoryProvider);
          final payload = await repo.getMessage(request.messageId);
          if (payload['conv_id'] == request.convId) {
            await dao.insertMessage(
              buildIncomingMessageCompanion(payload, defaultStatus: 'sent'),
            );
            source = await dao.getMessage(request.messageId);
          }
        } catch (e) {
          debugPrint('[ChatReminder] Failed to fetch source message: $e');
        }
      }
      if (source == null || source.convId != request.convId) return null;
      final resolved = await _resolveLocalMessageForUi(ref, source);
      final content = resolved.content?.trim();
      if (content == null || content.isEmpty) return null;
      if (content == encryptedMessagePreviewPlaceholder ||
          content == encryptedMessageDecryptFailedPlaceholder) {
        return null;
      }
      return content.length <= 120 ? content : '${content.substring(0, 120)}…';
    });

bool shouldFallbackToLegacyPlaintext(Object error) {
  if (error is! DioException) return false;
  final statusCode = error.response?.statusCode;
  return statusCode == 404 || statusCode == 405 || statusCode == 501;
}

bool shouldSynchronizeChatRoomOnConnectedTransition({
  required WsConnectionState? previousState,
  required WsConnectionState nextState,
}) {
  if (nextState != WsConnectionState.connected) {
    return false;
  }
  return previousState != WsConnectionState.connected;
}

bool shouldSynchronizeVisibleChatRoomOnReconnect({
  required String conversationId,
  required String? activeConversationId,
  required WsConnectionState? previousState,
  required WsConnectionState nextState,
}) {
  if (!shouldSynchronizeChatRoomOnConnectedTransition(
    previousState: previousState,
    nextState: nextState,
  )) {
    return false;
  }
  return isConversationActivelyViewed(
    conversationId: conversationId,
    activeConversationId: activeConversationId,
  );
}

LocalMessagesCompanion buildIncomingMessageCompanion(
  Map<String, dynamic> data, {
  String defaultStatus = 'delivered',
}) {
  final metadataStr = _buildMessageMetadata(data);
  final metaMap = _decodeMessageMetadata(metadataStr);
  final hasEncryptedEnvelope =
      data['encrypted_content'] != null ||
      (metaMap != null &&
          metaMap.containsKey(EncryptedMessageAdapter.envelopeMetadataKey));

  return LocalMessagesCompanion.insert(
    id: data['id'] as String,
    convId: data['conv_id'] as String,
    senderId: data['sender_id'] as String,
    createdAt: DateTime.parse(data['created_at'] as String),
    type: Value(data['type'] as String? ?? 'text'),
    content: Value(hasEncryptedEnvelope ? null : data['content'] as String?),
    replyToId: Value(data['reply_to_id'] as String?),
    metadata: Value(metadataStr),
    editedAt: Value(_parseApiDateTime(data['edited_at'])),
    deletedAt: Value(_parseApiDateTime(data['deleted_at'])),
    status: Value(defaultStatus),
    forwardedFromId: Value(data['forwarded_from_id'] as String?),
    forwardedFromSender: Value(data['forwarded_from_sender'] as String?),
  );
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return ChatRepository(dio);
});

final encryptedMessageAdapterProvider = Provider<EncryptedMessageAdapter>((
  ref,
) {
  return EncryptedMessageAdapter();
});

final conversationKeyRepositoryProvider = Provider<ConversationKeyRepository>((
  ref,
) {
  final repo = ref.watch(chatRepositoryProvider);
  return ConversationKeyRepository(repo, SecureConversationKeyStore());
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return UserRepository(dio);
});

// --- Audio Player ---

final audioPlayerProvider = Provider<AudioPlayer>((ref) {
  final player = AudioPlayer();
  ref.onDispose(() => player.dispose());
  return player;
});

final currentlyPlayingMessageProvider = StateProvider<String?>((ref) => null);
final currentVisibleRouteLocationProvider = StateProvider<String?>(
  (ref) => null,
);
final appLifecycleStateProvider = StateProvider<AppLifecycleState>(
  (ref) => WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed,
);

bool isInteractiveForegroundAppState(AppLifecycleState state) {
  return state == AppLifecycleState.resumed;
}

final activeChatConversationIdProvider = Provider<String?>((ref) {
  final lifecycleState = ref.watch(appLifecycleStateProvider);
  if (!isInteractiveForegroundAppState(lifecycleState)) {
    return null;
  }

  final currentRouteLocation = ref.watch(currentVisibleRouteLocationProvider);
  return conversationIdForChatLocation(currentRouteLocation);
});
final chatHistoryPaginationProvider =
    StateProvider.family<ChatHistoryPaginationState, String>(
      (ref, _) => const ChatHistoryPaginationState(),
    );

class ChatHistoryPaginationState {
  const ChatHistoryPaginationState({this.nextCursor, this.hasMore = true});

  final String? nextCursor;
  final bool hasMore;

  ChatHistoryPaginationState copyWith({
    Object? nextCursor = _chatPaginationCursorUnset,
    bool? hasMore,
  }) {
    return ChatHistoryPaginationState(
      nextCursor: nextCursor == _chatPaginationCursorUnset
          ? this.nextCursor
          : nextCursor as String?,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

const _chatPaginationCursorUnset = Object();

final chatConversationPreviewProvider =
    AsyncNotifierProvider.family<
      ChatConversationPreviewNotifier,
      List<LocalMessage>,
      String
    >(ChatConversationPreviewNotifier.new);

class ChatConversationPreviewNotifier
    extends FamilyAsyncNotifier<List<LocalMessage>, String> {
  @override
  Future<List<LocalMessage>> build(String convId) async {
    final dao = ref.read(chatDaoProvider);
    final cached = await dao.getMessages(
      convId,
      limit: chatConversationPreviewMessageLimit,
    );
    unawaited(_refreshFromApi());
    return normalizeConversationPreviewMessages(
      await _resolveLocalMessagesForUi(ref, cached),
    );
  }

  Future<void> refresh() => _refreshFromApi();

  Future<void> _refreshFromApi() async {
    try {
      final repo = ref.read(chatRepositoryProvider);
      final dao = ref.read(chatDaoProvider);
      final result = await repo.getMessages(arg);
      final messages = result['messages'] as List? ?? [];

      for (final item in messages) {
        final message = item as Map<String, dynamic>;
        try {
          await dao.insertMessage(
            buildIncomingMessageCompanion(message, defaultStatus: 'sent'),
          );
        } catch (e) {
          debugPrint('[ChatPreview] Failed to cache message: $e');
        }
      }

      final updated = await dao.getMessages(
        arg,
        limit: chatConversationPreviewMessageLimit,
      );
      state = AsyncData(
        normalizeConversationPreviewMessages(
          await _resolveLocalMessagesForUi(ref, updated),
        ),
      );
    } catch (e) {
      debugPrint('[ChatPreview] Failed to refresh preview: $e');
    }
  }
}

// --- Chat List ---

final chatListProvider =
    AsyncNotifierProvider<ChatListNotifier, List<LocalConversation>>(
      ChatListNotifier.new,
    );

class ChatListNotifier extends AsyncNotifier<List<LocalConversation>> {
  Future<void>? _refreshOperation;
  bool _refreshQueued = false;
  Timer? _reconciliationTimer;

  @override
  Future<List<LocalConversation>> build() async {
    final dao = ref.read(chatDaoProvider);

    // Load from local cache first
    final cached = await dao.getConversations();

    // Refresh from API in background
    _refreshFromApi();

    // Listen for WS message events
    final wsManager = ref.read(webSocketManagerProvider);
    wsManager.on('new_message', _onNewMessage);
    wsManager.on('message_updated', _onMessageUpdated);
    wsManager.on('message_recalled', _onMessageRecalled);
    ref.onDispose(() {
      wsManager.off('new_message', _onNewMessage);
      wsManager.off('message_updated', _onMessageUpdated);
      wsManager.off('message_recalled', _onMessageRecalled);
      _reconciliationTimer?.cancel();
    });

    return cached;
  }

  void _onNewMessage(Map<String, dynamic> data) {
    // Update conversation in list
    final convId = data['conv_id'] as String?;
    if (convId == null) return;
    final senderId = data['sender_id'] as String?;

    // Update conversation preview with proper message type handling
    final dao = ref.read(chatDaoProvider);
    final preview = _lastMessagePreview(data);
    final createdAt = data['created_at'] as String?;
    unawaited(() async {
      try {
        await dao.insertMessage(buildIncomingMessageCompanion(data));
      } catch (e) {
        debugPrint('[ChatList] Failed to persist incoming message: $e');
      }

      try {
        final activeConversationId = ref.read(activeChatConversationIdProvider);
        final currentUserId =
            ref.read(authNotifierProvider).valueOrNull?.user?.id ?? '';
        final localConversation = await dao.getConversation(convId);
        final currentUnreadCount = localConversation?.unreadCount ?? 0;
        final nextUnreadCount = senderId == null
            ? null
            : nextUnreadCountForInboundMessage(
                currentUnreadCount: currentUnreadCount,
                conversationId: convId,
                activeConversationId: activeConversationId,
                senderId: senderId,
                currentUserId: currentUserId,
              );

        await dao.updateConversation(
          convId,
          LocalConversationsCompanion(
            lastMessageAt: Value(
              createdAt != null ? DateTime.parse(createdAt) : DateTime.now(),
            ),
            lastMessageContent: Value(preview),
            lastMessageSenderId: Value(senderId),
            unreadCount: nextUnreadCount != null
                ? Value(nextUnreadCount)
                : const Value.absent(),
          ),
        );
      } catch (e) {
        debugPrint('[ChatList] Failed to update conversation preview: $e');
      }

      await ref.read(badgeSyncServiceProvider).syncFromLocalUnreadTotal();
      ref.invalidateSelf();
      _scheduleReconciliationRefresh(convId);
    }());
  }

  Future<void> _refreshFromApi() async {
    final inFlight = _refreshOperation;
    if (inFlight != null) {
      _refreshQueued = true;
      await inFlight;
      return;
    }

    final operation = _runRefreshFromApi();
    _refreshOperation = operation;
    try {
      await operation;
    } finally {
      if (identical(_refreshOperation, operation)) {
        _refreshOperation = null;
      }
      if (_refreshQueued) {
        _refreshQueued = false;
        unawaited(_refreshFromApi());
      }
    }
  }

  Future<void> _runRefreshFromApi() async {
    try {
      final repo = ref.read(chatRepositoryProvider);
      final dao = ref.read(chatDaoProvider);
      final authState = ref.read(authNotifierProvider);
      final currentUserId = authState.valueOrNull?.user?.id ?? '';
      final localConversations = await dao.getConversations();
      final localConversationById = {
        for (final conversation in localConversations)
          conversation.id: conversation,
      };
      final activeConversationId = ref.read(activeChatConversationIdProvider);
      final result = await repo.getConversations();
      final conversations = result['conversations'] as List? ?? [];

      final entries = await Future.wait(
        conversations.map((c) async {
          final conv = c as Map<String, dynamic>;
          final conversationId = conv['id'] as String;
          final conversationType = conv['type'] as String? ?? 'DIRECT';
          final lastMsg = conv['lastMessage'] as Map<String, dynamic>?;
          final lastMessageAt = conv['last_message_at'] != null
              ? DateTime.parse(conv['last_message_at'] as String)
              : null;
          final localConversation = localConversationById[conversationId];
          final localLastViewedAt = localConversation?.lastViewedAt;
          final unreadCount = resolveConversationUnreadCount(
            conversationId: conversationId,
            activeConversationId: activeConversationId,
            lastViewedAt: localLastViewedAt,
            lastMessageAt: lastMessageAt,
            serverUnreadCount: conv['unreadCount'] as int? ?? 0,
          );
          final unreadMentionCount = resolveConversationUnreadMentionCount(
            conversationId: conversationId,
            activeConversationId: activeConversationId,
            lastViewedAt: localLastViewedAt,
            lastMessageAt: lastMessageAt,
            serverUnreadMentionCount: conv['unreadMentionCount'] as int? ?? 0,
          );

          // Extract other member info for DIRECT conversations
          String? otherMemberName;
          String? otherMemberAvatar;
          DateTime? otherMemberLastSeenAt;
          if ((conv['type'] as String? ?? 'DIRECT') == 'DIRECT') {
            final members = conv['members'] as List? ?? [];
            for (final m in members) {
              final member = m as Map<String, dynamic>;
              final user = member['user'] as Map<String, dynamic>?;
              if (user != null && user['id'] != currentUserId) {
                otherMemberName = user['name'] as String?;
                otherMemberAvatar = resolveChatAvatarUrl(
                  user['avatar_url'] as String?,
                );
                final lastSeen = user['last_seen_at'] as String?;
                if (lastSeen != null) {
                  otherMemberLastSeenAt = DateTime.tryParse(lastSeen);
                }
                break;
              }
            }
          }

          final resolvedPreview =
              await _resolveConversationPreviewFromApiMessage(
                ref,
                lastMsg,
                convId: conversationId,
              );
          final decoratedPreview = _decorateConversationListPreview(
            conversationType: conversationType,
            preview: resolvedPreview,
            lastMsg: lastMsg,
            currentUserId: currentUserId,
          );

          return LocalConversationsCompanion.insert(
            id: conversationId,
            createdBy: conv['created_by'] as String? ?? '',
            createdAt: DateTime.parse(conv['created_at'] as String),
            type: Value(conversationType),
            name: Value(conv['name'] as String?),
            avatarUrl: Value(
              resolveChatAvatarUrl(conv['avatar_url'] as String?),
            ),
            lastMessageAt: Value(lastMessageAt),
            lastMessageContent: Value(decoratedPreview),
            lastMessageSenderId: Value(lastMsg?['sender_id'] as String?),
            unreadCount: Value(unreadCount),
            unreadMentionCount: Value(unreadMentionCount),
            otherMemberName: Value(otherMemberName),
            otherMemberAvatar: Value(otherMemberAvatar),
            otherMemberLastSeenAt: Value(otherMemberLastSeenAt),
            lastViewedAt: Value(localLastViewedAt),
          );
        }),
      );

      await dao.insertConversations(entries);

      // Remove local conversations that no longer exist on the server
      final remoteIds = entries.map((e) => e.id.value).toSet();
      if (remoteIds.isNotEmpty) {
        await dao.deleteConversationsNotIn(remoteIds);
      }

      await ref.read(badgeSyncServiceProvider).syncFromLocalUnreadTotal();
      state = AsyncData(await dao.getConversations());
    } catch (e) {
      // Silently fail — we already have cached data
    }
  }

  void _scheduleReconciliationRefresh(String convId) {
    if (!shouldScheduleChatListReconciliation(
      conversationId: convId,
      hasRefreshInFlight: _refreshOperation != null,
    )) {
      if (convId.isNotEmpty && _refreshOperation != null) {
        _refreshQueued = true;
      }
      return;
    }

    _reconciliationTimer?.cancel();
    _reconciliationTimer = Timer(_chatListReconciliationDelay, () {
      _reconciliationTimer = null;
      unawaited(_refreshFromApi());
    });
  }

  Future<void> refresh() async {
    await _refreshFromApi();
  }

  static String? _lastMessagePreview(Map<String, dynamic>? lastMsg) {
    if (lastMsg == null) return null;
    return buildConversationPreviewText(
      type: lastMsg['type'] as String? ?? 'text',
      content: lastMsg['content'] as String?,
      metadata: lastMsg['metadata'],
      deletedAt: _parseApiDateTime(lastMsg['deleted_at']),
    );
  }

  Future<void> _applyRemoteMessageUpdate(Map<String, dynamic> data) async {
    final dao = ref.read(chatDaoProvider);
    final existing = await dao.getMessage(data['id'] as String);
    if (existing == null) {
      await dao.insertMessage(
        buildIncomingMessageCompanion(data, defaultStatus: 'sent'),
      );
    } else {
      final metadataStr = _buildMessageMetadata(
        data,
        existingMetadata: _decodeMessageMetadata(existing.metadata),
      );
      final metaMap = _decodeMessageMetadata(metadataStr);
      final hasEncryptedEnvelope =
          data['encrypted_content'] != null ||
          (metaMap != null &&
              metaMap.containsKey(EncryptedMessageAdapter.envelopeMetadataKey));

      await dao.updateMessageFromRemote(
        data['id'] as String,
        content: hasEncryptedEnvelope ? null : data['content'] as String?,
        metadata: metadataStr,
        editedAt: _parseApiDateTime(data['edited_at']),
        deletedAt: _parseApiDateTime(data['deleted_at']),
      );
    }
  }

  Future<void> _syncPreviewFromMessageMutation(
    Map<String, dynamic> data,
  ) async {
    final convId = data['conv_id'] as String?;
    final messageId = data['id'] as String?;
    if (convId == null || messageId == null) return;

    final dao = ref.read(chatDaoProvider);
    await _applyRemoteMessageUpdate(data);
    await syncConversationPreviewFromLatestMessage(
      dao,
      convId: convId,
      changedMessageId: messageId,
    );
    state = AsyncData(await dao.getConversations());
    _scheduleReconciliationRefresh(convId);
  }

  void _onMessageUpdated(Map<String, dynamic> data) {
    unawaited(() async {
      try {
        await _syncPreviewFromMessageMutation(data);
      } catch (e) {
        debugPrint('[ChatList] Failed to sync edited preview: $e');
      }
    }());
  }

  void _onMessageRecalled(Map<String, dynamic> data) {
    unawaited(() async {
      try {
        await _syncPreviewFromMessageMutation(data);
      } catch (e) {
        debugPrint('[ChatList] Failed to sync recalled preview: $e');
      }
    }());
  }
}

// --- Chat Messages ---

final conversationDetailProvider =
    FutureProvider.family<LocalConversation?, String>((ref, id) async {
      final dao = ref.read(chatDaoProvider);
      final local = await dao.getConversation(id);
      if (local != null) return local;

      // Fallback: fetch from API and store locally
      try {
        final repo = ref.read(chatRepositoryProvider);
        final authState = ref.read(authNotifierProvider);
        final currentUserId = authState.valueOrNull?.user?.id ?? '';
        final result = await repo.getConversation(id);

        String? otherMemberName;
        String? otherMemberAvatar;
        DateTime? otherMemberLastSeenAt;
        if ((result['type'] as String? ?? 'DIRECT') == 'DIRECT') {
          final members = result['members'] as List? ?? [];
          for (final m in members) {
            final member = m as Map<String, dynamic>;
            final user = member['user'] as Map<String, dynamic>?;
            if (user != null && user['id'] != currentUserId) {
              otherMemberName = user['name'] as String?;
              otherMemberAvatar = resolveChatAvatarUrl(
                user['avatar_url'] as String?,
              );
              final lastSeen = user['last_seen_at'] as String?;
              if (lastSeen != null) {
                otherMemberLastSeenAt = DateTime.tryParse(lastSeen);
              }
              break;
            }
          }
        }

        final entry = LocalConversationsCompanion.insert(
          id: result['id'] as String,
          createdBy: result['created_by'] as String? ?? '',
          createdAt: DateTime.parse(result['created_at'] as String),
          type: Value(result['type'] as String? ?? 'DIRECT'),
          name: Value(result['name'] as String?),
          avatarUrl: Value(
            resolveChatAvatarUrl(result['avatar_url'] as String?),
          ),
          otherMemberName: Value(otherMemberName),
          otherMemberAvatar: Value(otherMemberAvatar),
          otherMemberLastSeenAt: Value(otherMemberLastSeenAt),
        );
        await dao.insertConversation(entry);
        return dao.getConversation(id);
      } catch (_) {
        return null;
      }
    });

// --- Chat Messages ---

/// Returns a map of {userId: {name, avatar}} for all members of a conversation.
/// Used to display sender names/avatars in group chat bubbles.
final conversationMembersProvider =
    FutureProvider.family<Map<String, Map<String, String?>>, String>((
      ref,
      convId,
    ) async {
      try {
        final repo = ref.read(chatRepositoryProvider);
        final result = await repo.getConversation(convId);
        final members = result['members'] as List? ?? [];
        final map = <String, Map<String, String?>>{};
        for (final m in members) {
          final member = m as Map<String, dynamic>;
          final user = member['user'] as Map<String, dynamic>?;
          if (user != null) {
            map[user['id'] as String] = {
              'name': user['name'] as String?,
              'avatar': resolveChatAvatarUrl(user['avatar_url'] as String?),
              'role': member['role'] as String?,
            };
          }
        }
        return map;
      } catch (_) {
        return {};
      }
    });

// --- Message Reactions ---

final messageReactionsProvider =
    StreamProvider.family<List<ReactionGroup>, String>((ref, messageId) {
      final dao = ref.watch(chatDaoProvider);
      final authState = ref.watch(authNotifierProvider);
      final currentUserId = authState.valueOrNull?.user?.id ?? '';

      return dao.watchReactionsForMessage(messageId).map((reactions) {
        final groups = <String, ReactionGroup>{};
        for (final r in reactions) {
          final existing = groups[r.emoji];
          final user = ReactionUser(id: r.userId, name: r.userName);
          if (existing != null) {
            groups[r.emoji] = ReactionGroup(
              emoji: r.emoji,
              count: existing.count + 1,
              users: [...existing.users, user],
              isMine: existing.isMine || r.userId == currentUserId,
            );
          } else {
            groups[r.emoji] = ReactionGroup(
              emoji: r.emoji,
              count: 1,
              users: [user],
              isMine: r.userId == currentUserId,
            );
          }
        }
        return groups.values.toList();
      });
    });

// --- Pinned Messages ---

class PinnedMessageData {
  final String messageId;
  final String convId;
  final String pinnedBy;
  final DateTime pinnedAt;
  final String? messageContent;
  final Map<String, dynamic>? messageMetadata;
  final String? messageType;
  final String? senderId;
  final String? senderName;
  final String? pinnerName;

  PinnedMessageData({
    required this.messageId,
    required this.convId,
    required this.pinnedBy,
    required this.pinnedAt,
    this.messageContent,
    this.messageMetadata,
    this.messageType,
    this.senderId,
    this.senderName,
    this.pinnerName,
  });
}

Map<String, dynamic>? _decodePinnedMessageMetadata(Object? metadata) {
  if (metadata == null) return null;
  if (metadata is Map<String, dynamic>) return metadata;
  if (metadata is Map) return Map<String, dynamic>.from(metadata);
  if (metadata is String && metadata.isNotEmpty) {
    return _decodeMessageMetadata(metadata);
  }
  return null;
}

Future<String?> _resolvePinnedMessageContent(
  Ref ref,
  Map<String, dynamic> pin, {
  required String convId,
  required String messageId,
  required String messageType,
}) async {
  final content = (pin['message_content'] as String?)?.trim();
  if (messageType != 'text') {
    return content;
  }
  if (content != null && content.isNotEmpty) {
    return content;
  }

  final metadata = _decodePinnedMessageMetadata(
    pin['message_metadata'] ?? pin['message_metatdata'],
  );
  final adapter = ref.read(encryptedMessageAdapterProvider);
  final envelopeRaw = metadata?[EncryptedMessageAdapter.envelopeMetadataKey];
  if (envelopeRaw is! Map) {
    return content;
  }

  try {
    final envelope = EncryptedMessageEnvelope.fromJson(
      Map<String, dynamic>.from(envelopeRaw),
    );
    final keyRepository = ref.read(conversationKeyRepositoryProvider);
    final key = await keyRepository.findKey(
      convId: convId,
      keyId: envelope.keyId,
      refreshIfMissing: true,
    );

    if (key == null) {
      debugPrint(
        '[PinnedMessages] Missing key for message_id=$messageId '
        'conv_id=$convId key_id=${envelope.keyId}',
      );
      return encryptedMessagePreviewPlaceholder;
    }

    return await adapter.decryptText(
      envelope: envelope,
      key: key,
      messageId: messageId,
      convId: convId,
      type: messageType,
    );
  } catch (error) {
    debugPrint(
      '[PinnedMessages] Failed to decrypt message_id=$messageId '
      'conv_id=$convId: $error',
    );
    return encryptedMessageDecryptFailedPlaceholder;
  }
}

Future<PinnedMessageData> _pinnedMessageFromJson(
  Ref ref,
  Map<String, dynamic> pin, {
  required String convId,
}) async {
  final messageId = pin['message_id'] as String;
  final messageType = pin['message_type'] as String? ?? 'text';
  final messageMetadata = _decodePinnedMessageMetadata(
    pin['message_metadata'] ?? pin['message_metatdata'],
  );
  final messageContent = await _resolvePinnedMessageContent(
    ref,
    pin,
    convId: convId,
    messageId: messageId,
    messageType: messageType,
  );

  return PinnedMessageData(
    messageId: messageId,
    convId: convId,
    pinnedBy: pin['pinned_by'] as String? ?? '',
    pinnedAt: pin['pinned_at'] != null
        ? DateTime.parse(pin['pinned_at'] as String)
        : DateTime.now(),
    messageContent: messageContent,
    messageMetadata: messageMetadata,
    messageType: pin['message_type'] as String?,
    senderId: pin['sender_id'] as String?,
    senderName: pin['sender_name'] as String?,
    pinnerName: pin['pinner_name'] as String?,
  );
}

final pinnedMessagesProvider =
    AsyncNotifierProvider.family<
      PinnedMessagesNotifier,
      List<PinnedMessageData>,
      String
    >(PinnedMessagesNotifier.new);

class PinnedMessagesNotifier
    extends FamilyAsyncNotifier<List<PinnedMessageData>, String> {
  @override
  Future<List<PinnedMessageData>> build(String arg) async {
    final convId = arg;
    final dao = ref.read(chatDaoProvider);

    // Load from local cache first
    final cached = await dao.getPinnedMessages(convId);
    final localPins = cached
        .map(
          (p) => PinnedMessageData(
            messageId: p.messageId,
            convId: p.convId,
            pinnedBy: p.pinnedBy,
            pinnedAt: p.pinnedAt,
          ),
        )
        .toList();

    // Fetch from API in background
    _refreshFromApi(convId);

    // Listen for pin_update WS events
    final wsManager = ref.read(webSocketManagerProvider);
    wsManager.on('pin_update', _onPinUpdate);
    ref.onDispose(() => wsManager.off('pin_update', _onPinUpdate));

    return localPins;
  }

  Future<void> _onPinUpdate(Map<String, dynamic> data) async {
    final convId = data['conv_id'] as String?;
    if (convId != arg) return;

    final pinsList = data['pinned_messages'] as List<dynamic>? ?? [];
    final pins = await Future.wait(
      pinsList.map(
        (p) => _pinnedMessageFromJson(
          ref,
          Map<String, dynamic>.from(p as Map),
          convId: convId!,
        ),
      ),
    );

    // Update local DAO (fire-and-forget with error logging)
    final dao = ref.read(chatDaoProvider);
    dao
        .deleteAllPinnedMessages(convId!)
        .then((_) async {
          for (final pin in pins) {
            await dao.insertPinnedMessage(
              LocalPinnedMessagesCompanion.insert(
                convId: pin.convId,
                messageId: pin.messageId,
                pinnedBy: pin.pinnedBy,
                pinnedAt: pin.pinnedAt,
              ),
            );
          }
        })
        .catchError((e) {
          debugPrint('[PinnedMessages] Failed to update local DAO: $e');
        });

    state = AsyncData(pins);
  }

  Future<void> _refreshFromApi(String convId) async {
    try {
      final repo = ref.read(chatRepositoryProvider);
      final dao = ref.read(chatDaoProvider);
      final data = await repo.getPinnedMessages(convId);

      final pins = await Future.wait(
        data.map(
          (p) => _pinnedMessageFromJson(
            ref,
            Map<String, dynamic>.from(p as Map),
            convId: convId,
          ),
        ),
      );

      // Update local cache
      await dao.deleteAllPinnedMessages(convId);
      for (final pin in pins) {
        await dao.insertPinnedMessage(
          LocalPinnedMessagesCompanion.insert(
            convId: pin.convId,
            messageId: pin.messageId,
            pinnedBy: pin.pinnedBy,
            pinnedAt: pin.pinnedAt,
          ),
        );
      }

      state = AsyncData(pins);
    } catch (e) {
      debugPrint('[PinnedMessages] Failed to refresh from API: $e');
    }
  }

  Future<void> pinMessage(String messageId) async {
    final repo = ref.read(chatRepositoryProvider);
    await repo.pinMessage(arg, messageId);
    await _refreshFromApi(arg);
  }

  Future<void> unpinMessage(String messageId) async {
    final repo = ref.read(chatRepositoryProvider);
    await repo.unpinMessage(arg, messageId);
    await _refreshFromApi(arg);
  }

  Future<void> unpinAllMessages() async {
    final repo = ref.read(chatRepositoryProvider);
    await repo.unpinAllMessages(arg);
    final dao = ref.read(chatDaoProvider);
    await dao.deleteAllPinnedMessages(arg);
    state = const AsyncData([]);
  }

  bool isPinned(String messageId) {
    final pins = state.valueOrNull ?? [];
    return pins.any((p) => p.messageId == messageId);
  }
}

String _bookmarkIdentityKey(BookmarkedMessageData bookmark) {
  return '${bookmark.userId}:${bookmark.convId}:${bookmark.messageId}';
}

String _localBookmarkCacheKey(LocalBookmarkedMessage bookmark) {
  return '${bookmark.convId}:${bookmark.messageId}';
}

String _bookmarkCacheKey(BookmarkedMessageData bookmark) {
  return '${bookmark.convId}:${bookmark.messageId}';
}

BookmarkedMessageData bookmarkedMessageFromJson(
  Map<String, dynamic> json,
  String? convId,
) {
  return BookmarkedMessageData.fromJson(json, fallbackConvId: convId);
}

@visibleForTesting
String? bookmarkedConversationDisplayName(LocalConversation? conversation) {
  if (conversation == null) return null;
  if (conversation.type == 'DIRECT') {
    return conversation.otherMemberName ?? conversation.name;
  }
  return conversation.name;
}

@visibleForTesting
String? bookmarkedConversationDisplayAvatar(LocalConversation? conversation) {
  if (conversation == null) return null;
  if (conversation.type == 'DIRECT') {
    return conversation.otherMemberAvatar ?? conversation.avatarUrl;
  }
  return conversation.avatarUrl;
}

BookmarkedMessageData _bookmarkedMessageFromLocal(
  LocalBookmarkedMessage bookmark, {
  LocalConversation? conversation,
}) {
  return BookmarkedMessageData(
    messageId: bookmark.messageId,
    convId: bookmark.convId,
    userId: bookmark.userId,
    markedAt: bookmark.markedAt,
    messageContent: bookmark.messageContent,
    messageType: bookmark.messageType,
    senderId: bookmark.senderId,
    senderName: bookmark.senderName,
    messageCreatedAt: bookmark.messageCreatedAt,
    conversationType: conversation?.type,
    conversationName: bookmarkedConversationDisplayName(conversation),
    conversationAvatarUrl: bookmarkedConversationDisplayAvatar(conversation),
  );
}

LocalBookmarkedMessagesCompanion buildBookmarkedMessageCompanion(
  BookmarkedMessageData bookmark,
) {
  return LocalBookmarkedMessagesCompanion.insert(
    convId: bookmark.convId,
    messageId: bookmark.messageId,
    userId: bookmark.userId,
    markedAt: bookmark.markedAt,
    messageContent: Value(bookmark.messageContent),
    messageType: Value(bookmark.messageType),
    senderId: Value(bookmark.senderId),
    senderName: Value(bookmark.senderName),
    messageCreatedAt: Value(bookmark.messageCreatedAt),
  );
}

@visibleForTesting
List<BookmarkedMessageData> mergeBookmarkedMessagePages({
  required Iterable<BookmarkedMessageData> current,
  required Iterable<BookmarkedMessageData> incoming,
}) {
  final merged = <BookmarkedMessageData>[];
  final seen = <String>{};

  for (final bookmark in [...current, ...incoming]) {
    if (seen.add(_bookmarkIdentityKey(bookmark))) {
      merged.add(bookmark);
    }
  }

  return merged;
}

int _compareBookmarkSortValues({
  required DateTime leftMarkedAt,
  required String leftMessageId,
  required DateTime rightMarkedAt,
  required String rightMessageId,
}) {
  final markedAtComparison = leftMarkedAt.compareTo(rightMarkedAt);
  if (markedAtComparison != 0) {
    return markedAtComparison;
  }
  return _compareBookmarkMessageIds(
    leftMessageId: leftMessageId,
    rightMessageId: rightMessageId,
  );
}

final _uuidSortKeyPattern = RegExp(r'^[0-9a-f]{32}$');

String? _bookmarkUuidSortKey(String messageId) {
  final normalized = messageId.replaceAll('-', '').toLowerCase();
  if (!_uuidSortKeyPattern.hasMatch(normalized)) {
    return null;
  }
  return normalized;
}

int _compareBookmarkMessageIds({
  required String leftMessageId,
  required String rightMessageId,
}) {
  // Postgres orders UUIDs by value, so compare canonical hex to keep the
  // cache-prune boundary aligned with backend pagination semantics.
  final leftUuidSortKey = _bookmarkUuidSortKey(leftMessageId);
  final rightUuidSortKey = _bookmarkUuidSortKey(rightMessageId);
  if (leftUuidSortKey != null && rightUuidSortKey != null) {
    return leftUuidSortKey.compareTo(rightUuidSortKey);
  }

  return leftMessageId.compareTo(rightMessageId);
}

Future<void> pruneGlobalBookmarkFirstPageCache({
  required ChatDao dao,
  required String userId,
  required GlobalBookmarkedMessagesPage page,
}) async {
  if (page.items.isEmpty && !page.hasMore) {
    await dao.deleteAllBookmarkedMessagesForUser(userId);
    return;
  }
  if (page.items.isEmpty) return;

  final cached = await dao.getAllBookmarkedMessagesForUser(userId);
  if (cached.isEmpty) return;

  final keepKeys = page.items.map(_bookmarkCacheKey).toSet();
  final boundary = page.items.last;

  for (final bookmark in cached) {
    if (keepKeys.contains(_localBookmarkCacheKey(bookmark))) {
      continue;
    }

    final isWithinFirstPageWindow =
        !page.hasMore ||
        _compareBookmarkSortValues(
              leftMarkedAt: bookmark.markedAt,
              leftMessageId: bookmark.messageId,
              rightMarkedAt: boundary.markedAt,
              rightMessageId: boundary.messageId,
            ) >=
            0;
    if (!isWithinFirstPageWindow) {
      continue;
    }

    await dao.deleteBookmarkedMessage(
      userId,
      bookmark.convId,
      bookmark.messageId,
    );
  }
}

void invalidateGlobalBookmarkedMessages(Ref ref) {
  for (final filter in GlobalBookmarkFilter.values) {
    ref.invalidate(globalBookmarkedMessagesProvider(filter));
  }
}

class GlobalBookmarkedMessagesState {
  const GlobalBookmarkedMessagesState({
    required this.items,
    this.nextCursor,
    this.hasMore = false,
    this.isLoadingMore = false,
  });

  final List<BookmarkedMessageData> items;
  final String? nextCursor;
  final bool hasMore;
  final bool isLoadingMore;

  static const _nextCursorUnset = Object();

  GlobalBookmarkedMessagesState copyWith({
    List<BookmarkedMessageData>? items,
    Object? nextCursor = _nextCursorUnset,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return GlobalBookmarkedMessagesState(
      items: items ?? this.items,
      nextCursor: nextCursor == _nextCursorUnset
          ? this.nextCursor
          : nextCursor as String?,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

final bookmarkedMessagesProvider =
    AsyncNotifierProvider.family<
      BookmarkedMessagesNotifier,
      List<BookmarkedMessageData>,
      String
    >(BookmarkedMessagesNotifier.new);

class BookmarkedMessagesNotifier
    extends FamilyAsyncNotifier<List<BookmarkedMessageData>, String> {
  @override
  Future<List<BookmarkedMessageData>> build(String arg) async {
    final userId = await currentUserIdFromAuth(ref);
    if (userId.isEmpty) {
      return const [];
    }

    final dao = ref.read(chatDaoProvider);
    final cached = await dao.getBookmarkedMessages(userId, arg);
    final localBookmarks = cached.map(_bookmarkedMessageFromLocal).toList();

    unawaited(refresh());
    return localBookmarks;
  }

  Future<void> refresh() async {
    try {
      final userId = await currentUserIdFromAuth(ref);
      if (userId.isEmpty) {
        state = const AsyncData([]);
        return;
      }

      final repo = ref.read(chatRepositoryProvider);
      final dao = ref.read(chatDaoProvider);
      final data = await repo.getBookmarkedMessages(arg);
      final bookmarks = data
          .map(
            (item) =>
                bookmarkedMessageFromJson(item as Map<String, dynamic>, arg),
          )
          .toList();

      await dao.deleteAllBookmarkedMessages(userId, arg);
      for (final bookmark in bookmarks) {
        await dao.insertBookmarkedMessage(
          buildBookmarkedMessageCompanion(bookmark),
        );
      }

      state = AsyncData(bookmarks);
    } catch (e) {
      debugPrint('[Bookmarks] Failed to refresh from API: $e');
    }
  }

  Future<void> bookmarkMessage(String messageId) async {
    final repo = ref.read(chatRepositoryProvider);
    await repo.bookmarkMessage(arg, messageId);
    await refresh();
    invalidateGlobalBookmarkedMessages(ref);
  }

  Future<void> unbookmarkMessage(String messageId) async {
    final repo = ref.read(chatRepositoryProvider);
    await repo.unbookmarkMessage(arg, messageId);
    await refresh();
    invalidateGlobalBookmarkedMessages(ref);
  }

  bool isBookmarked(String messageId) {
    final bookmarks = state.valueOrNull ?? [];
    return bookmarks.any((bookmark) => bookmark.messageId == messageId);
  }
}

final globalBookmarkedMessagesProvider =
    AsyncNotifierProvider.family<
      GlobalBookmarkedMessagesNotifier,
      GlobalBookmarkedMessagesState,
      GlobalBookmarkFilter
    >(GlobalBookmarkedMessagesNotifier.new);

class GlobalBookmarkedMessagesNotifier
    extends
        FamilyAsyncNotifier<
          GlobalBookmarkedMessagesState,
          GlobalBookmarkFilter
        > {
  @override
  Future<GlobalBookmarkedMessagesState> build(GlobalBookmarkFilter arg) async {
    final userId = await currentUserIdFromAuth(ref);
    if (userId.isEmpty) {
      return const GlobalBookmarkedMessagesState(items: []);
    }

    final dao = ref.read(chatDaoProvider);
    final cached = await dao.getGlobalBookmarkedMessages(
      userId,
      conversationType: arg.localConversationType,
      limit: _globalBookmarkPageSize,
    );
    final localItems = cached
        .map(
          (row) =>
              bookmarkedMessageFromJson(Map<String, dynamic>.from(row), null),
        )
        .toList(growable: false);

    unawaited(refresh());
    return GlobalBookmarkedMessagesState(items: localItems);
  }

  Future<void> refresh() async {
    try {
      final userId = await currentUserIdFromAuth(ref);
      if (userId.isEmpty) {
        state = const AsyncData(GlobalBookmarkedMessagesState(items: []));
        return;
      }

      final repo = ref.read(chatRepositoryProvider);
      final dao = ref.read(chatDaoProvider);
      final page = await repo.getGlobalBookmarkedMessages(
        filter: arg,
        limit: _globalBookmarkPageSize,
      );

      await pruneGlobalBookmarkFirstPageCache(
        dao: dao,
        userId: userId,
        page: page,
      );

      for (final bookmark in page.items) {
        await dao.insertBookmarkedMessage(
          buildBookmarkedMessageCompanion(bookmark),
        );
      }

      state = AsyncData(
        GlobalBookmarkedMessagesState(
          items: page.items,
          nextCursor: page.nextCursor,
          hasMore: page.hasMore,
        ),
      );
    } catch (e) {
      debugPrint('[GlobalBookmarks] Failed to refresh from API: $e');
    }
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null ||
        current.isLoadingMore ||
        !current.hasMore ||
        current.nextCursor == null) {
      return;
    }

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final userId = await currentUserIdFromAuth(ref);
      if (userId.isEmpty) {
        state = const AsyncData(GlobalBookmarkedMessagesState(items: []));
        return;
      }

      final repo = ref.read(chatRepositoryProvider);
      final dao = ref.read(chatDaoProvider);
      final page = await repo.getGlobalBookmarkedMessages(
        filter: arg,
        cursor: current.nextCursor,
        limit: _globalBookmarkPageSize,
      );

      for (final bookmark in page.items) {
        await dao.insertBookmarkedMessage(
          buildBookmarkedMessageCompanion(bookmark),
        );
      }

      state = AsyncData(
        current.copyWith(
          items: mergeBookmarkedMessagePages(
            current: current.items,
            incoming: page.items,
          ),
          nextCursor: page.nextCursor,
          hasMore: page.hasMore,
          isLoadingMore: false,
        ),
      );
    } catch (e) {
      debugPrint('[GlobalBookmarks] Failed to load more: $e');
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }
}

// --- Chat Messages ---

final chatMessagesProvider =
    AsyncNotifierProvider.family<ChatNotifier, List<LocalMessage>, String>(
      ChatNotifier.new,
    );

class ChatNotifier extends FamilyAsyncNotifier<List<LocalMessage>, String> {
  bool _isSynchronizing = false;
  bool _needsAnotherSynchronizationPass = false;

  @override
  Future<List<LocalMessage>> build(String convId) async {
    final dao = ref.read(chatDaoProvider);

    // Load from local cache
    List<LocalMessage> cached = [];
    try {
      cached = await dao.getMessages(convId);
      if (cached.isNotEmpty) {
        cached = await _resolveLocalMessagesForUi(ref, cached);
      }
    } catch (e) {
      debugPrint('[Chat] Failed to load cached messages: $e');
    }

    // Listen for WS events
    final wsManager = ref.read(webSocketManagerProvider);
    wsManager.on('new_message', _onNewMessage);
    wsManager.on('message_updated', _onMessageUpdated);
    wsManager.on('message_recalled', _onMessageRecalled);
    wsManager.on('sync_response', _onSyncResponse);
    wsManager.on('message_ack', _onMessageAck);
    wsManager.on('message_status', _onMessageStatus);
    wsManager.on('message_read', _onMessageRead);
    wsManager.on('send_error', _onSendError);
    wsManager.on('reaction_update', _onReactionUpdate);
    wsManager.on('error', _onWsError);
    ref.onDispose(() {
      wsManager.off('new_message', _onNewMessage);
      wsManager.off('message_updated', _onMessageUpdated);
      wsManager.off('message_recalled', _onMessageRecalled);
      wsManager.off('sync_response', _onSyncResponse);
      wsManager.off('message_ack', _onMessageAck);
      wsManager.off('message_status', _onMessageStatus);
      wsManager.off('message_read', _onMessageRead);
      wsManager.off('send_error', _onSendError);
      wsManager.off('reaction_update', _onReactionUpdate);
      wsManager.off('error', _onWsError);
    });

    await _markConversationRead(cached);

    return cached;
  }

  void recoverRealtimeOnRoomEntry() {
    ref.read(webSocketManagerProvider).ensureConnected();
    unawaited(synchronizeOnOpen());
  }

  Future<void> synchronizeAfterRealtimeReconnect() async {
    await synchronizeOnOpen();
  }

  Future<void> synchronizeOnOpen() async {
    if (_isSynchronizing) {
      _needsAnotherSynchronizationPass = true;
      return;
    }
    do {
      _needsAnotherSynchronizationPass = false;
      _isSynchronizing = true;
      try {
        await _refreshFromApi(reconcileReadState: true);
      } finally {
        _isSynchronizing = false;
      }
    } while (_needsAnotherSynchronizationPass);
  }

  Future<void> _refreshConversationList() async {
    try {
      await ref.read(chatListProvider.notifier).refresh();
    } catch (e) {
      debugPrint('[Chat] Failed to refresh conversation list: $e');
    }
  }

  Future<void> _markConversationRead(List<LocalMessage> messages) async {
    final activeConversationId = ref.read(activeChatConversationIdProvider);
    if (!isConversationActivelyViewed(
      conversationId: arg,
      activeConversationId: activeConversationId,
    )) {
      return;
    }

    final dao = ref.read(chatDaoProvider);
    final wsManager = ref.read(webSocketManagerProvider);
    final viewedAt = messages.isNotEmpty
        ? messages.first.createdAt
        : DateTime.now();

    await dao.markConversationViewed(arg, viewedAt: viewedAt);
    await ref.read(badgeSyncServiceProvider).syncFromLocalUnreadTotal();

    if (messages.isNotEmpty) {
      wsManager.sendMarkRead(arg, messages.first.id);
    }

    ref.invalidate(chatListProvider);
    unawaited(_refreshConversationList());
  }

  Future<void> _refreshFromApi({bool reconcileReadState = false}) async {
    try {
      final repo = ref.read(chatRepositoryProvider);
      final dao = ref.read(chatDaoProvider);

      final result = await repo.getMessages(arg);
      _updateHistoryPagination(result);
      final messages = result['messages'] as List? ?? [];

      for (final m in messages) {
        final msg = m as Map<String, dynamic>;
        try {
          await dao.insertMessage(
            buildIncomingMessageCompanion(msg, defaultStatus: 'sent'),
          );
          // Store reactions if present
          final reactions = msg['reactions'] as List?;
          if (reactions != null && reactions.isNotEmpty) {
            await _storeReactionsForMessage(msg['id'] as String, reactions);
          }
        } catch (e) {
          debugPrint('[Chat] Failed to cache message: $e');
        }
      }

      // Reload from DB (or use API data directly if DB is broken)
      List<LocalMessage> updated;
      try {
        updated = await dao.getMessages(arg);
      } catch (e) {
        debugPrint('[Chat] DB read failed, using API data directly');
        // Fallback: convert API data to LocalMessage-like objects
        // This won't work perfectly but at least shows messages
        updated = [];
      }

      if (updated.isNotEmpty) {
        state = AsyncData(await _resolveLocalMessagesForUi(ref, updated));
      } else if (messages.isNotEmpty) {
        // DB is broken but we have API data — build in-memory list
        final inMemory = messages.map((m) {
          final msg = m as Map<String, dynamic>;
          final companion = buildIncomingMessageCompanion(msg);
          return LocalMessage(
            id: msg['id'] as String,
            convId: msg['conv_id'] as String,
            senderId: msg['sender_id'] as String,
            createdAt: DateTime.parse(msg['created_at'] as String),
            type: msg['type'] as String? ?? 'text',
            content: companion.content.value,
            replyToId: msg['reply_to_id'] as String?,
            metadata: companion.metadata.value,
            status: 'sent',
            retryCount: 0,
            editedAt: _parseApiDateTime(msg['edited_at']),
            deletedAt: _parseApiDateTime(msg['deleted_at']),
            forwardedFromId: msg['forwarded_from_id'] as String?,
            forwardedFromSender: msg['forwarded_from_sender'] as String?,
          );
        }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        state = AsyncData(await _resolveLocalMessagesForUi(ref, inMemory));
        updated = inMemory;
      } else {
        updated = const [];
      }

      if (reconcileReadState) {
        await _markConversationRead(updated);
      }
    } catch (e) {
      debugPrint('[Chat] _refreshFromApi error: $e');
    }
  }

  Future<void> _upsertRemoteMessage(Map<String, dynamic> data) async {
    final dao = ref.read(chatDaoProvider);
    await dao.insertMessage(
      buildIncomingMessageCompanion(data, defaultStatus: 'sent'),
    );
  }

  Future<void> _applyRemoteMessageUpdate(Map<String, dynamic> data) async {
    final dao = ref.read(chatDaoProvider);
    final existing = await dao.getMessage(data['id'] as String);
    if (existing == null) {
      await _upsertRemoteMessage(data);
      final convId = data['conv_id'] as String?;
      final messageId = data['id'] as String?;
      if (convId != null && messageId != null) {
        await syncConversationPreviewFromLatestMessage(
          dao,
          convId: convId,
          changedMessageId: messageId,
        );
      }
      return;
    }

    Map<String, dynamic>? existingMetadata;
    if (existing.metadata != null) {
      try {
        existingMetadata =
            jsonDecode(existing.metadata!) as Map<String, dynamic>;
      } catch (_) {}
    }

    final metadataStr = _buildMessageMetadata(
      data,
      existingMetadata: existingMetadata,
    );
    final metaMap = _decodeMessageMetadata(metadataStr);
    final hasEncryptedEnvelope =
        data['encrypted_content'] != null ||
        (metaMap != null &&
            metaMap.containsKey(EncryptedMessageAdapter.envelopeMetadataKey));

    await dao.updateMessageFromRemote(
      data['id'] as String,
      content: hasEncryptedEnvelope ? null : data['content'] as String?,
      metadata: metadataStr,
      editedAt: _parseApiDateTime(data['edited_at']),
      deletedAt: _parseApiDateTime(data['deleted_at']),
    );

    final convId = data['conv_id'] as String?;
    final messageId = data['id'] as String?;
    if (convId != null && messageId != null) {
      await syncConversationPreviewFromLatestMessage(
        dao,
        convId: convId,
        changedMessageId: messageId,
      );
    }
  }

  Future<void> _reloadMessagesFromDao() async {
    final dao = ref.read(chatDaoProvider);
    final messages = await dao.getMessages(arg);
    state = AsyncData(await _resolveLocalMessagesForUi(ref, messages));
    ref.invalidate(chatListProvider);
    unawaited(_refreshConversationList());
  }

  Future<void> _setStateFromDao({int limit = 50}) async {
    final dao = ref.read(chatDaoProvider);
    final messages = await dao.getMessages(arg, limit: limit);
    state = AsyncData(await _resolveLocalMessagesForUi(ref, messages));
  }

  ConversationSeenByPlacementRequest? _buildSeenPlacementRequestFromState() {
    final currentMessages = state.valueOrNull;
    if (currentMessages == null) return null;
    final currentUserId =
        ref.read(authNotifierProvider).valueOrNull?.user?.id ?? '';
    return ConversationSeenByPlacementRequest(
      convId: arg,
      currentUserId: currentUserId,
      messageIdsNewestFirst: currentMessages
          .where(
            (message) => message.deletedAt == null && message.type != 'system',
          )
          .map((message) => message.id)
          .toList(),
    );
  }

  void _invalidateSeenByState() {
    final request = _buildSeenPlacementRequestFromState();
    if (request == null) return;

    for (final messageId in request.messageIdsNewestFirst) {
      ref.invalidate(
        messageSeenByProvider((convId: request.convId, messageId: messageId)),
      );
    }
    ref.invalidate(conversationSeenByPlacementProvider(request));
  }

  void _updateHistoryPagination(Map<String, dynamic> result) {
    final nextCursor = result['nextCursor'] as String?;
    final hasMore = result['hasMore'] as bool? ?? false;
    ref.read(chatHistoryPaginationProvider(arg).notifier).state =
        ChatHistoryPaginationState(nextCursor: nextCursor, hasMore: hasMore);
  }

  void _onNewMessage(Map<String, dynamic> data) async {
    try {
      if (data['conv_id'] != arg) return;
      final dao = ref.read(chatDaoProvider);
      final wsManager = ref.read(webSocketManagerProvider);

      try {
        await _upsertRemoteMessage(data);
      } catch (e) {
        debugPrint('[Chat] Failed to persist incoming message: $e');
      }

      // Send delivery confirmation
      wsManager.sendMarkDelivered(
        data['conv_id'] as String,
        data['id'] as String,
        data['sender_id'] as String,
      );

      // Update conversation preview
      try {
        await dao.updateConversation(
          arg,
          LocalConversationsCompanion(
            lastMessageAt: Value(DateTime.parse(data['created_at'] as String)),
            lastMessageContent: Value(
              buildConversationPreviewText(
                type: data['type'] as String? ?? 'text',
                content: data['content'] as String?,
                metadata: _decodeMessageMetadata(_buildMessageMetadata(data)),
                deletedAt: _parseApiDateTime(data['deleted_at']),
              ),
            ),
            lastMessageSenderId: Value(data['sender_id'] as String?),
          ),
        );
      } catch (e) {
        debugPrint('[Chat] Failed to update conversation preview: $e');
      }

      // Update state: try DB first, fallback to appending in-memory
      try {
        await _setStateFromDao();
      } catch (e) {
        final current = state.valueOrNull ?? [];
        final companion = buildIncomingMessageCompanion(data);
        var newMsg = LocalMessage(
          id: data['id'] as String,
          convId: data['conv_id'] as String,
          senderId: data['sender_id'] as String,
          createdAt: DateTime.parse(data['created_at'] as String),
          type: data['type'] as String? ?? 'text',
          content: companion.content.value,
          replyToId: data['reply_to_id'] as String?,
          metadata: companion.metadata.value,
          status: 'delivered',
          retryCount: 0,
          editedAt: _parseApiDateTime(data['edited_at']),
          deletedAt: _parseApiDateTime(data['deleted_at']),
          forwardedFromId: data['forwarded_from_id'] as String?,
          forwardedFromSender: data['forwarded_from_sender'] as String?,
        );
        newMsg = await _resolveLocalMessageForUi(ref, newMsg);
        state = AsyncData([newMsg, ...current]);
      }
      await _markConversationRead(state.valueOrNull ?? []);
      ref.invalidate(chatListProvider);
    } catch (e) {
      debugPrint('[Chat] _onNewMessage error: $e');
    }
  }

  void _onMessageUpdated(Map<String, dynamic> data) async {
    try {
      if (data['conv_id'] != arg) return;
      await _applyRemoteMessageUpdate(data);
      await _reloadMessagesFromDao();
    } catch (e) {
      debugPrint('[Chat] _onMessageUpdated error: $e');
    }
  }

  void _onMessageRecalled(Map<String, dynamic> data) async {
    try {
      if (data['conv_id'] != arg) return;
      await _applyRemoteMessageUpdate(data);
      await _reloadMessagesFromDao();
    } catch (e) {
      debugPrint('[Chat] _onMessageRecalled error: $e');
    }
  }

  void _onSyncResponse(Map<String, dynamic> data) async {
    try {
      final rawMessages = data['messages'] as List? ?? [];
      var touchedCurrentConversation = false;
      for (final raw in rawMessages) {
        final message = raw as Map<String, dynamic>;
        if (message['conv_id'] == arg) {
          touchedCurrentConversation = true;
        }
        await _applyRemoteMessageUpdate(message);
      }
      if (touchedCurrentConversation) {
        await _reloadMessagesFromDao();
      }
    } catch (e) {
      debugPrint('[Chat] _onSyncResponse error: $e');
    }
  }

  void _onMessageAck(Map<String, dynamic> data) async {
    try {
      final dao = ref.read(chatDaoProvider);
      await dao.updateMessageStatus(data['id'] as String, 'sent');
      await _setStateFromDao();
    } catch (e) {
      debugPrint('[Chat] _onMessageAck error: $e');
    }
  }

  void _onMessageStatus(Map<String, dynamic> data) async {
    try {
      final dao = ref.read(chatDaoProvider);
      await dao.updateMessageStatus(
        data['message_id'] as String,
        data['status'] as String,
      );
      await _setStateFromDao();
    } catch (e) {
      debugPrint('[Chat] _onMessageStatus error: $e');
    }
  }

  void _onMessageRead(Map<String, dynamic> data) {
    try {
      final convId = data['conv_id'] as String?;
      if (convId != arg) return;
      _invalidateSeenByState();
    } catch (e) {
      debugPrint('[Chat] _onMessageRead error: $e');
    }
  }

  void _onSendError(Map<String, dynamic> data) async {
    try {
      final messageId = data['message_id'] as String?;
      if (messageId == null) return;
      final reason = data['reason'] as String? ?? 'unknown';
      debugPrint('[WS] Send error for $messageId: $reason');
      final dao = ref.read(chatDaoProvider);
      await dao.incrementRetryCount(messageId);
    } catch (e) {
      debugPrint('[Chat] _onSendError error: $e');
    }
  }

  void _onReactionUpdate(Map<String, dynamic> data) async {
    try {
      final convId = data['conv_id'] as String?;
      if (convId != arg) return;
      final messageId = data['message_id'] as String?;
      if (messageId == null) return;

      final reactions = data['reactions'] as List? ?? [];
      await _storeReactionsForMessage(messageId, reactions);
    } catch (e) {
      debugPrint('[Chat] _onReactionUpdate error: $e');
    }
  }

  Future<void> toggleReaction(String messageId, String emoji) async {
    final dao = ref.read(chatDaoProvider);
    final wsManager = ref.read(webSocketManagerProvider);
    final authState = ref.read(authNotifierProvider);
    final userId = authState.valueOrNull?.user?.id ?? '';
    final userName = authState.valueOrNull?.user?.name ?? '';

    // Optimistic update
    final existing = await dao.getReactionsForMessage(messageId);
    final hasReaction = existing.any(
      (r) => r.userId == userId && r.emoji == emoji,
    );

    if (hasReaction) {
      await dao.deleteReaction(messageId, userId, emoji);
    } else {
      // Check local limit
      final myCount = existing.where((r) => r.userId == userId).length;
      if (myCount >= 3) return; // silently ignore
      await dao.upsertReaction(messageId, userId, emoji, userName);
    }

    // Send to server
    wsManager.sendToggleReaction(arg, messageId, emoji);
  }

  Future<void> _storeReactionsForMessage(
    String messageId,
    List<dynamic> reactions,
  ) async {
    final dao = ref.read(chatDaoProvider);
    final companions = <LocalMessageReactionsCompanion>[];
    for (final group in reactions) {
      final g = group as Map<String, dynamic>;
      final emoji = g['emoji'] as String;
      final users = g['users'] as List? ?? [];
      for (final u in users) {
        final user = u as Map<String, dynamic>;
        companions.add(
          LocalMessageReactionsCompanion.insert(
            messageId: messageId,
            userId: user['id'] as String,
            emoji: emoji,
            userName: user['name'] as String? ?? '',
            createdAt: DateTime.now(),
          ),
        );
      }
    }
    await dao.replaceReactionsForMessage(messageId, companions);
  }

  Future<void> editMessage(String messageId, String content) async {
    final repo = ref.read(chatRepositoryProvider);
    final adapter = ref.read(encryptedMessageAdapterProvider);
    final keyRepository = ref.read(conversationKeyRepositoryProvider);
    final dao = ref.read(chatDaoProvider);

    // Check whether the original message is encrypted
    final existing = await dao.getMessage(messageId);
    final isEncrypted =
        existing != null && adapter.isEncryptedMetadata(existing.metadata);

    try {
      Map<String, dynamic>? payload;

      if (isEncrypted) {
        // --- Encrypted message: must re-encrypt new content ---
        final activeKey = await keyRepository.resolveActiveKey(arg);
        final envelope = await adapter.encryptText(
          plaintext: content,
          key: activeKey,
          messageId: messageId,
          convId: arg,
        );
        final blindIndex = await adapter.buildBlindIndexPayload(
          plaintext: content,
          key: activeKey,
        );
        payload = await repo.editMessage(
          arg,
          messageId,
          content: null,
          metadata: {'encrypted_content': envelope.toJson()},
          blindIndex: blindIndex,
        );
      } else {
        // --- Plaintext message: send content only, no encrypted_content ---
        if (content.trim().isEmpty) {
          throw const EditMessageException(
            code: 'INVALID_CONTENT',
            message: 'Nội dung tin nhắn không được để trống',
          );
        }
        payload = await repo.editMessage(arg, messageId, content: content);
      }

      await _applyRemoteMessageUpdate(payload);
      await _reloadMessagesFromDao();
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final responseData = e.response?.data;
      String? errorCode;
      if (responseData is Map<String, dynamic>) {
        errorCode =
            responseData['code'] as String? ?? responseData['error'] as String?;
      }

      if (statusCode == 400 && errorCode == 'INVALID_MESSAGE_STATE') {
        throw const EditMessageException(
          code: 'INVALID_MESSAGE_STATE',
          message: 'Tin nhắn mã hóa cần có dữ liệu mã hóa mới khi chỉnh sửa',
        );
      } else if (statusCode == 400 && errorCode == 'INVALID_CONTENT') {
        throw const EditMessageException(
          code: 'INVALID_CONTENT',
          message: 'Nội dung tin nhắn không hợp lệ',
        );
      } else if (statusCode == 403) {
        throw const EditMessageException(
          code: 'FORBIDDEN',
          message: 'Bạn không có quyền sửa tin nhắn này',
        );
      }
      rethrow;
    }
  }

  Future<void> recallMessage(String messageId) async {
    final repo = ref.read(chatRepositoryProvider);
    final payload = await repo.recallMessage(arg, messageId);
    await _applyRemoteMessageUpdate(payload);
    await _reloadMessagesFromDao();
  }

  void _onWsError(Map<String, dynamic> data) async {
    try {
      final code = data['code'] as String?;
      if (code == 'REACTION_LIMIT') {
        // Revert optimistic reaction — re-sync from server via reaction_update
        // The server won't send a reaction_update for failed toggles,
        // so we need to revert locally
        final messageId = data['message_id'] as String?;
        if (messageId == null) return;
        final dao = ref.read(chatDaoProvider);
        final authState = ref.read(authNotifierProvider);
        final userId = authState.valueOrNull?.user?.id ?? '';
        final emoji = data['emoji'] as String?;
        if (emoji != null) {
          await dao.deleteReaction(messageId, userId, emoji);
        }
      }
    } catch (e) {
      debugPrint('[Chat] _onWsError error: $e');
    }
  }

  // --- Optimistic send ---

  Future<void> sendMessage(
    String content, {
    LinkPreview? linkPreview,
    List<Map<String, dynamic>>? mentions,
    String? replyToId,
    LocalMessage? replyToMessage,
  }) async {
    final dao = ref.read(chatDaoProvider);
    final wsManager = ref.read(webSocketManagerProvider);
    final adapter = ref.read(encryptedMessageAdapterProvider);
    final keyRepository = ref.read(conversationKeyRepositoryProvider);
    final authState = ref.read(authNotifierProvider);
    final userId = authState.valueOrNull?.user?.id ?? '';

    final id = _uuid.v4();
    final now = DateTime.now();
    EncryptedMessageEnvelope? envelope;
    Map<String, dynamic>? blindIndex;
    var shouldPersistPlaintext = true;

    try {
      final activeKey = await keyRepository.resolveActiveKey(arg);
      envelope = await adapter.encryptText(
        plaintext: content,
        key: activeKey,
        messageId: id,
        convId: arg,
      );
      blindIndex = await adapter.buildBlindIndexPayload(
        plaintext: content,
        key: activeKey,
      );
      shouldPersistPlaintext = false;
    } catch (error) {
      if (!shouldFallbackToLegacyPlaintext(error)) {
        debugPrint(
          '[Chat][Encrypt] Failed for message_id=$id conv_id=$arg: $error',
        );
        rethrow;
      }
      debugPrint(
        '[Chat] Encryption key endpoint unavailable for conversation $arg, '
        'falling back to legacy plaintext send.',
      );
    }

    // Build metadata with link preview and/or mentions and/or reply snapshot
    Map<String, dynamic>? metadataMap;
    if (linkPreview != null ||
        (mentions != null && mentions.isNotEmpty) ||
        replyToMessage != null) {
      metadataMap = {};
      if (linkPreview != null) {
        metadataMap['linkPreview'] = linkPreview.toJson();
      }
      if (mentions != null && mentions.isNotEmpty) {
        metadataMap['mentions'] = mentions;
      }
      if (replyToMessage != null) {
        metadataMap['reply_to'] = _safeReplySnapshot(replyToMessage);
      }
    }
    final metadataJson = adapter.buildMetadataJson(
      existingMetadata: metadataMap,
      envelope: envelope,
      blindIndex: blindIndex,
    );

    // Insert locally with pending status
    try {
      await dao.insertMessage(
        LocalMessagesCompanion.insert(
          id: id,
          convId: arg,
          senderId: userId,
          createdAt: now,
          content: Value(shouldPersistPlaintext ? content : null),
          replyToId: Value(replyToId),
          metadata: Value(metadataJson),
          status: const Value('pending'),
        ),
      );
    } catch (e) {
      debugPrint('[Chat] Failed to persist outgoing message: $id, error: $e');
    }

    // Update conversation preview
    try {
      final previewContent = envelope != null
          ? EncryptedMessageAdapter.getPreviewSnippet(content)
          : content;
      await dao.updateConversation(
        arg,
        LocalConversationsCompanion(
          lastMessageAt: Value(now),
          lastMessageContent: Value(previewContent),
          lastMessageSenderId: Value(userId),
        ),
      );
    } catch (e) {
      debugPrint('[Chat] Failed to update conversation preview: $e');
    }

    // Update state: try DB, fallback to in-memory append
    try {
      await _setStateFromDao();
    } catch (e) {
      final current = state.valueOrNull ?? [];
      var newMsg = LocalMessage(
        id: id,
        convId: arg,
        senderId: userId,
        createdAt: now,
        type: 'text',
        content: shouldPersistPlaintext ? content : null,
        replyToId: replyToId,
        metadata: metadataJson,
        status: 'pending',
        retryCount: 0,
        deletedAt: null,
      );
      newMsg = await _resolveLocalMessageForUi(ref, newMsg);
      state = AsyncData([newMsg, ...current]);
    }
    ref.invalidate(chatListProvider);

    // Send via WebSocket
    final wsPayload = <String, dynamic>{
      'id': id,
      'conv_id': arg,
      'type': 'text',
      'content': envelope != null ? null : content,
      if (envelope != null) 'encrypted_content': envelope.toJson(),
      ...?blindIndex == null
          ? null
          : {EncryptedMessageAdapter.blindIndexMetadataKey: blindIndex},
    };
    if (replyToId != null) wsPayload['reply_to_id'] = replyToId;
    if (metadataMap != null) wsPayload['metadata'] = metadataMap;
    final dispatched = wsManager.sendMessage(wsPayload, id: id);
    if (!dispatched) {
      debugPrint('[Chat] Text send queued for retry: $id');
      wsManager.ensureConnected();
      try {
        await dao.incrementRetryCount(id);
      } catch (e) {
        debugPrint('[Chat] Failed to increment retry count for $id: $e');
      }
    }
  }

  Future<void> sendImageMessage(
    List<XFile> images,
    String? caption, {
    String? replyToId,
    LocalMessage? replyToMessage,
  }) async {
    final dao = ref.read(chatDaoProvider);
    final wsManager = ref.read(webSocketManagerProvider);
    final repo = ref.read(chatRepositoryProvider);
    final authState = ref.read(authNotifierProvider);
    final userId = authState.valueOrNull?.user?.id ?? '';

    final id = _uuid.v4();
    final now = DateTime.now();
    final msgType = images.length == 1 ? 'image' : 'album';

    // Build optimistic metadata with local paths
    final localPaths = images.map((img) => img.path).toList();
    final optimisticMetaMap = msgType == 'album'
        ? {
            'images': localPaths.map((p) => {'url': p}).toList(),
            'caption': caption,
          }
        : {'url': localPaths.first, 'caption': caption};
    if (replyToMessage != null) {
      optimisticMetaMap['reply_to'] = {
        'id': replyToMessage.id,
        'sender_id': replyToMessage.senderId,
        'sender_name': null,
        'content': replyToMessage.content,
        'type': replyToMessage.type,
      };
    }
    final optimisticMeta = jsonEncode(optimisticMetaMap);

    // Insert optimistic message
    try {
      await dao.insertMessage(
        LocalMessagesCompanion.insert(
          id: id,
          convId: arg,
          senderId: userId,
          createdAt: now,
          type: Value(msgType),
          content: Value(caption),
          replyToId: Value(replyToId),
          metadata: Value(optimisticMeta),
          status: const Value('pending'),
        ),
      );
      await _setStateFromDao();
    } catch (e) {
      debugPrint('[Chat] Failed to insert optimistic image message: $e');
    }
    ref.invalidate(chatListProvider);

    // Check if online
    final isOnline = wsManager.state == WsConnectionState.connected;

    if (!isOnline) {
      // Offline: cache files and queue upload
      try {
        final dao2 = ref.read(chatDaoProvider);
        await dao2.insertPendingUpload(
          PendingUploadsCompanion.insert(
            id: id,
            convId: arg,
            localPaths: jsonEncode(localPaths),
            caption: Value(caption),
            createdAt: now,
          ),
        );
      } catch (e) {
        debugPrint('[Chat] Failed to queue pending upload: $e');
      }
      return;
    }

    // Upload images
    try {
      final uploaded = await repo.uploadImages(images);

      // Build final metadata with server URLs
      final Map<String, dynamic> finalMeta;
      if (msgType == 'album') {
        finalMeta = {
          'images': uploaded
              .map(
                (u) => <String, dynamic>{
                  'url': u['url'],
                  'originalName': u['originalName'],
                  'size': u['size'],
                  'mimeType': u['mimeType'],
                  ...?(caption != null ? {'caption': caption} : null),
                },
              )
              .toList(),
        };
      } else {
        finalMeta = {
          'url': uploaded.first['url'],
          'originalName': uploaded.first['originalName'],
          'size': uploaded.first['size'],
          'mimeType': uploaded.first['mimeType'],
          ...?(caption != null ? {'caption': caption} : null),
        };
      }

      // Update local message with server URLs
      await dao.updateMessageMetadata(id, jsonEncode(finalMeta));

      // Send via WebSocket
      wsManager.sendMessage({
        'id': id,
        'conv_id': arg,
        'type': msgType,
        'content': caption,
        'metadata': finalMeta,
        ...?(replyToId != null ? {'reply_to_id': replyToId} : null),
      }, id: id);

      await _setStateFromDao();
    } catch (e) {
      debugPrint('[Chat] Image upload failed: $e');
      await dao.updateMessageStatus(id, 'failed');
      await _setStateFromDao();
    }
  }

  Future<void> sendVoiceMessage(
    String filePath,
    double duration,
    List<double> waveform,
  ) async {
    final dao = ref.read(chatDaoProvider);
    final wsManager = ref.read(webSocketManagerProvider);
    final repo = ref.read(chatRepositoryProvider);
    final authState = ref.read(authNotifierProvider);
    final userId = authState.valueOrNull?.user?.id ?? '';

    final id = _uuid.v4();
    final now = DateTime.now();

    // Build optimistic metadata
    final optimisticMeta = jsonEncode({
      'localPath': filePath,
      'duration': duration,
      'waveform': waveform,
      'mimeType': 'audio/aac',
    });

    // Insert optimistic message
    try {
      await dao.insertMessage(
        LocalMessagesCompanion.insert(
          id: id,
          convId: arg,
          senderId: userId,
          createdAt: now,
          type: const Value('voice'),
          metadata: Value(optimisticMeta),
          status: const Value('pending'),
        ),
      );
      await _setStateFromDao();
    } catch (e) {
      debugPrint('[Chat] Failed to insert optimistic voice message: $e');
    }

    // Update conversation preview
    try {
      await dao.updateConversation(
        arg,
        LocalConversationsCompanion(
          lastMessageAt: Value(now),
          lastMessageContent: const Value('\u{1F3A4} Tin nhắn thoại'),
          lastMessageSenderId: Value(userId),
        ),
      );
    } catch (e) {
      debugPrint('[Chat] Failed to update conversation preview: $e');
    }
    ref.invalidate(chatListProvider);

    final isOnline = wsManager.state == WsConnectionState.connected;

    if (!isOnline) {
      // Offline: cache file and queue upload
      try {
        final cacheDir = await getTemporaryDirectory();
        final cachedPath = '${cacheDir.path}/voice_cache_$id.m4a';
        await File(filePath).copy(cachedPath);
        await dao.insertPendingUpload(
          PendingUploadsCompanion.insert(
            id: id,
            convId: arg,
            localPaths: jsonEncode([cachedPath]),
            createdAt: now,
          ),
        );
      } catch (e) {
        debugPrint('[Chat] Failed to queue pending voice upload: $e');
      }
      return;
    }

    // Upload voice file
    try {
      final uploaded = await repo.uploadVoice(filePath);
      final finalMeta = {
        'url': uploaded['url'],
        'duration': duration,
        'waveform': waveform,
        'size': uploaded['size'],
        'mimeType': uploaded['mimeType'],
      };

      await dao.updateMessageMetadata(id, jsonEncode(finalMeta));

      wsManager.sendMessage({
        'id': id,
        'conv_id': arg,
        'type': 'voice',
        'metadata': finalMeta,
      }, id: id);

      await _setStateFromDao();
    } catch (e) {
      debugPrint('[Chat] Voice upload failed: $e');
      await dao.updateMessageStatus(id, 'failed');
      await _setStateFromDao();
    }
  }

  Future<void> sendFileMessage(
    XFile file, {
    String? replyToId,
    LocalMessage? replyToMessage,
  }) async {
    final dao = ref.read(chatDaoProvider);
    final wsManager = ref.read(webSocketManagerProvider);
    final repo = ref.read(chatRepositoryProvider);
    final authState = ref.read(authNotifierProvider);
    final userId = authState.valueOrNull?.user?.id ?? '';

    final id = _uuid.v4();
    final now = DateTime.now();
    final fileSize = await file.length();

    final optimisticMetaMap = <String, dynamic>{
      'localPath': file.path,
      'originalName': file.name,
      'mimeType': file.mimeType,
      'size': fileSize,
    };
    if (replyToMessage != null) {
      optimisticMetaMap['reply_to'] = {
        'id': replyToMessage.id,
        'sender_id': replyToMessage.senderId,
        'sender_name': null,
        'content': replyToMessage.content,
        'type': replyToMessage.type,
      };
    }
    final optimisticMeta = jsonEncode(optimisticMetaMap);

    try {
      await dao.insertMessage(
        LocalMessagesCompanion.insert(
          id: id,
          convId: arg,
          senderId: userId,
          createdAt: now,
          type: const Value('file'),
          content: Value(file.name),
          replyToId: Value(replyToId),
          metadata: Value(optimisticMeta),
          status: const Value('pending'),
        ),
      );
      await _setStateFromDao();
    } catch (e) {
      debugPrint('[Chat] Failed to insert optimistic file message: $e');
    }

    try {
      await dao.updateConversation(
        arg,
        LocalConversationsCompanion(
          lastMessageAt: Value(now),
          lastMessageContent: Value('\u{1F4CE} ${file.name}'),
          lastMessageSenderId: Value(userId),
        ),
      );
    } catch (e) {
      debugPrint('[Chat] Failed to update conversation preview: $e');
    }
    ref.invalidate(chatListProvider);

    final isOnline = wsManager.state == WsConnectionState.connected;

    if (!isOnline) {
      try {
        await dao.insertPendingUpload(
          PendingUploadsCompanion.insert(
            id: id,
            convId: arg,
            localPaths: jsonEncode([file.path]),
            caption: Value(file.name),
            createdAt: now,
          ),
        );
      } catch (e) {
        debugPrint('[Chat] Failed to queue pending file upload: $e');
      }
      return;
    }

    try {
      final uploaded = await repo.uploadFiles([file]);
      final uploadedFile = uploaded.first;
      final finalMeta = {
        'url': uploadedFile['url'],
        'originalName': uploadedFile['originalName'],
        'mimeType': uploadedFile['mimeType'],
        'size': uploadedFile['size'],
      };

      await dao.updateMessageMetadata(id, jsonEncode(finalMeta));

      final dispatched = wsManager.sendMessage({
        'id': id,
        'conv_id': arg,
        'type': 'file',
        'content': uploadedFile['originalName'] ?? file.name,
        'metadata': finalMeta,
        ...?(replyToId != null ? {'reply_to_id': replyToId} : null),
      }, id: id);

      if (!dispatched) {
        await dao.insertPendingUpload(
          PendingUploadsCompanion.insert(
            id: id,
            convId: arg,
            localPaths: jsonEncode([file.path]),
            caption: Value(file.name),
            createdAt: now,
          ),
        );
      }

      await _setStateFromDao();
    } catch (e) {
      debugPrint('[Chat] File upload failed: $e');
      await dao.updateMessageStatus(id, 'failed');
      await _setStateFromDao();
    }
  }

  Future<void> sendVideoMessage(
    XFile video,
    String? caption, {
    required int duration,
    required int width,
    required int height,
    required int fileSize,
  }) async {
    final dao = ref.read(chatDaoProvider);
    final wsManager = ref.read(webSocketManagerProvider);
    final repo = ref.read(chatRepositoryProvider);
    final authState = ref.read(authNotifierProvider);
    final userId = authState.valueOrNull?.user?.id ?? '';

    final id = _uuid.v4();
    final now = DateTime.now();

    // Build optimistic metadata with local path
    final optimisticMeta = jsonEncode({
      'url': video.path,
      'thumbnail': null,
      'duration': duration,
      'size': fileSize,
      'width': width,
      'height': height,
    });

    // Insert optimistic message
    try {
      await dao.insertMessage(
        LocalMessagesCompanion.insert(
          id: id,
          convId: arg,
          senderId: userId,
          createdAt: now,
          type: const Value('video'),
          content: Value(caption),
          metadata: Value(optimisticMeta),
          status: const Value('pending'),
        ),
      );
      await _setStateFromDao();
    } catch (e) {
      debugPrint('[Chat] Failed to insert optimistic video message: $e');
    }

    // Update conversation preview
    try {
      await dao.updateConversation(
        arg,
        LocalConversationsCompanion(
          lastMessageAt: Value(now),
          lastMessageContent: const Value('\u{1F3AC} Video'),
          lastMessageSenderId: Value(userId),
        ),
      );
    } catch (e) {
      debugPrint('[Chat] Failed to update conversation preview: $e');
    }
    ref.invalidate(chatListProvider);

    final isOnline = wsManager.state == WsConnectionState.connected;

    if (!isOnline) {
      try {
        await dao.insertPendingUpload(
          PendingUploadsCompanion.insert(
            id: id,
            convId: arg,
            localPaths: jsonEncode([video.path]),
            caption: Value(caption),
            createdAt: now,
          ),
        );
      } catch (e) {
        debugPrint('[Chat] Failed to queue pending video upload: $e');
      }
      return;
    }

    // Generate thumbnail
    final thumbnailBytes = await repo.generateVideoThumbnail(video.path);

    // Upload video + thumbnail
    try {
      final uploaded = await repo.uploadVideo(
        video,
        thumbnailBytes,
        onSendProgress: (sent, total) {
          final progress = sent / total;
          debugPrint(
            '[Chat] Video upload: ${(progress * 100).toStringAsFixed(0)}%',
          );
        },
      );

      final finalMeta = {
        'url': uploaded['video']['url'],
        'thumbnail': uploaded['thumbnail']?['url'],
        'duration': duration,
        'size': fileSize,
        'width': width,
        'height': height,
        'mimeType': uploaded['video']['mimeType'],
      };

      await dao.updateMessageMetadata(id, jsonEncode(finalMeta));

      wsManager.sendMessage({
        'id': id,
        'conv_id': arg,
        'type': 'video',
        'content': caption,
        'metadata': finalMeta,
      }, id: id);

      await _setStateFromDao();
    } catch (e) {
      debugPrint('[Chat] Video upload failed: $e');
      await dao.updateMessageStatus(id, 'failed');
      await _setStateFromDao();
    }
  }

  Map<String, dynamic>? _forwardableMetadata(
    EncryptedMessageAdapter adapter,
    String? metadataJson,
  ) {
    final metadata = adapter.decodeMetadata(metadataJson);
    if (metadata == null || metadata.isEmpty) return null;
    final cloned = Map<String, dynamic>.from(metadata);
    cloned.remove(EncryptedMessageAdapter.envelopeMetadataKey);
    return cloned.isEmpty ? null : cloned;
  }

  Future<void> _refreshConversationCache(String convId) async {
    if (convId == arg) {
      await _setStateFromDao();
      return;
    }
    ref.invalidate(chatMessagesProvider(convId));
  }

  Future<void> _sendForwardedMessageToConversation({
    required LocalMessage sourceMessage,
    required String targetConvId,
    required String? forwardedFromId,
    required String? forwardedFromSender,
  }) async {
    final dao = ref.read(chatDaoProvider);
    final wsManager = ref.read(webSocketManagerProvider);
    final adapter = ref.read(encryptedMessageAdapterProvider);
    final keyRepository = ref.read(conversationKeyRepositoryProvider);
    final authState = ref.read(authNotifierProvider);
    final userId = authState.valueOrNull?.user?.id ?? '';

    final id = _uuid.v4();
    final now = DateTime.now();
    final metadataMap = _forwardableMetadata(adapter, sourceMessage.metadata);
    final type = sourceMessage.type;

    EncryptedMessageEnvelope? envelope;
    final String? content = sourceMessage.content;
    var shouldPersistPlaintext = true;

    if (type == 'text' && content != null && content.trim().isNotEmpty) {
      try {
        final activeKey = await keyRepository.resolveActiveKey(targetConvId);
        envelope = await adapter.encryptText(
          plaintext: content,
          key: activeKey,
          messageId: id,
          convId: targetConvId,
        );
        shouldPersistPlaintext = false;
      } catch (error) {
        if (!shouldFallbackToLegacyPlaintext(error)) {
          debugPrint(
            '[Chat][Forward][Encrypt] Failed for message_id=$id '
            'conv_id=$targetConvId: $error',
          );
          rethrow;
        }
        debugPrint(
          '[Chat][Forward] Encryption key endpoint unavailable for '
          'conversation $targetConvId, falling back to legacy plaintext send.',
        );
      }
    }

    final metadataJson = adapter.buildMetadataJson(
      existingMetadata: metadataMap,
      envelope: envelope,
    );

    await dao.insertMessage(
      LocalMessagesCompanion.insert(
        id: id,
        convId: targetConvId,
        senderId: userId,
        createdAt: now,
        type: Value(type),
        content: Value(
          type == 'text' && !shouldPersistPlaintext ? null : content,
        ),
        metadata: Value(metadataJson),
        status: const Value('pending'),
        forwardedFromId: Value(forwardedFromId),
        forwardedFromSender: Value(forwardedFromSender),
      ),
    );

    final previewContent = adapter.safePreviewForMessage(
      type: type,
      content: content,
      metadataJson: metadataJson,
      deletedAt: null,
    );

    await dao.updateConversation(
      targetConvId,
      LocalConversationsCompanion(
        lastMessageAt: Value(now),
        lastMessageContent: Value(previewContent),
        lastMessageSenderId: Value(userId),
      ),
    );

    await _refreshConversationCache(targetConvId);
    ref.invalidate(chatListProvider);

    final payload = <String, dynamic>{
      'id': id,
      'conv_id': targetConvId,
      'type': type,
      'content': type == 'text' && envelope != null ? null : content,
      ...?(metadataMap != null ? {'metadata': metadataMap} : null),
      ...?(envelope != null ? {'encrypted_content': envelope.toJson()} : null),
      ...?(forwardedFromId != null
          ? {'forwarded_from_id': forwardedFromId}
          : null),
      ...?(forwardedFromSender != null
          ? {'forwarded_from_sender': forwardedFromSender}
          : null),
    };

    final dispatched = wsManager.sendMessage(payload, id: id);
    if (!dispatched) {
      debugPrint('[Chat][Forward] Send queued for retry: $id');
      await dao.incrementRetryCount(id);
    }
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull ?? [];
    if (current.isEmpty) return;

    final repo = ref.read(chatRepositoryProvider);
    final dao = ref.read(chatDaoProvider);
    final oldest = current.last;
    final pagination = ref.read(chatHistoryPaginationProvider(arg));
    if (!pagination.hasMore) return;

    final result = await repo.getMessages(
      arg,
      cursor: pagination.nextCursor ?? oldest.createdAt.toIso8601String(),
      dir: 'before',
    );
    _updateHistoryPagination(result);

    final messages = result['messages'] as List? ?? [];
    for (final m in messages) {
      final msg = m as Map<String, dynamic>;

      await dao.insertMessage(
        buildIncomingMessageCompanion(msg, defaultStatus: 'sent'),
      );
      // Store reactions if present
      final reactions = msg['reactions'] as List?;
      if (reactions != null && reactions.isNotEmpty) {
        await _storeReactionsForMessage(msg['id'] as String, reactions);
      }
    }

    await _setStateFromDao(limit: current.length + 30);
  }

  Future<void> forwardMessages(
    List<String> messageIds,
    List<String> convIds,
    bool hideSender,
  ) async {
    if (arg.isEmpty || messageIds.isEmpty || convIds.isEmpty) return;

    final dao = ref.read(chatDaoProvider);
    final memberMap = hideSender
        ? const <String, Map<String, String?>>{}
        : await ref.read(conversationMembersProvider(arg).future);

    final rawMessages = await Future.wait(
      messageIds.map((messageId) => dao.getMessage(messageId)),
    );
    final sourceMessages =
        rawMessages
            .whereType<LocalMessage>()
            .where((message) => message.convId == arg)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    if (sourceMessages.isEmpty) return;

    final resolvedMessages = await _resolveLocalMessagesForUi(
      ref,
      sourceMessages,
    );

    for (final targetConvId in convIds) {
      for (final message in resolvedMessages) {
        final forwardedFromId = message.forwardedFromId ?? message.id;
        final forwardedFromSender = hideSender
            ? null
            : (message.forwardedFromSender ??
                  memberMap[message.senderId]?['name']);
        await _sendForwardedMessageToConversation(
          sourceMessage: message,
          targetConvId: targetConvId,
          forwardedFromId: forwardedFromId,
          forwardedFromSender: forwardedFromSender,
        );
      }
    }
  }
}

// --- Search Providers ---

final localSearchProvider = FutureProvider.family<List<SearchResult>, String>((
  ref,
  query,
) async {
  if (query.length < 2) return [];
  final dao = ref.read(chatDaoProvider);
  final rows = await dao.searchMessagesWithContext(query);
  return rows.map((row) => SearchResult.fromLocalRow(row, query)).toList();
});

final messageSeenByProvider = FutureProvider.autoDispose
    .family<MessageSeenByResponse, MessageSeenByRequest>((ref, request) async {
      final repo = ref.read(chatRepositoryProvider);
      return repo.getMessageSeenBy(request.convId, request.messageId);
    });

final conversationSeenByPlacementProvider = FutureProvider.autoDispose
    .family<
      Map<String, List<MessageSeenByUser>>,
      ConversationSeenByPlacementRequest
    >((ref, request) async {
      final repo = ref.read(chatRepositoryProvider);
      final seenByByMessage = <String, List<MessageSeenByUser>>{};

      await Future.wait(
        request.messageIdsNewestFirst.map((messageId) async {
          try {
            final response = await repo.getMessageSeenBy(
              request.convId,
              messageId,
            );
            seenByByMessage[messageId] = response.seenBy
                .where((user) => user.userId != request.currentUserId)
                .toList();
          } catch (_) {
            seenByByMessage[messageId] = const [];
          }
        }),
      );

      final placements = <String, List<MessageSeenByUser>>{};
      final assignedUserIds = <String>{};

      for (final messageId in request.messageIdsNewestFirst) {
        final users = seenByByMessage[messageId] ?? const [];
        final latestReaders = <MessageSeenByUser>[];

        for (final user in users) {
          if (assignedUserIds.add(user.userId)) {
            latestReaders.add(user);
          }
        }

        if (latestReaders.isNotEmpty) {
          placements[messageId] = latestReaders;
        }
      }

      return placements;
    });

const _serverSearchFieldUnset = Object();

class ServerSearchState {
  final String query;
  final List<SearchResult> results;
  final String? nextCursor;
  final bool hasMore;
  final bool isLoadingMore;
  final bool isLoading;
  final String? errorMessage;
  final String? loadMoreErrorMessage;

  const ServerSearchState({
    this.query = '',
    this.results = const [],
    this.nextCursor,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.isLoading = false,
    this.errorMessage,
    this.loadMoreErrorMessage,
  });

  ServerSearchState copyWith({
    String? query,
    List<SearchResult>? results,
    Object? nextCursor = _serverSearchFieldUnset,
    bool? hasMore,
    bool? isLoadingMore,
    bool? isLoading,
    Object? errorMessage = _serverSearchFieldUnset,
    Object? loadMoreErrorMessage = _serverSearchFieldUnset,
  }) {
    return ServerSearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      nextCursor: nextCursor == _serverSearchFieldUnset
          ? this.nextCursor
          : nextCursor as String?,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage == _serverSearchFieldUnset
          ? this.errorMessage
          : errorMessage as String?,
      loadMoreErrorMessage: loadMoreErrorMessage == _serverSearchFieldUnset
          ? this.loadMoreErrorMessage
          : loadMoreErrorMessage as String?,
    );
  }
}

class ServerSearchNotifier extends Notifier<ServerSearchState> {
  int _requestGeneration = 0;

  @override
  ServerSearchState build() => const ServerSearchState();

  Future<void> search(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.length < 2) {
      _requestGeneration += 1;
      state = const ServerSearchState();
      return;
    }
    final requestGeneration = ++_requestGeneration;
    state = ServerSearchState(query: normalizedQuery, isLoading: true);
    try {
      final repo = ref.read(chatRepositoryProvider);
      final data = await repo.searchMessages(query: normalizedQuery);
      if (requestGeneration != _requestGeneration ||
          state.query != normalizedQuery) {
        return;
      }
      final results = (data['results'] as List? ?? [])
          .map(
            (r) => SearchResult.fromServerResponse(r as Map<String, dynamic>),
          )
          .toList();
      state = ServerSearchState(
        query: normalizedQuery,
        results: results,
        nextCursor: data['next_cursor'] as String?,
        hasMore: data['has_more'] as bool? ?? false,
        isLoading: false,
      );
    } catch (e) {
      if (requestGeneration != _requestGeneration ||
          state.query != normalizedQuery) {
        return;
      }
      state = ServerSearchState(
        query: normalizedQuery,
        isLoading: false,
        errorMessage: e.toString(),
      );
      debugPrint('[Search] Server search error: $e');
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.nextCursor == null) {
      return;
    }
    final query = state.query;
    final requestGeneration = _requestGeneration;
    state = state.copyWith(isLoadingMore: true, loadMoreErrorMessage: null);
    try {
      final repo = ref.read(chatRepositoryProvider);
      final data = await repo.searchMessages(
        query: query,
        cursor: state.nextCursor,
      );
      if (requestGeneration != _requestGeneration || state.query != query) {
        return;
      }
      final newResults = (data['results'] as List? ?? [])
          .map(
            (r) => SearchResult.fromServerResponse(r as Map<String, dynamic>),
          )
          .toList();
      state = state.copyWith(
        results: [...state.results, ...newResults],
        nextCursor: data['next_cursor'] as String?,
        hasMore: data['has_more'] as bool? ?? false,
        isLoadingMore: false,
        loadMoreErrorMessage: null,
      );
    } catch (e) {
      if (requestGeneration != _requestGeneration || state.query != query) {
        return;
      }
      state = state.copyWith(
        isLoadingMore: false,
        loadMoreErrorMessage: e.toString(),
      );
      debugPrint('[Search] Server loadMore error: $e');
    }
  }

  void clear() {
    _requestGeneration += 1;
    state = const ServerSearchState();
  }
}

final serverSearchNotifierProvider =
    NotifierProvider<ServerSearchNotifier, ServerSearchState>(
      ServerSearchNotifier.new,
    );
