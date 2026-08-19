import 'package:flutter_test/flutter_test.dart';
import 'package:nineteen_tech_app/core/notifications/browser_notification_service_common.dart';

void main() {
  group('browserNotificationPermissionFromRaw', () {
    test('maps granted permission', () {
      expect(
        browserNotificationPermissionFromRaw('granted'),
        BrowserNotificationPermissionState.granted,
      );
    });

    test('maps denied permission', () {
      expect(
        browserNotificationPermissionFromRaw('denied'),
        BrowserNotificationPermissionState.denied,
      );
    });

    test('maps default permission', () {
      expect(
        browserNotificationPermissionFromRaw('default'),
        BrowserNotificationPermissionState.defaultPrompt,
      );
    });

    test('maps unsupported or unknown permission', () {
      expect(
        browserNotificationPermissionFromRaw(''),
        BrowserNotificationPermissionState.unsupported,
      );
      expect(
        browserNotificationPermissionFromRaw('unsupported'),
        BrowserNotificationPermissionState.unsupported,
      );
    });
  });

  group('browser permission decisions', () {
    test('requests permission only from default state', () {
      expect(
        shouldRequestBrowserNotificationPermission(
          BrowserNotificationPermissionState.defaultPrompt,
        ),
        isTrue,
      );
      expect(
        shouldRequestBrowserNotificationPermission(
          BrowserNotificationPermissionState.granted,
        ),
        isFalse,
      );
      expect(
        shouldRequestBrowserNotificationPermission(
          BrowserNotificationPermissionState.denied,
        ),
        isFalse,
      );
    });

    test('allows display only for granted permission', () {
      expect(
        canDisplayBrowserNotification(
          BrowserNotificationPermissionState.granted,
        ),
        isTrue,
      );
      expect(
        canDisplayBrowserNotification(
          BrowserNotificationPermissionState.defaultPrompt,
        ),
        isFalse,
      );
      expect(
        canDisplayBrowserNotification(
          BrowserNotificationPermissionState.denied,
        ),
        isFalse,
      );
    });
  });
}
