import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/chat_dao.dart';
import '../../../core/network/websocket_manager.dart';
import '../../../core/network/websocket_provider.dart';
import 'chat_repository.dart';
import 'encrypted_message_adapter.dart';
import '../providers/chat_providers.dart';

const Set<String> _retrySafePendingMessageTypes = {'text'};

bool shouldReplayPendingMessageType(String type) {
  return _retrySafePendingMessageTypes.contains(type);
}

abstract class OfflineQueueDao {
  Future<List<LocalMessage>> getPendingMessages();
  Future<void> updateMessageStatus(String id, String status);
  Future<void> incrementRetryCount(String id);
  Future<void> resetRetryCount(String id);
  Future<List<PendingUpload>> getPendingUploads();
  Future<void> updatePendingUploadStatus(
    String id,
    String status, {
    int? retryCount,
  });
  Future<LocalMessage?> getMessage(String id);
  Future<void> updateMessageMetadata(String id, String metadata);
  Future<void> deletePendingUpload(String id);
}

abstract class OfflineQueueWsManager {
  Stream<WsConnectionState> get stateStream;
  WsConnectionState get state;
  bool sendMessage(Map<String, dynamic> data, {String? id});
  void on(String event, WsEventHandler handler);
  void off(String event, WsEventHandler handler);
}

abstract class OfflineQueueRepository {
  Future<List<Map<String, dynamic>>> uploadFiles(List<XFile> files);
  Future<List<Map<String, dynamic>>> uploadImages(List<XFile> files);
  Future<Map<String, dynamic>> uploadVoice(String filePath);
  Future<Uint8List?> generateVideoThumbnail(String videoPath);
  Future<Map<String, dynamic>> uploadVideo(
    XFile video,
    Uint8List? thumbnailBytes,
  );
}

class _ChatDaoOfflineQueueAdapter implements OfflineQueueDao {
  final ChatDao _dao;

  _ChatDaoOfflineQueueAdapter(this._dao);

  @override
  Future<void> deletePendingUpload(String id) => _dao.deletePendingUpload(id);

  @override
  Future<LocalMessage?> getMessage(String id) => _dao.getMessage(id);

  @override
  Future<List<PendingUpload>> getPendingUploads() => _dao.getPendingUploads();

  @override
  Future<List<LocalMessage>> getPendingMessages() => _dao.getPendingMessages();

  @override
  Future<void> incrementRetryCount(String id) => _dao.incrementRetryCount(id);

  @override
  Future<void> resetRetryCount(String id) => _dao.resetRetryCount(id);

  @override
  Future<void> updateMessageMetadata(String id, String metadata) =>
      _dao.updateMessageMetadata(id, metadata);

  @override
  Future<void> updateMessageStatus(String id, String status) =>
      _dao.updateMessageStatus(id, status);

  @override
  Future<void> updatePendingUploadStatus(
    String id,
    String status, {
    int? retryCount,
  }) => _dao.updatePendingUploadStatus(id, status, retryCount: retryCount);
}

class _WebSocketManagerOfflineQueueAdapter implements OfflineQueueWsManager {
  final WebSocketManager _wsManager;

  _WebSocketManagerOfflineQueueAdapter(this._wsManager);

  @override
  void off(String event, WsEventHandler handler) =>
      _wsManager.off(event, handler);

  @override
  void on(String event, WsEventHandler handler) =>
      _wsManager.on(event, handler);

  @override
  bool sendMessage(Map<String, dynamic> data, {String? id}) =>
      _wsManager.sendMessage(data, id: id);

  @override
  WsConnectionState get state => _wsManager.state;

  @override
  Stream<WsConnectionState> get stateStream => _wsManager.stateStream;
}

class _ChatRepositoryOfflineQueueAdapter implements OfflineQueueRepository {
  final ChatRepository _repo;

  _ChatRepositoryOfflineQueueAdapter(this._repo);

  @override
  Future<Uint8List?> generateVideoThumbnail(String videoPath) =>
      _repo.generateVideoThumbnail(videoPath);

  @override
  Future<List<Map<String, dynamic>>> uploadFiles(List<XFile> files) =>
      _repo.uploadFiles(files);

  @override
  Future<List<Map<String, dynamic>>> uploadImages(List<XFile> files) =>
      _repo.uploadImages(files);

  @override
  Future<Map<String, dynamic>> uploadVoice(String filePath) =>
      _repo.uploadVoice(filePath);

  @override
  Future<Map<String, dynamic>> uploadVideo(
    XFile video,
    Uint8List? thumbnailBytes,
  ) => _repo.uploadVideo(video, thumbnailBytes);
}

final offlineQueueServiceProvider = Provider<OfflineQueueService>((ref) {
  final dao = ref.read(chatDaoProvider);
  final wsManager = ref.read(webSocketManagerProvider);
  final repo = ref.read(chatRepositoryProvider);
  final service = OfflineQueueService(
    _ChatDaoOfflineQueueAdapter(dao),
    _WebSocketManagerOfflineQueueAdapter(wsManager),
    _ChatRepositoryOfflineQueueAdapter(repo),
  );
  ref.onDispose(() => service.dispose());
  return service;
});

class OfflineQueueService {
  final OfflineQueueDao _dao;
  final OfflineQueueWsManager _wsManager;
  final OfflineQueueRepository _repo;
  StreamSubscription? _stateSub;
  Timer? _retryTimer;
  static const _maxRetries = 5;
  final _encryptedAdapter = EncryptedMessageAdapter();

  OfflineQueueService(this._dao, this._wsManager, this._repo) {
    _stateSub = _wsManager.stateStream.listen((state) {
      if (state == WsConnectionState.connected) {
        _flushQueue();
        _flushPendingUploads();
      }
    });

    // Listen for ACKs to clear pending messages
    _wsManager.on('message_ack', _onAck);

    // Periodic retry for pending messages
    _retryTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_wsManager.state == WsConnectionState.connected) {
        _flushQueue();
      }
    });
  }

  void _onAck(Map<String, dynamic> data) {
    final id = data['id'] as String?;
    if (id != null) {
      unawaited(_dao.updateMessageStatus(id, 'sent'));
    }
  }

  Future<void> _flushQueue() async {
    final pending = await _dao.getPendingMessages();
    for (final msg in pending) {
      if (!shouldReplayPendingMessageType(msg.type)) {
        continue;
      }

      if (msg.retryCount >= _maxRetries) {
        await _dao.updateMessageStatus(msg.id, 'failed');
        continue;
      }

      // Exponential backoff delay
      if (msg.retryCount > 0) {
        final delay = min(pow(2, msg.retryCount - 1).toInt(), 16);
        await Future.delayed(Duration(seconds: delay));
      }

      try {
        final payload = <String, dynamic>{
          'id': msg.id,
          'conv_id': msg.convId,
          'type': msg.type,
        };

        final encryptedEnvelope = _encryptedAdapter.envelopeFromMetadata(
          msg.metadata,
        );
        if (encryptedEnvelope != null) {
          payload['encrypted_content'] = encryptedEnvelope.toJson();
        } else {
          payload['content'] = msg.content;
        }

        // Include metadata (mentions, link preview, etc.)
        if (msg.metadata != null) {
          try {
            final decoded = jsonDecode(msg.metadata!);
            if (decoded is Map<String, dynamic>) {
              final adapter = _encryptedAdapter;
              final blindIndex =
                  decoded[EncryptedMessageAdapter.blindIndexMetadataKey];
              if (blindIndex is Map<String, dynamic>) {
                payload[EncryptedMessageAdapter.blindIndexMetadataKey] =
                    blindIndex;
              } else if (blindIndex is Map) {
                payload[EncryptedMessageAdapter.blindIndexMetadataKey] =
                    Map<String, dynamic>.from(blindIndex);
              }
              final sanitized = adapter.sanitizeOutgoingMetadata(decoded);
              if (sanitized != null && sanitized.isNotEmpty) {
                payload['metadata'] = sanitized;
              }
            }
          } catch (_) {}
        }
        final dispatched = _wsManager.sendMessage(payload, id: msg.id);

        // Increment retry count
        await _dao.incrementRetryCount(msg.id);
        if (!dispatched) {
          debugPrint('[OfflineQueue] sendMessage not dispatched for ${msg.id}');
        }
      } catch (e) {
        debugPrint('Offline queue send failed: $e');
      }
    }
  }

  /// Retry a specific failed message (user tapped Retry)
  Future<void> retryMessage(String messageId) async {
    await _dao.resetRetryCount(messageId);
    await _dao.updateMessageStatus(messageId, 'pending');
    if (_wsManager.state == WsConnectionState.connected) {
      _flushQueue();
    }
  }

  /// Process pending image uploads on reconnect
  Future<void> _flushPendingUploads() async {
    final pending = await _dao.getPendingUploads();
    for (final upload in pending) {
      if (upload.retryCount >= _maxRetries) {
        await _dao.updatePendingUploadStatus(upload.id, 'failed');
        await _dao.updateMessageStatus(upload.id, 'failed');
        continue;
      }

      try {
        await _dao.updatePendingUploadStatus(upload.id, 'uploading');

        final localPaths = (jsonDecode(upload.localPaths) as List)
            .cast<String>();
        final message = await _dao.getMessage(upload.id);
        final messageType = message?.type ?? 'image';
        if (messageType == 'file' &&
            await _canSendUploadedFileWithoutLocalCopy(message)) {
          await _processFileUpload(
            upload,
            null,
            localPaths: localPaths,
            existingMessage: message,
          );
          continue;
        }

        final xFiles = localPaths
            .where((p) => File(p).existsSync())
            .map((p) => XFile(p))
            .toList();

        if (xFiles.isEmpty) {
          await _dao.updatePendingUploadStatus(upload.id, 'failed');
          await _dao.updateMessageStatus(upload.id, 'failed');
          continue;
        }

        switch (messageType) {
          case 'video':
            await _processVideoUpload(upload, xFiles.first);
            break;
          case 'voice':
            await _processVoiceUpload(upload, localPaths.first);
            break;
          case 'file':
            await _processFileUpload(
              upload,
              xFiles.first,
              localPaths: localPaths,
              existingMessage: message,
            );
            break;
          case 'image':
          case 'album':
          default:
            await _processImageUpload(upload, xFiles, localPaths: localPaths);
            break;
        }
      } catch (e) {
        debugPrint('Pending upload failed: $e');
        await _dao.updatePendingUploadStatus(
          upload.id,
          'queued',
          retryCount: upload.retryCount + 1,
        );
      }
    }
  }

  /// Retry a specific failed image upload
  Future<void> retryUpload(String uploadId) async {
    await _dao.updatePendingUploadStatus(uploadId, 'queued', retryCount: 0);
    await _dao.updateMessageStatus(uploadId, 'pending');
    if (_wsManager.state == WsConnectionState.connected) {
      _flushPendingUploads();
    }
  }

  Future<bool> _canSendUploadedFileWithoutLocalCopy(
    LocalMessage? message,
  ) async {
    if (message?.metadata == null) return false;
    try {
      final meta = jsonDecode(message!.metadata!) as Map<String, dynamic>;
      return meta['url'] is String && (meta['url'] as String).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _processImageUpload(
    PendingUpload upload,
    List<XFile> xFiles, {
    required List<String> localPaths,
  }) async {
    final uploaded = await _repo.uploadImages(xFiles);
    final msgType = xFiles.length == 1 ? 'image' : 'album';

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
              },
            )
            .toList(),
        if (upload.caption != null) 'caption': upload.caption,
      };
    } else {
      finalMeta = {
        'url': uploaded.first['url'],
        'originalName': uploaded.first['originalName'],
        'size': uploaded.first['size'],
        'mimeType': uploaded.first['mimeType'],
        if (upload.caption != null) 'caption': upload.caption,
      };
    }

    await _dao.updateMessageMetadata(upload.id, jsonEncode(finalMeta));

    _wsManager.sendMessage({
      'id': upload.id,
      'conv_id': upload.convId,
      'type': msgType,
      'content': upload.caption,
      'metadata': finalMeta,
    }, id: upload.id);

    await _dao.deletePendingUpload(upload.id);
    for (final path in localPaths) {
      try {
        File(path).deleteSync();
      } catch (_) {}
    }
  }

  Future<void> _processVideoUpload(
    PendingUpload upload,
    XFile videoFile,
  ) async {
    // Read existing optimistic metadata to preserve duration/size/width/height
    Map<String, dynamic> existingMeta = {};
    try {
      final msg = await _dao.getMessage(upload.id);
      if (msg?.metadata != null) {
        existingMeta = jsonDecode(msg!.metadata!) as Map<String, dynamic>;
      }
    } catch (_) {}

    final thumbnailBytes = await _repo.generateVideoThumbnail(videoFile.path);
    final uploaded = await _repo.uploadVideo(videoFile, thumbnailBytes);

    final finalMeta = {
      'url': uploaded['video']['url'],
      'thumbnail': uploaded['thumbnail']?['url'],
      'duration': existingMeta['duration'],
      'size': existingMeta['size'],
      'width': existingMeta['width'],
      'height': existingMeta['height'],
      'mimeType': uploaded['video']['mimeType'],
    };

    await _dao.updateMessageMetadata(upload.id, jsonEncode(finalMeta));

    _wsManager.sendMessage({
      'id': upload.id,
      'conv_id': upload.convId,
      'type': 'video',
      'content': upload.caption,
      'metadata': finalMeta,
    }, id: upload.id);

    await _dao.deletePendingUpload(upload.id);
    try {
      File(videoFile.path).deleteSync();
    } catch (_) {}
  }

  Future<void> _processVoiceUpload(
    PendingUpload upload,
    String filePath,
  ) async {
    final uploaded = await _repo.uploadVoice(filePath);

    Map<String, dynamic> existingMeta = {};
    try {
      final msg = await _dao.getMessage(upload.id);
      if (msg?.metadata != null) {
        existingMeta = jsonDecode(msg!.metadata!) as Map<String, dynamic>;
      }
    } catch (_) {}

    final finalMeta = {
      'url': uploaded['url'],
      'duration': existingMeta['duration'],
      'waveform': existingMeta['waveform'],
      'size': uploaded['size'],
      'mimeType': uploaded['mimeType'],
    };

    await _dao.updateMessageMetadata(upload.id, jsonEncode(finalMeta));
    _wsManager.sendMessage({
      'id': upload.id,
      'conv_id': upload.convId,
      'type': 'voice',
      'metadata': finalMeta,
    }, id: upload.id);

    await _dao.deletePendingUpload(upload.id);
    try {
      File(filePath).deleteSync();
    } catch (_) {}
  }

  Future<void> _processFileUpload(
    PendingUpload upload,
    XFile? file, {
    required List<String> localPaths,
    required LocalMessage? existingMessage,
  }) async {
    Map<String, dynamic> existingMeta = {};
    try {
      if (existingMessage?.metadata != null) {
        existingMeta =
            jsonDecode(existingMessage!.metadata!) as Map<String, dynamic>;
      }
    } catch (_) {}

    Map<String, dynamic> finalMeta;
    final hasUploadedUrl =
        existingMeta['url'] is String &&
        (existingMeta['url'] as String).isNotEmpty;

    if (hasUploadedUrl) {
      finalMeta = existingMeta;
    } else {
      if (file == null) {
        throw StateError('Missing local file for pending attachment upload');
      }
      final uploaded = await _repo.uploadFiles([file]);
      final uploadedFile = uploaded.first;
      finalMeta = {
        'url': uploadedFile['url'],
        'originalName': uploadedFile['originalName'],
        'mimeType': uploadedFile['mimeType'],
        'size': uploadedFile['size'],
      };
      await _dao.updateMessageMetadata(upload.id, jsonEncode(finalMeta));
    }

    _wsManager.sendMessage({
      'id': upload.id,
      'conv_id': upload.convId,
      'type': 'file',
      'content': finalMeta['originalName'] ?? upload.caption,
      'metadata': finalMeta,
    }, id: upload.id);

    await _dao.deletePendingUpload(upload.id);
    for (final path in localPaths) {
      if (path.isEmpty) continue;
      try {
        File(path).deleteSync();
      } catch (_) {}
    }
  }

  void dispose() {
    _stateSub?.cancel();
    _retryTimer?.cancel();
    _wsManager.off('message_ack', _onAck);
  }
}
