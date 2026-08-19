import 'browser_notification_service_common.dart';

class BrowserNotificationService {
  Future<void> initialize() async {}

  Future<BrowserNotificationPermissionState> permissionState() async {
    return BrowserNotificationPermissionState.unsupported;
  }

  Future<BrowserNotificationPermissionState> requestPermissionIfNeeded() async {
    return BrowserNotificationPermissionState.unsupported;
  }

  Future<bool> showNotification({
    required String title,
    String? body,
    String? tag,
  }) async {
    return false;
  }
}
