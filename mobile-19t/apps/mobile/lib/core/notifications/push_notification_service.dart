import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nineteen_tech_app/core/notifications/foreground_notification_service.dart';
import 'package:nineteen_tech_app/features/call/services/callkit_service.dart';

import '../../features/auth/data/secure_token_storage.dart';
import '../../features/auth/providers/auth_notifier.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (message.data.isNotEmpty) {
    final type = message.data['type'];
    if (type == 'call_invite') {
      await showCallKitFromPushData(Map<String, dynamic>.from(message.data));
    } else if (type == 'call_ended' || type == 'call_rejected') {
      final callId = message.data['call_id'] ?? message.data['callId'];
      if (callId != null) {
        await FlutterCallkitIncoming.endCall(callId.toString());
      }
    }
  }
}

typedef ForegroundNotificationHandler =
    FutureOr<bool> Function(ForegroundNotificationRequest notification);

final pushNotificationServiceProvider = Provider<PushNotificationService>((
  ref,
) {
  final dio = ref.read(dioProvider);
  final storage = ref.read(secureTokenStorageProvider);
  final foregroundNotifications = ref.read(
    foregroundNotificationServiceProvider,
  );
  return PushNotificationService(dio, storage, foregroundNotifications);
});

class PushNotificationService {
  PushNotificationService(
    this._dio,
    this._storage,
    this._foregroundNotifications,
  );

  final Dio _dio;
  final SecureTokenStorage _storage;
  final ForegroundNotificationService _foregroundNotifications;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
  String? _initializedDeviceId;

  String? get initializedDeviceId => _initializedDeviceId;

  Future<void> initialize({
    required String deviceId,
    void Function(Map<String, dynamic> data)? onForegroundMessageData,
    ForegroundNotificationHandler? onForegroundNotification,
    required void Function(Map<String, dynamic> data) onNotificationTap,
  }) async {
    if (Firebase.apps.isEmpty) {
      debugPrint('Skipping FCM initialization because Firebase is not ready.');
      return;
    }

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    if (_initializedDeviceId != deviceId) {
      await reset();
      _initializedDeviceId = deviceId;
    } else if (_tokenRefreshSubscription != null &&
        _foregroundMessageSubscription != null &&
        _messageOpenedSubscription != null) {
      return;
    }

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('FCM permission: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint(
        'Skipping foreground notification setup because FCM permission is denied.',
      );
      return;
    }

    await _configureAppleForegroundPresentationOptions();
    await _foregroundNotifications.initialize();

    final token = await _messaging.getToken(
      vapidKey: kIsWeb
          ? 'BLf4lNGEbrgGAd3XcC6TMe28rsWlVQLqgUz5eS6jvNuL0HN6bFuJoJzjirZ-IVoomgriSQDs4rUwJE-48Jz_9SA'
          : null,
    );
    if (token != null) {
      await _sendTokenToServer(deviceId, token);
    }

    if (!kIsWeb && Platform.isIOS) {
      try {
        final voipToken = await FlutterCallkitIncoming.getDevicePushTokenVoIP();
        if (voipToken != null && voipToken.isNotEmpty) {
          await _sendVoipTokenToServer(deviceId, voipToken);
        }
      } catch (e) {
        debugPrint('Failed to get or send VoIP token: $e');
      }
    }

    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((newToken) {
      unawaited(_sendTokenToServer(deviceId, newToken));
    });

    _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen((
      message,
    ) {
      if (message.data.isNotEmpty) {
        onForegroundMessageData?.call(Map<String, dynamic>.from(message.data));
      }
      unawaited(
        _handleForegroundMessage(
          message,
          onForegroundNotification: onForegroundNotification,
        ),
      );
    });

    _messageOpenedSubscription = FirebaseMessaging.onMessageOpenedApp.listen((
      message,
    ) {
      if (message.data.isNotEmpty) {
        onNotificationTap(Map<String, dynamic>.from(message.data));
      }
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null && initialMessage.data.isNotEmpty) {
      onNotificationTap(Map<String, dynamic>.from(initialMessage.data));
    }
  }

  Future<String?> getCurrentToken({bool persist = true}) async {
    if (Firebase.apps.isEmpty) {
      debugPrint('Skipping FCM token read because Firebase is not ready.');
      return null;
    }

    final token = await _messaging.getToken(
      vapidKey: kIsWeb
          ? 'BLf4lNGEbrgGAd3XcC6TMe28rsWlVQLqgUz5eS6jvNuL0HN6bFuJoJzjirZ-IVoomgriSQDs4rUwJE-48Jz_9SA'
          : null,
    );
    debugPrint('FCM getToken result: ${token == null ? 'null' : 'ok'}');
    if (persist && token != null) {
      await _storage.saveFcmToken(token);
    }
    return token;
  }

  Future<String?> refreshCurrentToken() async {
    if (Firebase.apps.isEmpty) {
      debugPrint('Skipping FCM token refresh because Firebase is not ready.');
      return null;
    }

    await _messaging.deleteToken();
    debugPrint('FCM token deleted for refresh');
    return getCurrentToken();
  }

  Future<PushTokenUpdateResult> updateCurrentToken({
    required String deviceId,
    String? token,
  }) async {
    if (!kIsWeb && Platform.isIOS) {
      try {
        final voipToken = await FlutterCallkitIncoming.getDevicePushTokenVoIP();
        if (voipToken != null && voipToken.isNotEmpty) {
          unawaited(_sendVoipTokenToServer(deviceId, voipToken));
        }
      } catch (e) {
        debugPrint('Failed to get or send VoIP token in updateCurrentToken: $e');
      }
    }

    final fcmToken = token ?? await getCurrentToken();
    if (fcmToken == null || fcmToken.isEmpty) {
      const result = PushTokenUpdateResult(
        success: false,
        message: 'Không lấy được FCM token hiện tại',
      );
      debugPrint('FCM update failed: ${result.message}');
      return result;
    }

    return _sendTokenToServer(deviceId, fcmToken);
  }

  Future<PushTokenUpdateResult> _sendTokenToServer(
    String deviceId,
    String fcmToken,
  ) async {
    final accessToken = await _storage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      await _storage.saveFcmToken(fcmToken);
      debugPrint('Skipping FCM token update because user is not logged in.');
      return const PushTokenUpdateResult(
        success: false,
        message: 'Chưa đăng nhập, lưu token offline.',
      );
    }

    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/auth/sessions/fcm-token',
        data: {'device_id': deviceId, 'fcm_token': fcmToken},
      );
      await _storage.saveFcmToken(fcmToken);
      final message =
          response.data?['message'] as String? ?? 'FCM token updated';
      debugPrint('FCM update success: $message');
      return PushTokenUpdateResult(
        success: true,
        message: message,
        statusCode: response.statusCode,
      );
    } catch (e) {
      debugPrint('Failed to send FCM token: $e');
      return PushTokenUpdateResult(success: false, message: e.toString());
    }
  }

  Future<void> _sendVoipTokenToServer(
    String deviceId,
    String voipToken,
  ) async {
    final accessToken = await _storage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      await _storage.saveVoipToken(voipToken);
      debugPrint('Skipping VoIP token update because user is not logged in.');
      return;
    }

    try {
      await _dio.patch(
        '/auth/sessions/voip-token',
        data: {'device_id': deviceId, 'voip_token': voipToken},
      );
      await _storage.saveVoipToken(voipToken);
      debugPrint('VoIP token updated successfully');
    } catch (e) {
      debugPrint('Failed to send VoIP token: $e');
    }
  }

  Future<void> clearServerToken() async {
    final deviceId = await _storage.getDeviceId();
    if (deviceId == null || deviceId.isEmpty) {
      await _storage.clearFcmToken();
      await _storage.clearVoipToken();
      return;
    }

    final accessToken = await _storage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      await _storage.clearFcmToken();
      await _storage.clearVoipToken();
      return;
    }

    try {
      await _dio.patch(
        '/auth/sessions/fcm-token',
        data: {'device_id': deviceId, 'fcm_token': ''},
      );
    } catch (e) {
      debugPrint('Failed to clear FCM token: $e');
    }

    try {
      if (!kIsWeb && Platform.isIOS) {
        await _dio.patch(
          '/auth/sessions/voip-token',
          data: {'device_id': deviceId, 'voip_token': ''},
        );
      }
    } catch (e) {
      debugPrint('Failed to clear VoIP token: $e');
    } finally {
      await _storage.clearFcmToken();
      await _storage.clearVoipToken();
    }
  }

  Future<void> reset() async {
    await _tokenRefreshSubscription?.cancel();
    await _foregroundMessageSubscription?.cancel();
    await _messageOpenedSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _foregroundMessageSubscription = null;
    _messageOpenedSubscription = null;
    _initializedDeviceId = null;
  }

  Future<void> _handleForegroundMessage(
    RemoteMessage message, {
    ForegroundNotificationHandler? onForegroundNotification,
  }) async {
    try {
      final title =
          message.notification?.title ??
          (message.data['title'] as String?) ??
          'Thông báo mới';
      final body =
          message.notification?.body ?? (message.data['body'] as String?) ?? '';
      final request = ForegroundNotificationRequest(
        title: title,
        body: body,
        data: Map<String, dynamic>.from(message.data),
      );
      final shouldShow = await onForegroundNotification?.call(request) ?? true;
      if (!shouldShow) {
        debugPrint('Foreground FCM suppressed: $title');
        return;
      }
      debugPrint('Foreground FCM: $title');
      await _foregroundNotifications.showForegroundNotification(
        title: title,
        body: body,
        tag: _foregroundNotificationTag(message.data),
      );
    } catch (error, stackTrace) {
      _reportError(
        action: 'handle foreground FCM message',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _configureAppleForegroundPresentationOptions() async {
    if (kIsWeb) return;
    final platform = defaultTargetPlatform;
    final isApplePlatform =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    if (!isApplePlatform) return;

    try {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: true,
        sound: false,
      );
      debugPrint(
        'Configured Apple foreground notification presentation to use local banners.',
      );
    } catch (error, stackTrace) {
      _reportError(
        action: 'configure Apple foreground notification presentation',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  String? _foregroundNotificationTag(Map<String, dynamic> data) {
    for (final key in const ['id', 'message_id', 'reminder_id', 'leave_id']) {
      final value = data[key];
      if (value == null) continue;
      final normalized = value.toString().trim();
      if (normalized.isNotEmpty) return normalized;
    }
    return null;
  }

  void _reportError({
    required String action,
    required Object error,
    required StackTrace stackTrace,
  }) {
    debugPrint('Failed to $action: $error');
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'PushNotificationService',
        context: ErrorDescription('while attempting to $action'),
      ),
    );
  }
}

class PushTokenUpdateResult {
  const PushTokenUpdateResult({
    required this.success,
    required this.message,
    this.statusCode,
  });

  final bool success;
  final String message;
  final int? statusCode;
}

class ForegroundNotificationRequest {
  const ForegroundNotificationRequest({
    required this.title,
    required this.body,
    required this.data,
  });

  final String title;
  final String body;
  final Map<String, dynamic> data;
}
