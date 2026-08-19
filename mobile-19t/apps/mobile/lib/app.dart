import 'dart:async';
import 'dart:collection';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nineteen_tech_app/core/config/app_config.dart';
import 'package:nineteen_tech_app/core/network/connection_banner_policy.dart';
import 'package:nineteen_tech_app/core/network/websocket_manager.dart';
import 'package:nineteen_tech_app/core/network/websocket_provider.dart';
import 'package:nineteen_tech_app/core/notifications/badge_sync_service.dart';
import 'package:nineteen_tech_app/core/notifications/foreground_notification_service.dart';
import 'package:nineteen_tech_app/core/notifications/push_notification_service.dart';
import 'package:nineteen_tech_app/core/router/app_router.dart';
import 'package:nineteen_tech_app/core/router/chat_route_utils.dart';
import 'package:nineteen_tech_app/core/theme/app_interaction.dart';
import 'package:nineteen_tech_app/core/theme/app_theme.dart';
import 'package:nineteen_tech_app/core/theme/theme_color_presets.dart';
import 'package:nineteen_tech_app/features/auth/providers/auth_notifier.dart';
import 'package:nineteen_tech_app/features/chat/data/offline_queue_service.dart';
import 'package:nineteen_tech_app/features/chat/providers/chat_providers.dart';
import 'package:nineteen_tech_app/features/hr/providers/hr_providers.dart';
import 'package:nineteen_tech_app/features/call/providers/call_notifier.dart';
import 'package:nineteen_tech_app/features/call/services/callkit_service.dart';

enum NotificationNavigationMode { push, go }

String? routeForNotificationData(Map<String, dynamic> data) {
  final deepLink = data['deep_link']?.toString();
  if (deepLink != null && deepLink.startsWith('/pocs/')) {
    return deepLink;
  }

  final pocId = data['poc_id']?.toString();
  if (pocId != null && pocId.isNotEmpty) {
    return '/pocs/$pocId';
  }

  final convId = data['conv_id'] as String?;
  if (convId != null && convId.isNotEmpty) {
    return '/chat/$convId';
  }

  final type = data['type'] as String?;
  switch (type) {
    case 'call_invite':
      // Incoming call push notification (khi offline)
      // call_id và caller_id nằm trong data, CallNotifier sẽ xử lý
      return '/call/incoming';
    case 'hr_checkin_reminder':
    case 'hr_checkout_reminder':
    case 'hr_auto_checkout':
      return '/hr';
    case 'hr_contract_action_reminder':
      final userId = data['user_id'] as String?;
      final contractId = data['contract_id'] as String?;
      if (userId != null &&
          userId.isNotEmpty &&
          contractId != null &&
          contractId.isNotEmpty) {
        return '/hr/employees/$userId/contracts/$contractId';
      }
      return '/hr';
    default:
      return null;
  }
}

bool shouldRefreshAttendanceForNotificationData(Map<String, dynamic> data) {
  return data['type'] == 'hr_auto_checkout';
}

NotificationNavigationMode navigationModeForNotificationRoute(String route) {
  return NotificationNavigationMode.go;
}

bool shouldSkipNotificationNavigation({
  required String? currentLocation,
  required String targetRoute,
}) {
  return currentLocation == targetRoute;
}

bool shouldSyncChatListOnResume(AppLifecycleState state) {
  return state == AppLifecycleState.resumed;
}

bool shouldEnableOfflineQueueForAuthStatus(AuthStatus status) {
  return status == AuthStatus.authenticated;
}

bool shouldRecoverWebSocketForAuthState({
  required AsyncValue<AuthState> authState,
  required WsConnectionState wsState,
}) {
  final auth = authState.valueOrNull;
  return auth?.status == AuthStatus.authenticated &&
      wsState != WsConnectionState.connected;
}

bool shouldStartConnectionRecoveryWindow(WsConnectionState wsState) {
  return wsState != WsConnectionState.connected;
}

bool isChatNotificationData(Map<String, dynamic> data) {
  final convId = data['conv_id'] as String?;
  return convId != null && convId.isNotEmpty;
}

bool shouldSuppressForegroundChatNotification({
  required Map<String, dynamic> data,
  required String? currentLocation,
}) {
  if (!isChatNotificationData(data)) return false;
  final currentConvId = conversationIdForChatLocation(currentLocation);
  if (currentConvId == null || currentConvId.isEmpty) return false;
  return currentConvId == data['conv_id'];
}

bool shouldShowForegroundNotificationForData({
  required Map<String, dynamic> data,
  required String? currentLocation,
}) {
  if (!isChatNotificationData(data)) return true;
  return !shouldSuppressForegroundChatNotification(
    data: data,
    currentLocation: currentLocation,
  );
}

String? foregroundNotificationEventIdForData(Map<String, dynamic> data) {
  for (final key in const ['id', 'message_id', 'reminder_id', 'leave_id']) {
    final value = data[key];
    if (value == null) continue;
    final normalizedValue = value.toString().trim();
    if (normalizedValue.isNotEmpty) {
      return normalizedValue;
    }
  }
  return null;
}

bool rememberForegroundNotificationEvent({
  required Queue<String> recentIds,
  required Set<String> recentIdSet,
  required String? messageId,
  required int maxTracked,
}) {
  if (messageId == null || messageId.isEmpty) return true;
  if (recentIdSet.contains(messageId)) return false;

  recentIds.addLast(messageId);
  recentIdSet.add(messageId);
  while (recentIds.length > maxTracked) {
    final removedId = recentIds.removeFirst();
    recentIdSet.remove(removedId);
  }
  return true;
}

String foregroundChatNotificationTitle(Map<String, dynamic> data) {
  final senderName = data['sender_name'] as String?;
  if (senderName != null && senderName.isNotEmpty) {
    return senderName;
  }
  return 'Tin nhắn mới';
}

String foregroundChatNotificationBody(Map<String, dynamic> data) {
  if (data['deleted_at'] != null) {
    return 'Tin nhắn đã được thu hồi';
  }

  final type = data['type'] as String? ?? 'text';
  final content = data['content'] as String?;
  switch (type) {
    case 'image':
      return content != null && content.isNotEmpty ? 'Anh - $content' : 'Anh';
    case 'album':
      return content != null && content.isNotEmpty
          ? 'Nhieu anh - $content'
          : 'Nhieu anh';
    case 'voice':
      return 'Tin nhan thoai';
    case 'video':
      return content != null && content.isNotEmpty
          ? 'Video - $content'
          : 'Video';
    case 'system':
      return 'Hoat dong moi trong cuoc tro chuyen';
    default:
      return (content != null && content.isNotEmpty)
          ? content
          : 'Ban co tin nhan moi';
  }
}

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> with WidgetsBindingObserver {
  static const _maxTrackedForegroundMessageIds = 100;

  ProviderSubscription<AsyncValue<AuthState>>? _authSubscription;
  ProviderSubscription<AsyncValue<WsConnectionState>>?
  _wsConnectionSubscription;
  WebSocketManager? _foregroundChatNotificationManager;
  GoRouter? _trackedRouter;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  final Queue<String> _recentForegroundChatMessageIds = Queue<String>();
  final Set<String> _recentForegroundChatMessageIdSet = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authSubscription = ref.listenManual<AsyncValue<AuthState>>(
      authNotifierProvider,
      (previous, next) => _handleAuthState(next),
      fireImmediately: true,
    );
    _wsConnectionSubscription = ref.listenManual<AsyncValue<WsConnectionState>>(
      webSocketConnectionProvider,
      (previous, next) => _handleWsConnectionState(previous, next),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncAppLifecycleState(
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed,
      );
      _syncRouterLocationListener(ref.read(routerProvider));
      _startConnectivityMonitor();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.close();
    _wsConnectionSubscription?.close();
    _connectivitySubscription?.cancel();
    _detachRouterLocationListener();
    _detachForegroundChatListener();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _syncAppLifecycleState(state);
    if (!shouldSyncChatListOnResume(state)) return;
    _markRecentConnectionRecoveryIfNeeded();
    _recoverAuthenticatedWebSocket();
    unawaited(ref.read(authNotifierProvider.notifier).resyncRewardWallet());
    unawaited(ref.read(chatListProvider.notifier).refresh());
    unawaited(ref.read(badgeSyncServiceProvider).syncFromLocalUnreadTotal());
    // Kiểm tra cuộc gọi active khi app quay trở lại foreground
    ref.read(callNotifierProvider.notifier).checkInitialCall();
    // Đồng bộ cuộc gọi đến đang chờ từ backend (phòng khi WS bị rớt/zombie)
    unawaited(
      ref.read(callNotifierProvider.notifier).syncPendingIncomingCall(),
    );
  }

  void _syncAppLifecycleState(AppLifecycleState state) {
    final notifier = ref.read(appLifecycleStateProvider.notifier);
    if (notifier.state == state) return;
    notifier.state = state;
  }

  void _syncRouterLocationListener(GoRouter router) {
    if (identical(_trackedRouter, router)) return;
    _detachRouterLocationListener();
    _trackedRouter = router;
    router.routeInformationProvider.addListener(_syncCurrentRouteLocation);
    _syncCurrentRouteLocation();
  }

  void _detachRouterLocationListener() {
    _trackedRouter?.routeInformationProvider.removeListener(
      _syncCurrentRouteLocation,
    );
    _trackedRouter = null;
  }

  void _syncCurrentRouteLocation() {
    final nextLocation =
        _trackedRouter?.routeInformationProvider.value.uri.path;
    final notifier = ref.read(currentVisibleRouteLocationProvider.notifier);
    if (notifier.state == nextLocation) return;
    notifier.state = nextLocation;
  }

  void _recoverAuthenticatedWebSocket() {
    final manager = ref.read(webSocketManagerProvider);
    if (shouldRecoverWebSocketForAuthState(
      authState: ref.read(authNotifierProvider),
      wsState: manager.state,
    )) {
      manager.ensureConnected();
    }
  }

  void _markRecentConnectionRecoveryIfNeeded() {
    final manager = ref.read(webSocketManagerProvider);
    final notifier = ref.read(
      recentConnectionRecoveryStartedAtProvider.notifier,
    );
    notifier.state = nextConnectionRecoveryStartedAt(
      connectionState: manager.state,
      now: DateTime.now(),
      currentRecoveryStartedAt: notifier.state,
    );
  }

  // --- Network connectivity monitoring ---

  void _startConnectivityMonitor() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _handleConnectivityChanged,
    );
  }

  void _handleConnectivityChanged(List<ConnectivityResult> results) {
    final hasConnection = results.any((r) => r != ConnectivityResult.none);
    if (!hasConnection) return;

    // Network restored — tell WebSocket to reconnect immediately
    final auth = ref.read(authNotifierProvider).valueOrNull;
    if (auth?.status != AuthStatus.authenticated) return;
    ref.read(webSocketManagerProvider).onNetworkRestored();
  }

  /// Khi WebSocket vừa chuyển sang `connected`, đồng bộ lại cuộc gọi đến
  /// đang chờ từ backend. Xử lý trường hợp sự kiện `incoming_call` qua WS
  /// bị mất do socket rớt/zombie (vd: receiver reconnect sau khi caller đã gọi).
  void _handleWsConnectionState(
    AsyncValue<WsConnectionState>? previous,
    AsyncValue<WsConnectionState> next,
  ) {
    final previousState = previous?.valueOrNull;
    final nextState = next.valueOrNull;
    if (nextState != WsConnectionState.connected) return;
    ref.read(recentConnectionRecoveryStartedAtProvider.notifier).state = null;
    if (previousState == WsConnectionState.connected) return;

    final auth = ref.read(authNotifierProvider).valueOrNull;
    if (auth?.status != AuthStatus.authenticated) return;

    unawaited(
      ref.read(callNotifierProvider.notifier).syncPendingIncomingCall(),
    );
  }

  void _handleAuthState(AsyncValue<AuthState> next) {
    next.whenData((auth) {
      final pushService = ref.read(pushNotificationServiceProvider);
      final badgeSyncService = ref.read(badgeSyncServiceProvider);
      final foregroundNotifications = ref.read(
        foregroundNotificationServiceProvider,
      );

      // Incoming call khi online được nhận qua Chat WebSocket
      // (event 'incoming_call' từ Redis PubSub — xem _attachCallListener)

      if (!shouldEnableOfflineQueueForAuthStatus(auth.status)) {
        ref.invalidate(offlineQueueServiceProvider);
        _detachForegroundChatListener();
        unawaited(pushService.reset());
        unawaited(badgeSyncService.clearBadge());
        return;
      }

      // Bootstrap chat offline queue and call notifier once per authenticated session.
      ref.read(offlineQueueServiceProvider);
      ref.read(callNotifierProvider);
      unawaited(() async {
        final notificationInitialization = foregroundNotifications.initialize();
        _attachForegroundChatListener();

        try {
          await notificationInitialization;
        } catch (error, stackTrace) {
          _reportNotificationBootstrapError(
            action: 'initialize local foreground notifications',
            error: error,
            stackTrace: stackTrace,
          );
        }

        try {
          final storage = ref.read(secureTokenStorageProvider);
          final deviceId = await storage.getOrCreateDeviceId();
          await pushService.initialize(
            deviceId: deviceId,
            onForegroundMessageData: _handleForegroundNotificationData,
            onForegroundNotification: _handleForegroundNotificationRequest,
            onNotificationTap: _handleNotificationTap,
          );
        } catch (error, stackTrace) {
          _reportNotificationBootstrapError(
            action: 'initialize push notifications',
            error: error,
            stackTrace: stackTrace,
          );
        } finally {
          await badgeSyncService.syncFromLocalUnreadTotal();
        }
      }());
    });
  }

  void _handleForegroundNotificationData(Map<String, dynamic> data) {
    if (shouldRefreshAttendanceForNotificationData(data)) {
      ref.invalidate(attendanceProvider);
    }
    unawaited(ref.read(badgeSyncServiceProvider).applyBadgeCountFromData(data));
  }

  Future<bool> _handleForegroundNotificationRequest(
    ForegroundNotificationRequest notification,
  ) async {
    final type = notification.data['type'];
    final callId =
        notification.data['call_id'] ??
        notification.data['callId'] ??
        notification.data['id'];
    debugPrint('[App] FCM foreground request: type=$type, callId=$callId');
    if (type == 'call_invite') {
      final currentCallId = ref.read(callNotifierProvider).callId;
      if (callId != null && callId.toString() == currentCallId) {
        debugPrint(
          '[App] FCM call_invite IGNORED: already handling callId=$callId',
        );
        return false;
      }
      ref
          .read(callNotifierProvider.notifier)
          .handleIncomingCall(notification.data);
      return false;
    }
    if (type == 'call_accepted') {
      debugPrint('[App] FCM call_accepted received');
      ref
          .read(callNotifierProvider.notifier)
          .handleCallAccepted(callId?.toString());
      return false;
    }
    if (type == 'call_rejected') {
      debugPrint('[App] FCM call_rejected received');
      ref
          .read(callNotifierProvider.notifier)
          .markCallAsProcessed(callId?.toString());
      if (callId != null) {
        ref.read(callKitServiceProvider).endCall(callId.toString());
      }
      ref
          .read(callNotifierProvider.notifier)
          .handleCallRejected(callId?.toString());
      return false;
    }
    if (type == 'call_ended') {
      debugPrint('[App] FCM call_ended received');
      ref
          .read(callNotifierProvider.notifier)
          .markCallAsProcessed(callId?.toString());
      if (callId != null) {
        ref.read(callKitServiceProvider).endCall(callId.toString());
      }
      ref
          .read(callNotifierProvider.notifier)
          .handleCallEnded(callId?.toString());
      return false;
    }
    if (type == 'call_busy') {
      debugPrint('[App] FCM call_busy received');
      ref
          .read(callNotifierProvider.notifier)
          .markCallAsProcessed(callId?.toString());
      if (callId != null) {
        ref.read(callKitServiceProvider).endCall(callId.toString());
      }
      ref
          .read(callNotifierProvider.notifier)
          .handleCallBusy(callId?.toString());
      return false;
    }
    if (isChatNotificationData(notification.data)) {
      final shouldShow = _shouldShowForegroundChatNotification(
        notification.data,
      );
      if (!shouldShow) {
        return false;
      }
      return _rememberForegroundChatMessage(
        foregroundNotificationEventIdForData(notification.data),
      );
    }
    return true;
  }

  void _attachForegroundChatListener() {
    final manager = ref.read(webSocketManagerProvider);
    if (identical(_foregroundChatNotificationManager, manager)) {
      return;
    }
    _detachForegroundChatListener();
    manager.on('new_message', _handleForegroundChatMessage);
    // Nhận incoming_call khi app đang mở (online)
    // Backend publish qua Redis PubSub → Chat WebSocket
    manager.on('incoming_call', _handleIncomingCallViaWs);
    manager.on('call_accepted', _handleCallAcceptedViaWs);
    manager.on('call_rejected', _handleCallRejectedViaWs);
    manager.on('call_ended', _handleCallEndedViaWs);
    manager.on('call_busy', _handleCallBusyViaWs);
    _foregroundChatNotificationManager = manager;
  }

  void _detachForegroundChatListener() {
    _foregroundChatNotificationManager?.off(
      'new_message',
      _handleForegroundChatMessage,
    );
    _foregroundChatNotificationManager?.off(
      'incoming_call',
      _handleIncomingCallViaWs,
    );
    _foregroundChatNotificationManager?.off(
      'call_accepted',
      _handleCallAcceptedViaWs,
    );
    _foregroundChatNotificationManager?.off(
      'call_rejected',
      _handleCallRejectedViaWs,
    );
    _foregroundChatNotificationManager?.off(
      'call_ended',
      _handleCallEndedViaWs,
    );
    _foregroundChatNotificationManager?.off('call_busy', _handleCallBusyViaWs);
    _foregroundChatNotificationManager = null;
  }

  /// Xử lý incoming_call event qua Chat WebSocket (khi online).
  /// data: { call_id, caller_id, channel_name, type }
  void _handleIncomingCallViaWs(Map<String, dynamic> data) {
    final callId = data['call_id'] ?? data['callId'] ?? data['id'];
    debugPrint('[App] WS incoming_call received: callId=$callId');
    ref.read(callNotifierProvider.notifier).handleIncomingCall(data);
  }

  void _handleCallAcceptedViaWs(Map<String, dynamic> data) {
    final callId = data['call_id'] ?? data['callId'] ?? data['id'];
    debugPrint('[App] WS call_accepted received: callId=$callId');
    ref
        .read(callNotifierProvider.notifier)
        .handleCallAccepted(callId?.toString());
  }

  void _handleCallRejectedViaWs(Map<String, dynamic> data) {
    final callId = data['call_id'] ?? data['callId'] ?? data['id'];
    debugPrint('[App] WS call_rejected received: callId=$callId');
    ref
        .read(callNotifierProvider.notifier)
        .markCallAsProcessed(callId?.toString());
    ref
        .read(callNotifierProvider.notifier)
        .handleCallRejected(callId?.toString());
  }

  void _handleCallEndedViaWs(Map<String, dynamic> data) {
    final callId = data['call_id'] ?? data['callId'] ?? data['id'];
    debugPrint('[App] WS call_ended received: callId=$callId');
    ref
        .read(callNotifierProvider.notifier)
        .markCallAsProcessed(callId?.toString());
    ref.read(callNotifierProvider.notifier).handleCallEnded(callId?.toString());
  }

  void _handleCallBusyViaWs(Map<String, dynamic> data) {
    final callId = data['call_id'] ?? data['callId'] ?? data['id'];
    debugPrint('[App] WS call_busy received: callId=$callId');
    ref
        .read(callNotifierProvider.notifier)
        .markCallAsProcessed(callId?.toString());
    ref.read(callNotifierProvider.notifier).handleCallBusy(callId?.toString());
  }

  bool _shouldShowForegroundChatNotification(Map<String, dynamic> data) {
    return shouldShowForegroundNotificationForData(
      data: data,
      currentLocation: _currentLocation(),
    );
  }

  String? _currentLocation() {
    return ref
        .read(routerProvider)
        .routeInformationProvider
        .value
        .uri
        .toString();
  }

  bool _rememberForegroundChatMessage(String? messageId) {
    return rememberForegroundNotificationEvent(
      recentIds: _recentForegroundChatMessageIds,
      recentIdSet: _recentForegroundChatMessageIdSet,
      messageId: messageId,
      maxTracked: _maxTrackedForegroundMessageIds,
    );
  }

  void _handleForegroundChatMessage(Map<String, dynamic> data) {
    if (!_shouldShowForegroundChatNotification(data)) return;
    final messageId = foregroundNotificationEventIdForData(data);
    if (!_rememberForegroundChatMessage(messageId)) return;

    final foregroundNotifications = ref.read(
      foregroundNotificationServiceProvider,
    );
    unawaited(
      foregroundNotifications.showForegroundNotification(
        title: foregroundChatNotificationTitle(data),
        body: foregroundChatNotificationBody(data),
        tag: messageId,
      ),
    );
  }

  void _reportNotificationBootstrapError({
    required String action,
    required Object error,
    required StackTrace stackTrace,
  }) {
    debugPrint('Failed to $action: $error');
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'App',
        context: ErrorDescription('while attempting to $action'),
      ),
    );
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    if (shouldRefreshAttendanceForNotificationData(data)) {
      ref.invalidate(attendanceProvider);
    }

    if (isChatNotificationData(data)) {
      _markRecentConnectionRecoveryIfNeeded();
      _recoverAuthenticatedWebSocket();
    }

    // Xử lý call_invite FCM notification (khi offline)
    // Backend gửi: { type: 'call_invite', call_id, caller_id, channel_name }
    if (data['type'] == 'call_invite') {
      final callId = data['call_id'] ?? data['callId'] ?? data['id'];
      debugPrint('[App] FCM tap call: type=call_invite, callId=$callId');
      ref.read(callNotifierProvider.notifier).handleIncomingCall(data);
    }

    if (data['type'] == 'call_ended' || data['type'] == 'call_rejected') {
      final callId = data['call_id'] ?? data['callId'] ?? data['id'];
      ref
          .read(callNotifierProvider.notifier)
          .markCallAsProcessed(callId?.toString());
      return;
    }

    final route = routeForNotificationData(data);
    if (route != null) {
      final router = ref.read(routerProvider);
      final currentLocation = router.routeInformationProvider.value.uri
          .toString();
      if (shouldSkipNotificationNavigation(
        currentLocation: currentLocation,
        targetRoute: route,
      )) {
        return;
      }

      switch (navigationModeForNotificationRoute(route)) {
        case NotificationNavigationMode.go:
          router.go(route);
          break;
        case NotificationNavigationMode.push:
          unawaited(router.push(route));
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final authState = ref.watch(authNotifierProvider);
    if (!identical(_trackedRouter, router)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _syncRouterLocationListener(router);
      });
    }
    final themePreset = ref.watch(themePresetProvider);

    return MaterialApp.router(
      title: AppConfig.instance.appName,
      theme: AppTheme.dark(themePreset),
      scrollBehavior: const AppScrollBehavior(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        Widget content = _AuthBootstrapGate(
          authState: authState,
          child: child ?? const SizedBox.shrink(),
        );
        // Show connection status banner when disconnected/reconnecting
        if (authState.valueOrNull?.status == AuthStatus.authenticated) {
          content = Column(
            children: [
              const _ConnectionStatusBanner(),
              Expanded(child: content),
            ],
          );
        }
        return content;
      },
    );
  }
}

class _AuthBootstrapGate extends StatelessWidget {
  const _AuthBootstrapGate({required this.authState, required this.child});

  final AsyncValue<AuthState> authState;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final auth = authState.valueOrNull;
    final shouldBlock =
        auth?.status == AuthStatus.authenticated &&
        auth?.bootstrapStatus != AuthBootstrapStatus.ready;
    if (!shouldBlock) return child;

    return Stack(
      children: [
        child,
        const Positioned.fill(
          child: ColoredBox(color: Color.fromRGBO(0, 0, 0, 0.55)),
        ),
        const Positioned.fill(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: _AuthBootstrapGateCard(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AuthBootstrapGateCard extends ConsumerStatefulWidget {
  const _AuthBootstrapGateCard();

  @override
  ConsumerState<_AuthBootstrapGateCard> createState() =>
      _AuthBootstrapGateCardState();
}

class _AuthBootstrapGateCardState
    extends ConsumerState<_AuthBootstrapGateCard> {
  final _phoneController = TextEditingController();
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _savePhoneNumber() async {
    final phone = _phoneController.text.trim();
    final normalizedPhone = phone.replaceAll(' ', '');
    if (!_isValidPhoneNumber(normalizedPhone)) {
      setState(() {
        _errorMessage = 'Vui lòng nhập số điện thoại hợp lệ.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(authNotifierProvider.notifier)
          .updatePhoneNumber(normalizedPhone);
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = data is Map ? data['message'] as String? : null;
      if (!mounted) return;
      setState(() {
        _errorMessage =
            message ?? 'Không thể cập nhật số điện thoại. Vui lòng thử lại.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Không thể cập nhật số điện thoại: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  bool _isValidPhoneNumber(String value) {
    final normalized = value.replaceAll(RegExp(r'[\s\-]'), '');
    return RegExp(r'^\+?[0-9]{9,15}$').hasMatch(normalized);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final auth = ref.watch(authNotifierProvider).valueOrNull;
    final status = auth?.bootstrapStatus ?? AuthBootstrapStatus.ready;
    final user = auth?.user;
    if (_phoneController.text.isEmpty &&
        user?.phoneNumber != null &&
        user!.phoneNumber!.trim().isNotEmpty) {
      _phoneController.text = user.phoneNumber!.trim();
    }

    final content = switch (status) {
      AuthBootstrapStatus.pending => _BootstrapLoadingContent(palette: palette),
      AuthBootstrapStatus.error => _BootstrapErrorContent(
        palette: palette,
        message:
            auth?.bootstrapErrorMessage ?? 'Không thể tải cấu hình khởi tạo.',
        onRetry: () =>
            ref.read(authNotifierProvider.notifier).retryBootstrapConfig(),
        onLogout: () => ref.read(authNotifierProvider.notifier).logout(),
      ),
      AuthBootstrapStatus.phoneRequired => _BootstrapPhoneContent(
        palette: palette,
        controller: _phoneController,
        isSaving: _isSaving,
        errorMessage: _errorMessage,
        onSave: _savePhoneNumber,
        onLogout: () => ref.read(authNotifierProvider.notifier).logout(),
      ),
      AuthBootstrapStatus.ready => const SizedBox.shrink(),
    };

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Material(
        color: palette.surface,
        borderRadius: BorderRadius.circular(24),
        child: Padding(padding: const EdgeInsets.all(20), child: content),
      ),
    );
  }
}

class _BootstrapLoadingContent extends StatelessWidget {
  const _BootstrapLoadingContent({required this.palette});

  final AppThemePalette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(color: palette.primary),
        const SizedBox(height: 16),
        Text(
          'Đang kiểm tra thông tin tài khoản...',
          textAlign: TextAlign.center,
          style: TextStyle(color: palette.textPrimary, fontSize: 16),
        ),
      ],
    );
  }
}

class _BootstrapErrorContent extends StatelessWidget {
  const _BootstrapErrorContent({
    required this.palette,
    required this.message,
    required this.onRetry,
    required this.onLogout,
  });

  final AppThemePalette palette;
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Không thể tải cấu hình',
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          style: TextStyle(color: palette.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onLogout,
                child: const Text('Đăng xuất'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: onRetry,
                child: const Text('Thử lại'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BootstrapPhoneContent extends StatelessWidget {
  const _BootstrapPhoneContent({
    required this.palette,
    required this.controller,
    required this.isSaving,
    required this.errorMessage,
    required this.onSave,
    required this.onLogout,
  });

  final AppThemePalette palette;
  final TextEditingController controller;
  final bool isSaving;
  final String? errorMessage;
  final VoidCallback onSave;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Thêm số điện thoại',
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tài khoản của bạn cần có số điện thoại trước khi tiếp tục sử dụng ứng dụng.',
          style: TextStyle(color: palette.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          enabled: !isSaving,
          style: TextStyle(color: palette.textPrimary),
          decoration: InputDecoration(
            labelText: 'Số điện thoại',
            hintText: '0901234567',
            errorText: errorMessage,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: isSaving ? null : onLogout,
                child: const Text('Đăng xuất'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: isSaving ? null : onSave,
                child: isSaving
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: palette.isLight
                              ? Colors.white
                              : palette.background,
                        ),
                      )
                    : const Text('Lưu'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ConnectionStatusBanner extends ConsumerWidget {
  const _ConnectionStatusBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wsState = ref.watch(webSocketConnectionProvider);
    final connectionState = wsState.valueOrNull ?? WsConnectionState.connected;
    final recoveryStartedAt = ref.watch(
      recentConnectionRecoveryStartedAtProvider,
    );
    final now =
        ref.watch(connectionBannerNowProvider).valueOrNull ?? DateTime.now();
    final presentation = resolveConnectionBannerPresentation(
      connectionState: connectionState,
      now: now,
      recoveryStartedAt: recoveryStartedAt,
    );

    if (!presentation.isVisible) {
      return const SizedBox.shrink();
    }

    final isSoft = presentation.severity == ConnectionBannerSeverity.soft;
    final message = presentation.message ?? '';

    return Material(
      color: isSoft
          ? const Color(0xFFF59E0B) // amber
          : const Color(0xFFEF4444), // red
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (presentation.showSpinner)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.wifi_off_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (presentation.showRetry) ...[
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
                    ref
                            .read(
                              recentConnectionRecoveryStartedAtProvider
                                  .notifier,
                            )
                            .state =
                        DateTime.now();
                    ref.read(webSocketManagerProvider).onNetworkRestored();
                  },
                  child: const Text(
                    'Thử lại',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
