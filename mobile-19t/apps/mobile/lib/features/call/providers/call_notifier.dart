import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:just_audio/just_audio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/call_model.dart';
import '../services/call_api_service.dart';
import '../services/agora_call_service.dart';
import '../services/callkit_service.dart';
import '../../../core/router/app_router.dart';
import '../../../core/database/app_database.dart';
import '../providers/agora_provider.dart';
import '../../auth/providers/auth_notifier.dart';
import '../../chat/providers/chat_providers.dart';

part 'call_notifier.g.dart';

bool shouldEndCancelledOutgoingCall({
  required CallStatus currentStatus,
  required bool callerHangupRequestedWhileStarting,
}) {
  return currentStatus != CallStatus.outgoing &&
      callerHangupRequestedWhileStarting;
}

bool shouldIgnoreIncomingCallPresentation({
  required Set<String> processedCallIds,
  required CallStatus status,
  required String? currentCallId,
  required String? incomingCallId,
}) {
  if (incomingCallId != null && processedCallIds.contains(incomingCallId)) {
    return true;
  }

  if (status != CallStatus.idle) {
    return true;
  }

  if (incomingCallId != null && incomingCallId == currentCallId) {
    return true;
  }

  return false;
}

bool shouldIgnoreNativeCallKitEndedEvent({
  required Set<String> locallyClosedCallIds,
  required CallStatus status,
  required String? currentCallId,
  required String endedCallId,
}) {
  return locallyClosedCallIds.contains(endedCallId) ||
      status != CallStatus.idle ||
      currentCallId != endedCallId;
}

Map<String, dynamic>? findOwnedCallKitCallForRestore({
  required List<dynamic> activeCalls,
  String? eventCallId,
}) {
  for (final rawCall in activeCalls) {
    if (!isAppOwnedCallKitCall(rawCall)) continue;

    final businessId = extractAppOwnedBusinessCallId(rawCall);
    final nativeId = extractCallKitNativeId(rawCall);

    if (eventCallId == null || eventCallId.isEmpty) {
      return normalizeCallKitMap(rawCall);
    }

    if (eventCallId == businessId || eventCallId == nativeId) {
      return normalizeCallKitMap(rawCall);
    }
  }

  return null;
}

@Riverpod(keepAlive: true)
class CallNotifier extends _$CallNotifier {
  static const Duration _outgoingAutoEndGuardWindow = Duration(seconds: 3);
  static const _callRoutes = <String>{
    '/call/incoming',
    '/call/outgoing',
    '/call/active',
  };
  late final CallApiService _api;
  Timer? _callTimeoutTimer;
  AudioPlayer? _ringbackPlayer;
  bool _isAccepting = false;
  bool _isRejecting = false;
  bool _isEnding = false;
  bool _isResetting = false;
  Timer? _busyTimer;
  final Set<String> _processedCallIds = {};
  final Set<String> _nativeTeardownCallIds = {};
  bool _callerHangupRequestedWhileStarting = false;
  DateTime? _outgoingStartedAt;

  void _logCallFlow(String message, {StackTrace? stackTrace}) {
    debugPrint('[CallNotifier] $message');
    if (stackTrace != null) {
      final lines = stackTrace.toString().trim().split('\n').take(8);
      for (final line in lines) {
        debugPrint('[CallNotifier][trace] $line');
      }
    }
  }

  @override
  CallModel build() {
    _api = ref.read(callApiServiceProvider);
    _setupAgoraListeners();
    _setupCallKitListeners();

    // Check if there is an active/accepted call when provider initializes
    Future.microtask(() => checkInitialCall());

    return CallModel();
  }

  void _updateState(CallModel newState) {
    debugPrint(
      '[CallNotifier] State changed: ${state.status} -> ${newState.status} | callId: ${state.callId} -> ${newState.callId}',
    );
    state = newState;
  }

  void _rememberProcessedCallId(String? callId) {
    if (callId == null || callId.isEmpty) return;
    _processedCallIds.add(callId);
    if (_processedCallIds.length > 100) {
      _processedCallIds.remove(_processedCallIds.first);
    }
  }

  void markCallAsProcessed(String? callId) {
    debugPrint('[CallNotifier] markCallAsProcessed: callId=$callId');
    _rememberProcessedCallId(callId);
  }

  void _rememberNativeTeardownCallId(String? callId) {
    if (callId == null || callId.isEmpty) return;
    _nativeTeardownCallIds.add(callId);
    if (_nativeTeardownCallIds.length > 100) {
      _nativeTeardownCallIds.remove(_nativeTeardownCallIds.first);
    }
  }

  bool _isWithinOutgoingAutoEndGuardWindow() {
    if (_outgoingStartedAt == null) return false;
    return DateTime.now().difference(_outgoingStartedAt!) <
        _outgoingAutoEndGuardWindow;
  }

  Future<void> _closeNativeCallUi(String? callId) async {
    if (callId == null || callId.isEmpty) return;

    _rememberNativeTeardownCallId(callId);
    try {
      await ref.read(callKitServiceProvider).endCall(callId);
    } catch (e) {
      debugPrint('[CallNotifier] _closeNativeCallUi error: $e');
    }
  }

  String? _currentRouteLocation() {
    return ref.read(routerProvider).routeInformationProvider.value.uri.path;
  }

  bool _isOnCallRoute() {
    final currentLocation = _currentRouteLocation();
    return currentLocation != null && _callRoutes.contains(currentLocation);
  }

  bool _isCurrentCall(String? callId) {
    if (callId == null || callId.isEmpty) return true;
    return state.callId == callId;
  }

  Map<String, dynamic> _normalizeDynamicMap(Object? rawValue) {
    if (rawValue is! Map) return const <String, dynamic>{};
    return Map<String, dynamic>.from(
      rawValue.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  String? _normalizedString(Object? rawValue) {
    final value = rawValue?.toString().trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  Future<void> _restoreIncomingStateFromNativeCall({
    required CallKitService callKit,
    required String eventCallId,
    required CallStatus status,
  }) async {
    final calls = await callKit.getActiveCalls();
    final matchedCall = findOwnedCallKitCallForRestore(
      activeCalls: calls,
      eventCallId: eventCallId,
    );
    if (matchedCall == null) {
      debugPrint(
        '[CallNotifier] _restoreIncomingStateFromNativeCall ignored: no app-owned native call for eventCallId=$eventCallId',
      );
      return;
    }

    final extra = _normalizeDynamicMap(matchedCall['extra']);
    final resolvedCallId =
        extra['callId']?.toString() ??
        matchedCall['call_id']?.toString() ??
        matchedCall['callId']?.toString() ??
        matchedCall['id']?.toString() ??
        eventCallId;
    final resolvedCallerId =
        _normalizedString(extra['caller_id']) ??
        _normalizedString(extra['callerId']) ??
        state.otherUserId;
    final resolvedCallerName =
        _normalizedString(extra['caller_name']) ??
        _normalizedString(extra['callerName']) ??
        _normalizedString(matchedCall['nameCaller']) ??
        state.otherUserName ??
        'Người gọi';
    final resolvedCallerAvatar =
        _normalizedString(extra['caller_avatar']) ??
        _normalizedString(extra['callerAvatar']) ??
        _normalizedString(matchedCall['avatar']) ??
        state.otherUserAvatar;
    final resolvedConversationId =
        _normalizedString(extra['conversation_id']) ??
        _normalizedString(extra['conversationId']) ??
        state.conversationId;
    final isVideo =
        matchedCall['type'] == 1 ||
        extra['call_type'] == 'video' ||
        extra['type'] == 'video' ||
        extra['isVideo'] == true ||
        state.isVideo;

    _updateState(
      CallModel(
        callId: resolvedCallId,
        otherUserId: resolvedCallerId,
        otherUserName: resolvedCallerName,
        otherUserAvatar: resolvedCallerAvatar,
        isVideo: isVideo,
        conversationId: resolvedConversationId,
        status: status,
      ),
    );
  }

  /// Đồng bộ cuộc gọi đến đang chờ từ backend.
  ///
  /// Gọi khi WS (re)connect hoặc app resume để bắt lại cuộc gọi `ringing`
  /// trong trường hợp sự kiện `incoming_call` qua WS bị mất do socket
  /// rớt/zombie. `handleIncomingCall` đã có sẵn guard chống hiển thị trùng.
  Future<void> syncPendingIncomingCall() async {
    if (state.status != CallStatus.idle) {
      debugPrint(
        '[CallNotifier] syncPendingIncomingCall skipped: status=${state.status}',
      );
      return;
    }
    try {
      final pending = await _api.getActiveIncomingCall();
      if (pending == null) return;

      final callId = pending['call_id'] ?? pending['callId'] ?? pending['id'];
      if (callId != null && _processedCallIds.contains(callId.toString())) {
        debugPrint(
          '[CallNotifier] syncPendingIncomingCall: callId=$callId already processed, skipping',
        );
        return;
      }

      debugPrint(
        '[CallNotifier] syncPendingIncomingCall: found pending call $callId, presenting',
      );
      await handleIncomingCall(Map<String, dynamic>.from(pending));
    } catch (e) {
      debugPrint('[CallNotifier] syncPendingIncomingCall error: $e');
    }
  }

  Future<void> checkInitialCall() async {
    try {
      if (_isAccepting) {
        debugPrint(
          '[CallNotifier] checkInitialCall skipped: accept is already in progress',
        );
        return;
      }
      final storage = ref.read(secureTokenStorageProvider);
      final hasToken = await storage.getAccessToken() != null;
      if (!hasToken) {
        debugPrint(
          '[CallNotifier] checkInitialCall skipped: User is not logged in',
        );
        return;
      }

      final callKit = ref.read(callKitServiceProvider);
      final calls = await callKit.getActiveCalls();
      final call = findOwnedCallKitCallForRestore(activeCalls: calls);
      if (call != null) {
        final callId =
            extractAppOwnedBusinessCallId(call) ?? extractCallKitNativeId(call);
        final isAccepted = call['isAccepted'] as bool? ?? false;

        debugPrint(
          '[CallNotifier] checkInitialCall: Found active call $callId, accepted=$isAccepted',
        );

        if (state.callId == callId &&
            (isAccepted
                ? state.status == CallStatus.active
                : state.status == CallStatus.incoming)) {
          return;
        }

        if (callId != null) {
          final extra = _normalizeDynamicMap(call['extra']);
          final isVideo =
              call['type'] == 1 ||
              extra['call_type'] == 'video' ||
              extra['type'] == 'video' ||
              extra['isVideo'] == true;
          final resolvedCallerId =
              _normalizedString(extra['caller_id']) ??
              _normalizedString(extra['callerId']) ??
              state.otherUserId;
          final resolvedCallerName =
              _normalizedString(extra['caller_name']) ??
              _normalizedString(extra['callerName']) ??
              _normalizedString(call['nameCaller']) ??
              state.otherUserName ??
              'Người gọi';
          final resolvedCallerAvatar =
              _normalizedString(extra['caller_avatar']) ??
              _normalizedString(extra['callerAvatar']) ??
              _normalizedString(call['avatar']) ??
              state.otherUserAvatar;
          final resolvedConversationId =
              _normalizedString(extra['conversation_id']) ??
              _normalizedString(extra['conversationId']) ??
              state.conversationId;

          _updateState(
            CallModel(
              callId: callId,
              otherUserId: resolvedCallerId,
              otherUserName: resolvedCallerName,
              otherUserAvatar: resolvedCallerAvatar,
              isVideo: isVideo,
              conversationId: resolvedConversationId,
              status: isAccepted ? CallStatus.active : CallStatus.incoming,
            ),
          );

          if (isAccepted) {
            ref.read(routerProvider).go('/call/active');
          } else {
            if (!_isAccepting &&
                state.callId == callId &&
                state.status == CallStatus.incoming) {
              ref.read(routerProvider).go('/call/incoming');
            }
          }
        }
      } else if (calls.isNotEmpty) {
        debugPrint(
          '[CallNotifier] checkInitialCall ignored ${calls.length} foreign/native active call(s); backend reconcile remains fallback',
        );
      }
    } catch (e) {
      debugPrint('[CallNotifier] Error checking initial call: $e');
    }
  }

  void _setupAgoraListeners() {
    final agora = ref.read(agoraCallServiceProvider);
    agora.onUserJoined = (uid) {
      debugPrint('[CallNotifier] Remote user joined: $uid');
      _updateState(state.copyWith(remoteUid: uid, status: CallStatus.active));
    };

    agora.onUserOffline = (uid) {
      debugPrint('[CallNotifier] Remote user offline: $uid');
      if (state.remoteUid == uid) {
        unawaited(handleCallEnded());
      }
    };

    agora.onLeaveChannel = () {
      debugPrint(
        '[CallNotifier] Local left channel (observed). Reset is handled by explicit end/reject/ended flows.',
      );
    };
  }

  void _setupCallKitListeners() {
    final callKit = ref.read(callKitServiceProvider);
    callKit.setupListeners();

    callKit.onAccepted = (callId) async {
      debugPrint('[CallNotifier] CallKit onAccepted event: $callId');

      if (state.callId != callId || state.status == CallStatus.idle) {
        await _restoreIncomingStateFromNativeCall(
          callKit: callKit,
          eventCallId: callId,
          status: CallStatus.incoming,
        );
      }

      await acceptCall();
    };

    callKit.onDeclined = (callId) async {
      debugPrint('[CallNotifier] CallKit onDeclined event: $callId');
      if (_isAccepting) {
        debugPrint(
          '[CallNotifier] CallKit onDeclined IGNORED: accept already in progress for callId=$callId',
        );
        return;
      }
      if (state.callId != callId || state.status == CallStatus.idle) {
        await _restoreIncomingStateFromNativeCall(
          callKit: callKit,
          eventCallId: callId,
          status: CallStatus.incoming,
        );
      }
      await rejectCall();
    };

    callKit.onEnded = (callId) async {
      if (_isAccepting) {
        debugPrint(
          '[CallNotifier] CallKit onEnded IGNORED: accept already in progress for callId=$callId',
        );
        return;
      }
      _logCallFlow(
        'CallKit onEnded event: callId=$callId, state.callId=${state.callId}, status=${state.status}, pendingHangup=$_callerHangupRequestedWhileStarting',
      );
      if (shouldIgnoreNativeCallKitEndedEvent(
            locallyClosedCallIds: _nativeTeardownCallIds,
            status: state.status,
            currentCallId: state.callId,
            endedCallId: callId,
          ) &&
          _nativeTeardownCallIds.remove(callId)) {
        debugPrint(
          '[CallNotifier] CallKit onEnded treated as local native teardown for callId=$callId',
        );
        return;
      }
      if (shouldIgnoreNativeCallKitEndedEvent(
            locallyClosedCallIds: _nativeTeardownCallIds,
            status: state.status,
            currentCallId: state.callId,
            endedCallId: callId,
          ) &&
          state.status == CallStatus.idle &&
          state.callId != callId) {
        debugPrint(
          '[CallNotifier] CallKit onEnded IGNORED: idle and unrelated callId=$callId',
        );
        _rememberProcessedCallId(callId);
        return;
      }
      debugPrint(
        '[CallNotifier] CallKit onEnded treated as observational native event for callId=$callId, status=${state.status}',
      );
    };

    callKit.onTimeout = (callId) async {
      debugPrint('[CallNotifier] CallKit onTimeout event: $callId');
      if (state.callId != callId) {
        _updateState(state.copyWith(callId: callId));
      }
      await rejectCall();
    };
  }

  Future<void> _startTimeoutAndRingtone({required bool isIncoming}) async {
    debugPrint(
      '[CallNotifier] _startTimeoutAndRingtone: isIncoming=$isIncoming, callId=${state.callId}',
    );
    _callTimeoutTimer?.cancel();
    _callTimeoutTimer = Timer(const Duration(seconds: 45), () {
      debugPrint('[CallNotifier] Call timeout reached (45s)');
      if (state.status == CallStatus.incoming) {
        rejectCall();
      } else if (state.status == CallStatus.outgoing) {
        endCall(userInitiated: true, source: 'outgoing_timeout');
      }
    });

    if (isIncoming) {
      // Người nhận: CallKit sẽ tự đổ chuông native
    } else {
      try {
        _ringbackPlayer?.dispose();
        _ringbackPlayer = AudioPlayer();
        await _ringbackPlayer?.setAsset('assets/audio/ringback.mp3');
        await _ringbackPlayer?.setLoopMode(LoopMode.one);
        await _ringbackPlayer?.play();
      } catch (e) {
        debugPrint('[CallNotifier] Error playing ringback tone: $e');
        if (!kIsWeb) {
          FlutterRingtonePlayer().play(
            android: AndroidSounds.ringtone,
            ios: IosSounds.electronic,
            looping: true,
            volume: 0.5,
          );
        }
      }
    }
  }

  void _cancelTimeoutAndRingtone() {
    debugPrint('[CallNotifier] _cancelTimeoutAndRingtone');
    _callTimeoutTimer?.cancel();
    _callTimeoutTimer = null;
    _busyTimer?.cancel();
    _busyTimer = null;
    if (!kIsWeb) {
      FlutterRingtonePlayer().stop();
    }
    _ringbackPlayer?.stop();
    _ringbackPlayer?.dispose();
    _ringbackPlayer = null;
  }

  AgoraCallService get _agora => ref.read(agoraCallServiceProvider);

  Future<bool> _requestPermissions({required bool isVideo}) async {
    debugPrint('[CallNotifier] _requestPermissions: isVideo=$isVideo');

    final micStatus = await Permission.microphone.status;
    final camStatus = isVideo
        ? await Permission.camera.status
        : PermissionStatus.granted;

    if (micStatus == PermissionStatus.granted &&
        camStatus == PermissionStatus.granted) {
      debugPrint(
        '[CallNotifier] Permissions already granted, skipping request dialog',
      );
      return true;
    }

    final micRequest = micStatus != PermissionStatus.granted
        ? await Permission.microphone.request()
        : PermissionStatus.granted;

    final camRequest = (isVideo && camStatus != PermissionStatus.granted)
        ? await Permission.camera.request()
        : PermissionStatus.granted;

    if (micRequest != PermissionStatus.granted) {
      debugPrint('[CallNotifier] microphone permission denied');
      return false;
    }
    if (isVideo && camRequest != PermissionStatus.granted) {
      debugPrint('[CallNotifier] camera permission denied');
      return false;
    }
    return true;
  }

  Future<void> startCall({
    required String receiverId,
    required String receiverName,
    String? receiverAvatar,
    required String conversationId,
    required bool isVideo,
  }) async {
    debugPrint(
      '[CallNotifier] startCall: receiverId=$receiverId, receiverName=$receiverName, conversationId=$conversationId, isVideo=$isVideo, currentStatus=${state.status}',
    );
    if (state.status != CallStatus.idle) {
      debugPrint(
        '[CallNotifier] startCall: Already in a call (status=${state.status}), redirecting to call screen',
      );
      final router = ref.read(routerProvider);
      if (state.status == CallStatus.active) {
        router.push('/call/active');
      } else if (state.status == CallStatus.outgoing) {
        router.push('/call/outgoing');
      } else if (state.status == CallStatus.incoming) {
        router.push('/call/incoming');
      }
      return;
    }

    final hasPermission = await _requestPermissions(isVideo: isVideo);
    if (!hasPermission) {
      debugPrint('[CallNotifier] startCall: Missing permissions');
      throw Exception(
        'Vui lòng cấp quyền Microphone${isVideo ? ' và Camera' : ''} để thực hiện cuộc gọi',
      );
    }

    _updateState(
      CallModel(
        otherUserId: receiverId,
        otherUserName: receiverName,
        otherUserAvatar: receiverAvatar,
        conversationId: conversationId,
        isVideo: isVideo,
        status: CallStatus.outgoing,
      ),
    );
    _outgoingStartedAt = DateTime.now();

    // Chuyển sang màn hình Outgoing ngay lập tức để có phản hồi UI nhanh
    ref.read(routerProvider).push('/call/outgoing');
    unawaited(_startTimeoutAndRingtone(isIncoming: false));

    try {
      _logCallFlow(
        'startCall API request: receiverId=$receiverId, conversationId=$conversationId, isVideo=$isVideo',
      );
      final callData = await _api.startCall(
        receiverId: receiverId,
        conversationId: conversationId,
        isVideo: isVideo,
      );

      final callId = callData['id'];
      debugPrint(
        '[CallNotifier] startCall API response: callId=$callId, status=${callData['status']}',
      );

      if (state.status != CallStatus.outgoing) {
        debugPrint(
          '[CallNotifier] startCall: User already cancelled the call (currentStatus=${state.status}). Cleaning up callId=$callId on backend.',
        );
        if (callId != null &&
            shouldEndCancelledOutgoingCall(
              currentStatus: state.status,
              callerHangupRequestedWhileStarting:
                  _callerHangupRequestedWhileStarting,
            )) {
          try {
            await _api.endCall(callId);
          } catch (e) {
            debugPrint('[CallNotifier] Error cleaning up cancelled call: $e');
          }
        }
        _callerHangupRequestedWhileStarting = false;
        return;
      }

      if (callData['status'] == 'busy' || callData['busy'] == true) {
        debugPrint('[CallNotifier] startCall: Receiver is busy');
        _callerHangupRequestedWhileStarting = false;
        _outgoingStartedAt = null;
        _updateState(state.copyWith(status: CallStatus.busy));
        _cancelTimeoutAndRingtone();
        _busyTimer = Timer(const Duration(seconds: 3), () {
          debugPrint('[CallNotifier] Busy timer fired after 3s');
          _resetCall();
        });
        return;
      }

      _callerHangupRequestedWhileStarting = false;
      _updateState(state.copyWith(callId: callId));
      _logCallFlow(
        'startCall success: callId=$callId, skipping native outgoing CallKit and keeping app-managed outgoing UI only',
      );
    } catch (e) {
      debugPrint('[CallNotifier] startCall error: $e');
      _callerHangupRequestedWhileStarting = false;
      _outgoingStartedAt = null;
      _cancelTimeoutAndRingtone();
      _resetCall();
      rethrow;
    }
  }

  Future<void> handleIncomingCall(Map<String, dynamic> data) async {
    final String? callId = data['call_id'] ?? data['callId'] ?? data['id'];
    debugPrint(
      '[CallNotifier] handleIncomingCall: incomingCallId=$callId, currentCallId=${state.callId}, status=${state.status}',
    );

    // GUARD 0: Nếu cuộc gọi đã được xử lý xong → bỏ qua hoàn toàn
    if (shouldIgnoreIncomingCallPresentation(
      processedCallIds: _processedCallIds,
      status: state.status,
      currentCallId: state.callId,
      incomingCallId: callId,
    )) {
      debugPrint(
        '[CallNotifier] handleIncomingCall IGNORED: status=${state.status}, currentCallId=${state.callId}, incomingCallId=$callId',
      );
      return;
    }

    String callerName =
        data['caller_name'] ?? data['callerName'] ?? 'Người gọi';
    String? callerAvatar = data['caller_avatar'] ?? data['callerAvatar'];
    final String? convId = data['conversation_id'] ?? data['conversationId'];
    final String? callerId = data['caller_id'] ?? data['callerId'];

    if (callerName == 'Người gọi') {
      // 1. Cố gắng lấy từ conversation_id nếu có
      if (convId != null) {
        final dao = ref.read(chatDaoProvider);
        final conv = await dao.getConversation(convId);
        if (conv != null) {
          if (conv.type == 'DIRECT') {
            callerName = conv.otherMemberName ?? conv.name ?? 'Người gọi';
            callerAvatar = conv.otherMemberAvatar ?? conv.avatarUrl;
          } else {
            callerName = conv.name ?? 'Người gọi';
            callerAvatar = conv.avatarUrl;
          }
        }
      }

      // 2. Nếu vẫn chưa có tên (ví dụ socket không gửi kèm convId), thử tìm trong tất cả local conversations
      if (callerName == 'Người gọi' && callerId != null) {
        final dao = ref.read(chatDaoProvider);
        final allConvs = await dao.getConversations();
        try {
          // Thử tìm conversation DIRECT nào có otherMemberAvatar hoặc name khớp với avatar/thông tin
          // Hoặc có thể sử dụng UserRepository nếu cần, nhưng ta thử quét Local trước:
          final matchedConv = allConvs.firstWhere(
            (c) =>
                c.type == 'DIRECT' &&
                (c.id.contains(callerId) || c.lastMessageSenderId == callerId),
          );
          callerName =
              matchedConv.otherMemberName ?? matchedConv.name ?? 'Người gọi';
          callerAvatar ??=
              matchedConv.otherMemberAvatar ?? matchedConv.avatarUrl;
        } catch (_) {}
      }
    }

    // Mapping key từ snake_case hoặc CamelCase của Backend sang CamelCase của Model
    _updateState(
      CallModel(
        callId: callId,
        otherUserId: callerId,
        otherUserName: callerName,
        otherUserAvatar: callerAvatar,
        conversationId: convId,
        isVideo: data['type'] == 'video',
        status: CallStatus.incoming,
      ),
    );

    final lifecycleState = ref.read(appLifecycleStateProvider);
    final shouldShowNativeIncomingUi = !isInteractiveForegroundAppState(
      lifecycleState,
    );

    if (callId != null && shouldShowNativeIncomingUi) {
      ref
          .read(callKitServiceProvider)
          .showIncomingCall(
            callId: callId,
            callerName: callerName,
            callerAvatar: callerAvatar,
            isVideo: data['type'] == 'video',
          );
    } else if (callId != null) {
      debugPrint(
        '[CallNotifier] handleIncomingCall: skipping native CallKit UI because app is in foreground (state=$lifecycleState)',
      );
    }

    await _startTimeoutAndRingtone(isIncoming: true);
    if (_isAccepting ||
        state.callId != callId ||
        state.status != CallStatus.incoming) {
      debugPrint(
        '[CallNotifier] handleIncomingCall route skipped: accepting=$_isAccepting, state.callId=${state.callId}, expectedCallId=$callId, status=${state.status}',
      );
      return;
    }
    ref.read(routerProvider).go('/call/incoming');
  }

  Future<void> handleCallAccepted([String? eventCallId]) async {
    debugPrint(
      '[CallNotifier] handleCallAccepted: eventCallId=$eventCallId, callId=${state.callId}, status=${state.status}',
    );
    if (!_isCurrentCall(eventCallId)) {
      debugPrint(
        '[CallNotifier] handleCallAccepted IGNORED: unrelated callId=$eventCallId, currentCallId=${state.callId}',
      );
      return;
    }
    if (state.status == CallStatus.active) {
      debugPrint('[CallNotifier] handleCallAccepted IGNORED: already active');
      return;
    }
    if (_isResetting || state.status == CallStatus.idle) {
      debugPrint(
        '[CallNotifier] handleCallAccepted IGNORED: resetting or idle',
      );
      return;
    }
    _cancelTimeoutAndRingtone();
    await _closeNativeCallUi(state.callId);
    if (state.callId == null) return;

    try {
      final tokenData = await _api.getAgoraToken(state.callId!);

      await _agora.init(tokenData['appId']);
      await _agora.joinChannel(
        token: tokenData['token'],
        channelId: tokenData['channelName'],
        uid: tokenData['uid'] ?? 0,
        isVideo: state.isVideo,
      );

      _updateState(
        state.copyWith(
          status: CallStatus.active,
          agoraToken: tokenData['token'],
          agoraAppId: tokenData['appId'],
          channelName: tokenData['channelName'],
          agoraUid: tokenData['uid'],
        ),
      );
      ref.read(routerProvider).go('/call/active');
    } catch (e) {
      debugPrint('[CallNotifier] Accept Error (Caller): $e');
      _resetCall();
    }
  }

  Future<void> handleCallRejected([String? eventCallId]) async {
    debugPrint(
      '[CallNotifier] handleCallRejected: eventCallId=$eventCallId, callId=${state.callId}, status=${state.status}',
    );
    if (!_isCurrentCall(eventCallId)) {
      debugPrint(
        '[CallNotifier] handleCallRejected IGNORED: unrelated callId=$eventCallId, currentCallId=${state.callId}',
      );
      return;
    }
    if (state.status == CallStatus.active) {
      debugPrint(
        '[CallNotifier] handleCallRejected IGNORED: call already active',
      );
      return;
    }
    _rememberProcessedCallId(state.callId);
    _callerHangupRequestedWhileStarting = false;
    if (_isResetting || state.status == CallStatus.idle) {
      debugPrint(
        '[CallNotifier] handleCallRejected IGNORED: resetting or idle',
      );
      return;
    }
    _cancelTimeoutAndRingtone();
    await _closeNativeCallUi(state.callId);
    _resetCall();
  }

  Future<void> handleCallEnded([String? eventCallId]) async {
    debugPrint(
      '[CallNotifier] handleCallEnded: eventCallId=$eventCallId, callId=${state.callId}, status=${state.status}',
    );
    if (!_isCurrentCall(eventCallId)) {
      debugPrint(
        '[CallNotifier] handleCallEnded IGNORED: unrelated callId=$eventCallId, currentCallId=${state.callId}',
      );
      return;
    }
    _rememberProcessedCallId(state.callId);
    _callerHangupRequestedWhileStarting = false;
    if (_isResetting || state.status == CallStatus.idle) {
      debugPrint('[CallNotifier] handleCallEnded IGNORED: resetting or idle');
      return;
    }
    _cancelTimeoutAndRingtone();
    await _closeNativeCallUi(state.callId);
    await _agora.leaveChannel();
    _resetCall();
  }

  Future<void> acceptCall() async {
    debugPrint(
      '[CallNotifier] acceptCall: callId=${state.callId}, status=${state.status}',
    );
    if (_isAccepting) {
      debugPrint(
        '[CallNotifier] acceptCall already in progress, ignoring duplicate call',
      );
      return;
    }
    _isAccepting = true;
    _cancelTimeoutAndRingtone();

    if (state.callId == null) {
      _isAccepting = false;
      return;
    }

    final hasPermission = await _requestPermissions(isVideo: state.isVideo);
    if (!hasPermission) {
      debugPrint(
        '[CallNotifier] acceptCall: Missing permissions, rejecting call',
      );
      _isAccepting = false;
      rejectCall();
      return;
    }

    try {
      await _api.acceptCall(state.callId!);
      _updateState(state.copyWith(status: CallStatus.active));
      ref.read(routerProvider).go('/call/active');
      await ref.read(callKitServiceProvider).endAllCalls();

      final tokenData = await _api.getAgoraToken(state.callId!);

      await _agora.init(tokenData['appId']);
      await _agora.joinChannel(
        token: tokenData['token'],
        channelId: tokenData['channelName'],
        uid: tokenData['uid'] ?? 0,
        isVideo: state.isVideo,
      );

      _updateState(
        state.copyWith(
          agoraToken: tokenData['token'],
          agoraAppId: tokenData['appId'],
          channelName: tokenData['channelName'],
          agoraUid: tokenData['uid'],
        ),
      );
    } catch (e) {
      debugPrint('[CallNotifier] Accept Error: $e');
      _resetCall();
    } finally {
      _isAccepting = false;
    }
  }

  Future<void> rejectCall() async {
    debugPrint(
      '[CallNotifier] rejectCall: callId=${state.callId}, status=${state.status}',
    );
    if (_isRejecting) {
      debugPrint('[CallNotifier] rejectCall IGNORED: already rejecting');
      return;
    }
    if (state.status == CallStatus.active) {
      debugPrint(
        '[CallNotifier] rejectCall IGNORED: call already active, refusing to send reject',
      );
      return;
    }
    if (_isResetting || state.status == CallStatus.idle) {
      debugPrint('[CallNotifier] rejectCall IGNORED: resetting or idle');
      return;
    }
    _callerHangupRequestedWhileStarting = false;
    _isRejecting = true;
    try {
      _cancelTimeoutAndRingtone();
      if (state.callId != null) {
        try {
          await _api.rejectCall(state.callId!);
        } catch (e) {
          debugPrint('[CallNotifier] rejectCall API error: $e');
        }
      }
      await ref.read(callKitServiceProvider).endAllCalls();
      _resetCall();
    } finally {
      _isRejecting = false;
    }
  }

  Future<void> endCall({
    bool userInitiated = false,
    String source = 'unknown',
  }) async {
    _logCallFlow(
      'endCall requested: callId=${state.callId}, status=${state.status}, userInitiated=$userInitiated, source=$source, pendingHangup=$_callerHangupRequestedWhileStarting',
      stackTrace: StackTrace.current,
    );
    if (_isEnding) {
      debugPrint('[CallNotifier] endCall IGNORED: already ending');
      return;
    }
    if (_isResetting || state.status == CallStatus.idle) {
      debugPrint('[CallNotifier] endCall IGNORED: resetting or idle');
      return;
    }
    if (state.status == CallStatus.outgoing &&
        !userInitiated &&
        _isWithinOutgoingAutoEndGuardWindow()) {
      _logCallFlow(
        'endCall BLOCKED: within outgoing auto-end guard window (${_outgoingAutoEndGuardWindow.inSeconds}s) without explicit user intent',
        stackTrace: StackTrace.current,
      );
      return;
    }
    if (state.status == CallStatus.outgoing && !userInitiated) {
      _logCallFlow(
        'endCall BLOCKED: refusing to end outgoing call without explicit user intent',
        stackTrace: StackTrace.current,
      );
      return;
    }
    if (state.status == CallStatus.outgoing) {
      _callerHangupRequestedWhileStarting = true;
    }
    final activeCallId = state.callId;
    final shouldKeepPendingHangup =
        activeCallId == null && state.status == CallStatus.outgoing;
    _isEnding = true;
    try {
      _cancelTimeoutAndRingtone();
      if (activeCallId != null) {
        try {
          await _api.endCall(activeCallId);
        } catch (e) {
          debugPrint('[CallNotifier] endCall API error: $e');
        }
      }
      await _closeNativeCallUi(activeCallId);
      await _agora.leaveChannel();
      _resetCall();
    } finally {
      if (!shouldKeepPendingHangup) {
        _callerHangupRequestedWhileStarting = false;
      }
      if (state.status != CallStatus.outgoing || userInitiated) {
        _outgoingStartedAt = null;
      }
      _isEnding = false;
    }
  }

  void _resetCall() {
    debugPrint(
      '[CallNotifier] _resetCall: callId=${state.callId}, status=${state.status}',
    );
    _rememberProcessedCallId(state.callId);
    if (_isResetting) {
      debugPrint('[CallNotifier] _resetCall IGNORED: already resetting');
      return;
    }
    _isResetting = true;
    try {
      _cancelTimeoutAndRingtone();
      _outgoingStartedAt = null;
      final router = ref.read(routerProvider);
      final currentLocation = _currentRouteLocation();
      _updateState(CallModel());
      if (_isOnCallRoute() || currentLocation != '/chat') {
        router.go('/chat');
      }
    } finally {
      _isResetting = false;
    }
  }

  void setCallStatus(CallStatus status) {
    debugPrint('[CallNotifier] setCallStatus: status=$status');
    _updateState(state.copyWith(status: status));
  }

  void handleCallBusy([String? eventCallId]) {
    debugPrint(
      '[CallNotifier] handleCallBusy: eventCallId=$eventCallId, callId=${state.callId}, status=${state.status}',
    );
    if (!_isCurrentCall(eventCallId)) {
      debugPrint(
        '[CallNotifier] handleCallBusy IGNORED: unrelated callId=$eventCallId, currentCallId=${state.callId}',
      );
      return;
    }
    if (_isResetting || state.status == CallStatus.idle) {
      debugPrint('[CallNotifier] handleCallBusy IGNORED: resetting or idle');
      return;
    }
    _rememberProcessedCallId(state.callId);
    _callerHangupRequestedWhileStarting = false;
    _cancelTimeoutAndRingtone();
    _closeNativeCallUi(state.callId).whenComplete(() {
      _updateState(state.copyWith(status: CallStatus.busy));
      _busyTimer = Timer(const Duration(seconds: 3), () {
        debugPrint('[CallNotifier] Busy timer fired (handleCallBusy) after 3s');
        _resetCall();
      });
    });
  }
}
