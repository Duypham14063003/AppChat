import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();
const callKitAppSourceKey = 'appSource';
const callKitAppSourceValue = '19t-mobile-call';
const callKitBusinessCallIdKey = 'callId';
const callKitNativeCallIdKey = 'nativeCallId';
const callKitDirectionKey = 'callDirection';
final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);

Map<String, dynamic> _normalizeDynamicMap(Object? rawValue) {
  if (rawValue is! Map) return const <String, dynamic>{};
  return Map<String, dynamic>.from(
    rawValue.map((key, value) => MapEntry(key.toString(), value)),
  );
}

String _ensureCallkitUuid(Object? rawValue) {
  final value = rawValue?.toString().trim();
  if (value != null && _uuidPattern.hasMatch(value)) {
    return value;
  }
  return _uuid.v4();
}

Map<String, dynamic> buildAppOwnedCallKitExtra({
  required String callId,
  required String nativeCallId,
  required String callDirection,
  Map<String, dynamic> extra = const <String, dynamic>{},
}) {
  return <String, dynamic>{
    ...extra,
    callKitAppSourceKey: callKitAppSourceValue,
    callKitBusinessCallIdKey: callId,
    callKitNativeCallIdKey: nativeCallId,
    callKitDirectionKey: callDirection,
  };
}

Map<String, dynamic> normalizeCallKitMap(Object? rawValue) {
  return _normalizeDynamicMap(rawValue);
}

Map<String, dynamic> extractCallKitExtra(Object? rawValue) {
  final normalized = normalizeCallKitMap(rawValue);
  return normalizeCallKitMap(normalized['extra']);
}

String? extractAppOwnedBusinessCallId(Object? rawValue) {
  final call = normalizeCallKitMap(rawValue);
  final extra = extractCallKitExtra(call);
  final value =
      extra[callKitBusinessCallIdKey]?.toString().trim() ??
      call['call_id']?.toString().trim() ??
      call['callId']?.toString().trim();
  if (value == null || value.isEmpty) return null;
  return value;
}

String? extractCallKitNativeId(Object? rawValue) {
  final call = normalizeCallKitMap(rawValue);
  final value =
      call['id']?.toString().trim() ?? call['uuid']?.toString().trim();
  if (value == null || value.isEmpty) return null;
  return value;
}

bool isAppOwnedCallKitExtra(Object? rawValue) {
  final extra = normalizeCallKitMap(rawValue);
  final appSource = extra[callKitAppSourceKey]?.toString().trim();
  final businessCallId = extra[callKitBusinessCallIdKey]?.toString().trim();
  final direction = extra[callKitDirectionKey]?.toString().trim();

  return appSource == callKitAppSourceValue &&
      businessCallId != null &&
      businessCallId.isNotEmpty &&
      (direction == 'incoming' || direction == 'outgoing');
}

bool isAppOwnedCallKitCall(Object? rawValue) {
  final call = normalizeCallKitMap(rawValue);
  if (call.isEmpty) return false;
  final extra = extractCallKitExtra(call);
  return isAppOwnedCallKitExtra(extra) &&
      extractAppOwnedBusinessCallId(call) != null;
}

bool shouldHandleOwnedCallKitEvent(Object? rawValue) {
  final body = normalizeCallKitMap(rawValue);
  final extra = extractCallKitExtra(body);
  final callId =
      extra[callKitBusinessCallIdKey]?.toString().trim() ??
      body['call_id']?.toString().trim() ??
      body['callId']?.toString().trim() ??
      body['id']?.toString().trim() ??
      body['uuid']?.toString().trim();
  final callDirection =
      extra[callKitDirectionKey]?.toString().trim() ??
      body[callKitDirectionKey]?.toString().trim();

  return isAppOwnedCallKitExtra(extra) &&
      callId != null &&
      callId.isNotEmpty &&
      (callDirection == 'incoming' || callDirection == 'outgoing');
}

String resolveIncomingPushCallId(Map<String, dynamic> data) {
  return (data['call_id'] ?? data['callId'] ?? data['id'])?.toString() ??
      _uuid.v4();
}

/// Service wrapper cho flutter_callkit_incoming.
///
/// Hiển thị giao diện cuộc gọi native của iOS/Android khi nhận cuộc gọi
/// (kể cả khi app bị kill hoặc đang ở background).
class CallKitService {
  CallKitService();

  // Callbacks được gắn từ bên ngoài (CallNotifier / App)
  void Function(String callId)? onAccepted;
  void Function(String callId)? onDeclined;
  void Function(String callId)? onEnded;
  void Function(String callId)? onTimeout;

  StreamSubscription<CallEvent?>? _subscription;

  /// Khởi tạo listeners cho các sự kiện CallKit.
  /// Gọi một lần duy nhất khi app khởi động (sau khi authenticated).
  Future<void> setupListeners() async {
    if (kIsWeb) return;
    _subscription?.cancel();
    _subscription = FlutterCallkitIncoming.onEvent.listen(_onCallKitEvent);
  }

  /// Hiển thị giao diện cuộc gọi native.
  Future<void> showIncomingCall({
    required String callId,
    required String callerName,
    String? callerAvatar,
    bool isVideo = false,
    int duration = 45000, // ms — tự động hết hạn sau 45s
  }) async {
    if (kIsWeb) return;
    final nativeCallId = _ensureCallkitUuid(callId);
    final params = CallKitParams(
      id: nativeCallId,
      nameCaller: callerName,
      avatar: callerAvatar,
      handle: callerName,
      type: isVideo ? 1 : 0, // 0 = audio, 1 = video
      textAccept: 'Chấp nhận',
      textDecline: 'Từ chối',
      duration: duration,
      extra: buildAppOwnedCallKitExtra(
        callId: callId,
        nativeCallId: nativeCallId,
        callDirection: 'incoming',
      ),
      android: const AndroidParams(
        isCustomNotification: false,
        isShowLogo: false,
        ringtonePath: 'ringtone', // tên file trong res/raw/ringtone.mp3
        backgroundColor: '#1A1A2E',
        actionColor: '#4FC3F7',
        isShowFullLockedScreen: true,
        isShowCallID: false,
      ),
      ios: const IOSParams(
        iconName: 'AppIcon',
        handleType: 'generic',
        supportsVideo: true,
        maximumCallGroups: 1,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'voiceChat',
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 44100.0,
        audioSessionPreferredIOBufferDuration: 0.005,
        supportsDTMF: false,
        supportsHolding: false,
        supportsGrouping: false,
        supportsUngrouping: false,
        ringtonePath: 'ringtone.mp3', // file trong ios/Runner/ringtone.mp3
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  /// Hiển thị giao diện cuộc gọi đi (outgoing) trên native.
  Future<void> showOutgoingCall({
    required String callId,
    required String calleeName,
    String? calleeAvatar,
    bool isVideo = false,
  }) async {
    if (kIsWeb) return;
    final nativeCallId = _ensureCallkitUuid(callId);
    final params = CallKitParams(
      id: nativeCallId,
      nameCaller: calleeName,
      avatar: calleeAvatar,
      handle: calleeName,
      type: isVideo ? 1 : 0,
      extra: buildAppOwnedCallKitExtra(
        callId: callId,
        nativeCallId: nativeCallId,
        callDirection: 'outgoing',
      ),
    );

    await FlutterCallkitIncoming.startCall(params);
  }

  /// Ẩn/kết thúc giao diện cuộc gọi native.
  Future<void> endCall(String callId) async {
    if (kIsWeb) return;
    final activeCalls = await FlutterCallkitIncoming.activeCalls();
    String resolvedId = callId;

    for (final activeCall in activeCalls) {
      if (activeCall is! Map) continue;
      final call = Map<String, dynamic>.from(
        activeCall.map((key, value) => MapEntry(key.toString(), value)),
      );
      final activeNativeId = extractCallKitNativeId(call);
      final activeBusinessId = extractAppOwnedBusinessCallId(call);

      if (activeNativeId == callId || activeBusinessId == callId) {
        resolvedId = activeNativeId ?? callId;
        break;
      }
    }

    await FlutterCallkitIncoming.endCall(resolvedId);
  }

  /// Kết thúc tất cả cuộc gọi native.
  Future<void> endAllCalls() async {
    if (kIsWeb) return;
    await FlutterCallkitIncoming.endAllCalls();
  }

  /// Lấy danh sách cuộc gọi đang active trên CallKit.
  Future<List<dynamic>> getActiveCalls() async {
    if (kIsWeb) return const [];
    return await FlutterCallkitIncoming.activeCalls();
  }

  void _onCallKitEvent(CallEvent? event) {
    if (event == null) return;

    final body = normalizeCallKitMap(event.body);
    final extra = extractCallKitExtra(body);
    final callId =
        extra[callKitBusinessCallIdKey]?.toString() ??
        body['call_id']?.toString() ??
        body['callId']?.toString() ??
        body['id']?.toString() ??
        body['uuid']?.toString() ??
        '';
    final callDirection =
        extra[callKitDirectionKey]?.toString() ??
        body[callKitDirectionKey]?.toString() ??
        'unknown';
    final isOwnedEvent = shouldHandleOwnedCallKitEvent(body);

    debugPrint(
      '[CallKit] Event: ${event.event}, callId: $callId, direction: $callDirection',
    );

    if (!isOwnedEvent) {
      debugPrint(
        '[CallKit] Ignored foreign/native event: ${event.event}, body=$body',
      );
      return;
    }

    switch (event.event) {
      case Event.actionCallAccept:
        onAccepted?.call(callId);
        break;
      case Event.actionCallDecline:
        onDeclined?.call(callId);
        break;
      case Event.actionCallEnded:
        onEnded?.call(callId);
        break;
      case Event.actionCallTimeout:
        onTimeout?.call(callId);
        break;
      default:
        debugPrint('[CallKit] Unhandled event: ${event.event}');
        break;
    }
  }

  /// Giải phóng resources.
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}

/// Hiển thị CallKit incoming call từ FCM background message.
/// Hàm này là top-level, có thể gọi từ background isolate.
Future<void> showCallKitFromPushData(Map<String, dynamic> data) async {
  if (kIsWeb) return;
  final originalCallId = resolveIncomingPushCallId(data);
  final nativeCallId = _ensureCallkitUuid(
    data['uuid'] ?? data['id'] ?? data['call_id'] ?? data['callId'],
  );
  final callerName =
      data['caller_name'] ?? data['callerName'] ?? 'Cuộc gọi đến';
  final callerAvatar = data['caller_avatar'] ?? data['callerAvatar'];
  final callType = data['call_type'] ?? data['type'] ?? 'audio';
  final isVideo = callType == 'video';

  final params = CallKitParams(
    id: nativeCallId,
    nameCaller: callerName,
    avatar: callerAvatar,
    handle: callerName,
    type: isVideo ? 1 : 0,
    textAccept: 'Chấp nhận',
    textDecline: 'Từ chối',
    duration: 45000,
    extra: buildAppOwnedCallKitExtra(
      callId: originalCallId,
      nativeCallId: nativeCallId,
      callDirection: 'incoming',
      extra: Map<String, dynamic>.from(data),
    ),
    android: const AndroidParams(
      isCustomNotification: false,
      isShowLogo: false,
      ringtonePath: 'ringtone',
      backgroundColor: '#1A1A2E',
      actionColor: '#4FC3F7',
      isShowFullLockedScreen: true,
      isShowCallID: false,
    ),
    ios: const IOSParams(
      iconName: 'AppIcon',
      handleType: 'generic',
      supportsVideo: true,
      maximumCallGroups: 1,
      maximumCallsPerCallGroup: 1,
      ringtonePath: 'ringtone.mp3',
    ),
  );

  await FlutterCallkitIncoming.showCallkitIncoming(params);
}

final callKitServiceProvider = Provider<CallKitService>((ref) {
  final service = CallKitService();
  ref.onDispose(() => service.dispose());
  return service;
});
