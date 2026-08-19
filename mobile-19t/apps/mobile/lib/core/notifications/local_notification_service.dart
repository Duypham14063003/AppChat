import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const foregroundNotificationAndroidIcon = 'ic_notification';

final localNotificationServiceProvider = Provider<LocalNotificationService>((
  ref,
) {
  return LocalNotificationService();
});

class LocalNotificationService {
  static const _channelId = 'fcm_foreground_channel';
  static const _channelName = 'Foreground Notifications';
  static const _channelDescription = 'Notifications shown while app is open';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  Future<void>? _initializationFuture;
  int _notificationId = 1000;

  Future<void> initialize() async {
    if (_initialized) return;
    final initializationFuture = _initializationFuture;
    if (initializationFuture != null) {
      await initializationFuture;
      return;
    }

    final pendingInitialization = _initializeInternal();
    _initializationFuture = pendingInitialization;
    try {
      await pendingInitialization;
    } finally {
      if (!_initialized) {
        _initializationFuture = null;
      }
    }
  }

  Future<void> _initializeInternal() async {
    try {
      const androidSettings = AndroidInitializationSettings(
        foregroundNotificationAndroidIcon,
      );
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        defaultPresentAlert: true,
        defaultPresentBadge: true,
        defaultPresentSound: true,
        defaultPresentBanner: true,
        defaultPresentList: true,
      );
      const settings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );

      await _plugin.initialize(settings);

      final iosPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final macosPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      final iosGranted = await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      final macosGranted = await macosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );

      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final androidGranted = await androidPlugin
          ?.requestNotificationsPermission();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.max,
        ),
      );
      debugPrint(
        'Local notification permissions: Android=$androidGranted iOS=$iosGranted macOS=$macosGranted',
      );

      _initialized = true;
      _initializationFuture = null;
    } catch (error, stackTrace) {
      _reportError(
        action: 'initialize local notifications',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> showForegroundNotification({
    required String title,
    required String body,
  }) async {
    final sanitizedTitle = _sanitizeTitle(title);
    final sanitizedBody = _sanitizeBody(body);

    try {
      await initialize();
      await _plugin.show(
        _notificationId++,
        sanitizedTitle,
        sanitizedBody,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.max,
            priority: Priority.high,
            icon: foregroundNotificationAndroidIcon,
            playSound: true,
            enableVibration: true,
            channelShowBadge: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            presentBanner: true,
            presentList: true,
          ),
          macOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            presentBanner: true,
            presentList: true,
          ),
        ),
      );
      debugPrint('Local foreground notification shown: $sanitizedTitle');
    } catch (error, stackTrace) {
      _reportError(
        action: 'show foreground notification',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  String _sanitizeTitle(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return 'Thông báo mới';
    return trimmed;
  }

  String? _sanitizeBody(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;
    return trimmed;
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
        library: 'LocalNotificationService',
        context: ErrorDescription('while attempting to $action'),
      ),
    );
  }
}
