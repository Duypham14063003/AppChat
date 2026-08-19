import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nineteen_tech_app/core/database/app_database.dart';
import 'package:nineteen_tech_app/core/network/websocket_manager.dart';
import 'package:nineteen_tech_app/features/chat/data/offline_queue_service.dart';

void main() {
  group('shouldReplayPendingMessageType', () {
    test('replays only text messages', () {
      expect(shouldReplayPendingMessageType('text'), isTrue);
      expect(shouldReplayPendingMessageType('image'), isFalse);
      expect(shouldReplayPendingMessageType('album'), isFalse);
      expect(shouldReplayPendingMessageType('voice'), isFalse);
      expect(shouldReplayPendingMessageType('video'), isFalse);
      expect(shouldReplayPendingMessageType('file'), isFalse);
    });
  });

  group('OfflineQueueService', () {
    test('retries pending text on reconnect and marks sent on ACK', () async {
      final dao = FakeOfflineQueueDao(
        messages: [
          _message(
            id: 'msg-text-1',
            type: 'text',
            status: 'pending',
            retryCount: 0,
          ),
        ],
      );
      final ws = FakeOfflineQueueWsManager();
      final repo = FakeOfflineQueueRepository();
      final service = OfflineQueueService(dao, ws, repo);

      addTearDown(() {
        service.dispose();
        ws.dispose();
      });

      ws.emitState(WsConnectionState.connected);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(ws.sentMessages, hasLength(1));
      expect(ws.sentMessages.single.id, 'msg-text-1');
      expect(ws.sentMessages.single.data['type'], 'text');
      expect(dao.messageById('msg-text-1')?.retryCount, 1);

      ws.emitEvent('message_ack', {'id': 'msg-text-1'});
      await Future<void>.delayed(Duration.zero);

      expect(dao.messageById('msg-text-1')?.status, 'sent');
    });

    test('does not replay pending media through text resend path', () async {
      final dao = FakeOfflineQueueDao(
        messages: [
          _message(id: 'm-image', type: 'image', status: 'pending'),
          _message(id: 'm-album', type: 'album', status: 'pending'),
          _message(id: 'm-voice', type: 'voice', status: 'pending'),
          _message(id: 'm-video', type: 'video', status: 'pending'),
        ],
      );
      final ws = FakeOfflineQueueWsManager();
      final repo = FakeOfflineQueueRepository();
      final service = OfflineQueueService(dao, ws, repo);

      addTearDown(() {
        service.dispose();
        ws.dispose();
      });

      ws.emitState(WsConnectionState.connected);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(ws.sentMessages, isEmpty);
      expect(dao.messageById('m-image')?.status, 'pending');
      expect(dao.messageById('m-album')?.status, 'pending');
      expect(dao.messageById('m-voice')?.status, 'pending');
      expect(dao.messageById('m-video')?.status, 'pending');
    });
  });
}

LocalMessage _message({
  required String id,
  required String type,
  required String status,
  int retryCount = 0,
}) {
  return LocalMessage(
    id: id,
    convId: 'conv-1',
    senderId: 'user-1',
    type: type,
    content: 'hello',
    createdAt: DateTime(2026, 4, 23, 10),
    status: status,
    retryCount: retryCount,
  );
}

class SentWsMessage {
  final Map<String, dynamic> data;
  final String? id;

  const SentWsMessage({required this.data, required this.id});
}

class FakeOfflineQueueWsManager implements OfflineQueueWsManager {
  final StreamController<WsConnectionState> _stateController =
      StreamController<WsConnectionState>.broadcast();
  final Map<String, List<WsEventHandler>> _handlers = {};
  final List<SentWsMessage> sentMessages = [];
  WsConnectionState _state;
  bool sendShouldSucceed;

  FakeOfflineQueueWsManager({
    WsConnectionState initialState = WsConnectionState.disconnected,
    this.sendShouldSucceed = true,
  }) : _state = initialState;

  @override
  void off(String event, WsEventHandler handler) {
    _handlers[event]?.remove(handler);
  }

  @override
  void on(String event, WsEventHandler handler) {
    _handlers.putIfAbsent(event, () => []).add(handler);
  }

  @override
  bool sendMessage(Map<String, dynamic> data, {String? id}) {
    sentMessages.add(
      SentWsMessage(data: Map<String, dynamic>.from(data), id: id),
    );
    return sendShouldSucceed;
  }

  @override
  WsConnectionState get state => _state;

  @override
  Stream<WsConnectionState> get stateStream => _stateController.stream;

  void emitState(WsConnectionState next) {
    _state = next;
    _stateController.add(next);
  }

  void emitEvent(String event, Map<String, dynamic> data) {
    final handlers = List<WsEventHandler>.from(_handlers[event] ?? const []);
    for (final handler in handlers) {
      handler(data);
    }
  }

  void dispose() {
    _stateController.close();
  }
}

class FakeOfflineQueueDao implements OfflineQueueDao {
  final Map<String, LocalMessage> _messages;
  final Map<String, PendingUpload> _uploads;

  FakeOfflineQueueDao({
    List<LocalMessage> messages = const [],
    List<PendingUpload> uploads = const [],
  }) : _messages = {for (final message in messages) message.id: message},
       _uploads = {for (final upload in uploads) upload.id: upload};

  LocalMessage? messageById(String id) => _messages[id];

  @override
  Future<void> deletePendingUpload(String id) async {
    _uploads.remove(id);
  }

  @override
  Future<LocalMessage?> getMessage(String id) async {
    return _messages[id];
  }

  @override
  Future<List<PendingUpload>> getPendingUploads() async {
    final items = _uploads.values
        .where((upload) => upload.status == 'queued')
        .toList();
    items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return items;
  }

  @override
  Future<List<LocalMessage>> getPendingMessages() async {
    final items = _messages.values
        .where((message) => message.status == 'pending')
        .toList();
    items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return items;
  }

  @override
  Future<void> incrementRetryCount(String id) async {
    final current = _messages[id];
    if (current == null) return;
    _messages[id] = current.copyWith(retryCount: current.retryCount + 1);
  }

  @override
  Future<void> resetRetryCount(String id) async {
    final current = _messages[id];
    if (current == null) return;
    _messages[id] = current.copyWith(retryCount: 0);
  }

  @override
  Future<void> updateMessageMetadata(String id, String metadata) async {
    final current = _messages[id];
    if (current == null) return;
    _messages[id] = current.copyWith(metadata: Value(metadata));
  }

  @override
  Future<void> updateMessageStatus(String id, String status) async {
    final current = _messages[id];
    if (current == null) return;
    _messages[id] = current.copyWith(status: status);
  }

  @override
  Future<void> updatePendingUploadStatus(
    String id,
    String status, {
    int? retryCount,
  }) async {
    final current = _uploads[id];
    if (current == null) return;
    _uploads[id] = current.copyWith(
      status: status,
      retryCount: retryCount ?? current.retryCount,
    );
  }
}

class FakeOfflineQueueRepository implements OfflineQueueRepository {
  @override
  Future<Uint8List?> generateVideoThumbnail(String videoPath) async {
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>> uploadFiles(List<XFile> files) async {
    return [
      {
        'url': 'https://example.com/${files.first.name}',
        'originalName': files.first.name,
        'size': 1024,
        'mimeType': 'application/pdf',
      },
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> uploadImages(List<XFile> files) async {
    return const [];
  }

  @override
  Future<Map<String, dynamic>> uploadVoice(String filePath) async {
    return {
      'url': 'https://example.com/voice.m4a',
      'size': 2048,
      'mimeType': 'audio/aac',
    };
  }

  @override
  Future<Map<String, dynamic>> uploadVideo(
    XFile video,
    Uint8List? thumbnailBytes,
  ) async {
    return {
      'video': {
        'url': 'https://example.com/video.mp4',
        'mimeType': 'video/mp4',
      },
      'thumbnail': {'url': 'https://example.com/thumb.jpg'},
    };
  }
}
