import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'browser_notification_service.dart';
import 'local_notification_service.dart';

final foregroundNotificationServiceProvider = Provider<
    ForegroundNotificationService>((ref) {
  final localNotifications = ref.read(localNotificationServiceProvider);
  final browserNotifications = BrowserNotificationService();
  if (kIsWeb) {
    return WebForegroundNotificationService(browserNotifications);
  }
  return NativeForegroundNotificationService(localNotifications);
});

abstract class ForegroundNotificationService {
  Future<void> initialize();

  Future<void> showForegroundNotification({
    required String title,
    required String body,
    String? tag,
  });
}

class NativeForegroundNotificationService implements ForegroundNotificationService {
  NativeForegroundNotificationService(this._localNotifications);

  final LocalNotificationService _localNotifications;

  @override
  Future<void> initialize() => _localNotifications.initialize();

  @override
  Future<void> showForegroundNotification({
    required String title,
    required String body,
    String? tag,
  }) {
    return _localNotifications.showForegroundNotification(
      title: title,
      body: body,
    );
  }
}

class WebForegroundNotificationService implements ForegroundNotificationService {
  WebForegroundNotificationService(this._browserNotifications);

  final BrowserNotificationService _browserNotifications;

  @override
  Future<void> initialize() => _browserNotifications.initialize();

  @override
  Future<void> showForegroundNotification({
    required String title,
    required String body,
    String? tag,
  }) async {
    await _browserNotifications.showNotification(
      title: title,
      body: body,
      tag: tag,
    );
  }
}
