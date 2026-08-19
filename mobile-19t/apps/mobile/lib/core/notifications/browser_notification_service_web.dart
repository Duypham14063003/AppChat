// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;

import 'browser_notification_service_common.dart';

class BrowserNotificationService {
  BrowserNotificationPermissionState? _cachedPermission;
  final Map<String, html.EventListener> _permissionPromptListeners = {};
  bool _isRequestInFlight = false;

  Future<void> initialize() async {
    final permission = await permissionState();
    if (!shouldRequestBrowserNotificationPermission(permission)) {
      _detachPermissionPromptListeners();
      return;
    }

    // Many browsers only honor notification permission prompts when they are
    // triggered from a user gesture. We arm a one-shot retry on the next
    // interaction so authenticated web sessions can still complete setup.
    _attachPermissionPromptListeners();
  }

  Future<BrowserNotificationPermissionState> permissionState() async {
    if (!html.Notification.supported) {
      _cachedPermission = BrowserNotificationPermissionState.unsupported;
      return _cachedPermission!;
    }

    _cachedPermission = browserNotificationPermissionFromRaw(
      html.Notification.permission,
    );
    return _cachedPermission!;
  }

  Future<BrowserNotificationPermissionState> requestPermissionIfNeeded() async {
    final permission = await permissionState();
    if (!shouldRequestBrowserNotificationPermission(permission)) {
      _detachPermissionPromptListeners();
      return permission;
    }

    if (_isRequestInFlight) {
      return permission;
    }

    _isRequestInFlight = true;
    final requested = await html.Notification.requestPermission();
    _isRequestInFlight = false;
    _cachedPermission = browserNotificationPermissionFromRaw(requested);
    if (!shouldRequestBrowserNotificationPermission(_cachedPermission!)) {
      _detachPermissionPromptListeners();
    }
    return _cachedPermission!;
  }

  Future<bool> showNotification({
    required String title,
    String? body,
    String? tag,
  }) async {
    final permission = await permissionState();
    if (!canDisplayBrowserNotification(permission)) {
      return false;
    }

    html.Notification(
      title,
      body: body,
      tag: tag,
      icon: '/icons/Icon-192.png',
    );
    return true;
  }

  void _attachPermissionPromptListeners() {
    if (_permissionPromptListeners.isNotEmpty) {
      return;
    }

    void register(String eventType) {
      late final html.EventListener listener;
      listener = (event) {
        _detachPermissionPromptListeners();
        unawaited(requestPermissionIfNeeded());
      };
      _permissionPromptListeners[eventType] = listener;
      html.document.addEventListener(eventType, listener);
    }

    register('pointerdown');
    register('keydown');
    register('touchend');
  }

  void _detachPermissionPromptListeners() {
    _permissionPromptListeners.forEach((eventType, listener) {
      html.document.removeEventListener(eventType, listener);
    });
    _permissionPromptListeners.clear();
  }
}
