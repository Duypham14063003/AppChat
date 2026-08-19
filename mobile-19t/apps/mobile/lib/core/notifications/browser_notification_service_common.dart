enum BrowserNotificationPermissionState {
  unsupported,
  defaultPrompt,
  granted,
  denied,
}

BrowserNotificationPermissionState browserNotificationPermissionFromRaw(
  String? rawPermission,
) {
  switch ((rawPermission ?? '').trim().toLowerCase()) {
    case 'granted':
      return BrowserNotificationPermissionState.granted;
    case 'denied':
      return BrowserNotificationPermissionState.denied;
    case 'default':
      return BrowserNotificationPermissionState.defaultPrompt;
    default:
      return BrowserNotificationPermissionState.unsupported;
  }
}

bool shouldRequestBrowserNotificationPermission(
  BrowserNotificationPermissionState permission,
) {
  return permission == BrowserNotificationPermissionState.defaultPrompt;
}

bool canDisplayBrowserNotification(
  BrowserNotificationPermissionState permission,
) {
  return permission == BrowserNotificationPermissionState.granted;
}
