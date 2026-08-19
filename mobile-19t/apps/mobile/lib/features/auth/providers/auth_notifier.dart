import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nineteen_tech_app/core/config/app_config.dart';
import 'package:nineteen_tech_app/core/network/websocket_manager.dart';
import 'package:nineteen_tech_app/core/network/websocket_provider.dart';
import 'package:nineteen_tech_app/core/notifications/push_notification_service.dart';
import 'package:nineteen_tech_app/features/auth/data/auth_interceptor.dart';
import 'package:nineteen_tech_app/features/auth/data/auth_repository.dart';
import 'package:nineteen_tech_app/features/auth/data/secure_token_storage.dart';
import 'package:nineteen_tech_app/features/auth/data/auth_token_sync.dart';

final secureTokenStorageProvider = Provider<SecureTokenStorage>(
  (ref) => SecureTokenStorage(),
);

final authTokenSyncProvider = Provider<AuthTokenSync>((ref) {
  final sync = createAuthTokenSync();
  ref.onDispose(sync.dispose);
  return sync;
});

final dioProvider = Provider<Dio>((ref) {
  final storage = ref.read(secureTokenStorageProvider);
  final baseUrl = '${AppConfig.instance.apiUrl}/api/v1';
  debugPrint('[Dio] baseUrl: $baseUrl');
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );
  dio.interceptors.add(
    LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (obj) => debugPrint('[Dio] $obj'),
    ),
  );
  dio.interceptors.add(
    AuthInterceptor(
      tokenStorage: storage,
      onTokenRefresh: setCachedToken,
      onTokensUpdated: ({required accessToken, required refreshToken}) {
        return ref
            .read(authTokenSyncProvider)
            .publishTokens(
              accessToken: accessToken,
              refreshToken: refreshToken,
            );
      },
      onAuthFailure: () {
        ref.read(authNotifierProvider.notifier).logout();
      },
    ),
  );
  return dio;
});

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(dioProvider)),
);

final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

enum AuthStatus { unauthenticated, authenticated }

enum AuthBootstrapStatus { pending, ready, phoneRequired, error }

class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.points,
    this.payrollStartConfig,
    this.configRoles = const [],
    this.bootstrapStatus = AuthBootstrapStatus.ready,
    this.bootstrapErrorMessage,
  });

  final AuthStatus status;
  final UserInfo? user;
  final int? points;
  final int? payrollStartConfig;
  final List<String> configRoles;
  final AuthBootstrapStatus bootstrapStatus;
  final String? bootstrapErrorMessage;

  bool get isBootstrapReady => bootstrapStatus == AuthBootstrapStatus.ready;
  bool get requiresPhoneNumber =>
      bootstrapStatus == AuthBootstrapStatus.phoneRequired;

  AuthState copyWith({
    AuthStatus? status,
    Object? user = _authUnsetField,
    Object? points = _authUnsetField,
    Object? payrollStartConfig = _authUnsetField,
    List<String>? configRoles,
    AuthBootstrapStatus? bootstrapStatus,
    Object? bootstrapErrorMessage = _authUnsetField,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: identical(user, _authUnsetField) ? this.user : user as UserInfo?,
      points: identical(points, _authUnsetField) ? this.points : points as int?,
      payrollStartConfig: identical(payrollStartConfig, _authUnsetField) ? this.payrollStartConfig : payrollStartConfig as int?,
      configRoles: configRoles ?? this.configRoles,
      bootstrapStatus: bootstrapStatus ?? this.bootstrapStatus,
      bootstrapErrorMessage: identical(bootstrapErrorMessage, _authUnsetField)
          ? this.bootstrapErrorMessage
          : bootstrapErrorMessage as String?,
    );
  }

  static const unauthenticated = AuthState(status: AuthStatus.unauthenticated);
}

const Object _authUnsetField = Object();

class AuthNotifier extends AsyncNotifier<AuthState> {
  StreamSubscription<AuthTokenSyncEvent>? _authTokenSyncSubscription;
  StreamSubscription<WsConnectionState>? _webSocketStateSubscription;
  DateTime? _lastRewardWalletSyncAt;
  Future<void>? _walletResyncInFlight;
  bool _rewardPointsRealtimeBound = false;

  void _connectWebSocket(String accessToken) {
    setCachedToken(accessToken);
    ref.read(webSocketManagerProvider).connect();
  }

  void _bindAuthTokenSync() {
    _authTokenSyncSubscription ??= ref
        .read(authTokenSyncProvider)
        .events
        .listen(_handleAuthTokenSyncEvent);
    ref.onDispose(() async {
      await _authTokenSyncSubscription?.cancel();
      await _webSocketStateSubscription?.cancel();
      if (_rewardPointsRealtimeBound) {
        ref
            .read(webSocketManagerProvider)
            .off('reward_points_changed', _handleRewardPointsChanged);
        _rewardPointsRealtimeBound = false;
      }
    });
  }

  void _bindRewardPointsRealtime() {
    if (!_rewardPointsRealtimeBound) {
      ref
          .read(webSocketManagerProvider)
          .on('reward_points_changed', _handleRewardPointsChanged);
      _rewardPointsRealtimeBound = true;
    }

    _webSocketStateSubscription ??= ref
        .read(webSocketManagerProvider)
        .stateStream
        .listen(_handleWebSocketStateChanged);
  }

  void _handleWebSocketStateChanged(WsConnectionState state) {
    if (state != WsConnectionState.connected) return;
    unawaited(resyncRewardWallet());
  }

  void _handleRewardPointsChanged(Map<String, dynamic> payload) {
    final balance = _readLiveBalance(payload);
    if (balance == null) return;
    _lastRewardWalletSyncAt = DateTime.now();
    _updatePoints(balance);
  }

  int? _readLiveBalance(Map<String, dynamic> payload) {
    final rawBalance = payload['balance'];
    if (rawBalance is int) return rawBalance;
    if (rawBalance is num) return rawBalance.toInt();
    if (rawBalance is String) return int.tryParse(rawBalance.trim());
    return null;
  }

  void _updatePoints(int balance) {
    final currentState = state.valueOrNull;
    if (currentState == null ||
        currentState.status != AuthStatus.authenticated ||
        currentState.user == null) {
      return;
    }

    if (currentState.points == balance) return;
    state = AsyncData(currentState.copyWith(points: balance));
  }

  Future<void> _handleAuthTokenSyncEvent(AuthTokenSyncEvent event) async {
    final storage = ref.read(secureTokenStorageProvider);
    if (event.isLogout) {
      ref.read(webSocketManagerProvider).disconnect();
      await storage.clearTokens();
      clearCachedToken();
      state = const AsyncData(AuthState.unauthenticated);
      return;
    }

    final accessToken = event.accessToken;
    final refreshToken = event.refreshToken;
    if (accessToken == null || refreshToken == null) {
      return;
    }

    await _applyAuthResponse(
      AuthResponse(
        accessToken: accessToken,
        refreshToken: refreshToken,
        user:
            state.valueOrNull?.user ??
            const UserInfo(id: '', email: '', name: '', roles: []),
      ),
      publishSync: false,
      connectSocketOnly: true,
    );

    if (state.valueOrNull?.status == AuthStatus.authenticated &&
        state.valueOrNull?.user != null &&
        state.valueOrNull!.user!.id.isNotEmpty) {
      return;
    }

    try {
      final authResponse = await ref
          .read(authRepositoryProvider)
          .refresh(refreshToken);
      await _applyAuthResponse(authResponse, publishSync: false);
      state = AsyncData(await _buildAuthenticatedState(authResponse.user));
    } catch (_) {
      // Keep synced tokens so the tab can retry later without forcing logout.
    }
  }

  Future<void> _applyAuthResponse(
    AuthResponse authResponse, {
    required bool publishSync,
    bool connectSocketOnly = false,
  }) async {
    final storage = ref.read(secureTokenStorageProvider);
    await storage.saveTokens(
      accessToken: authResponse.accessToken,
      refreshToken: authResponse.refreshToken,
    );
    if (publishSync) {
      await ref
          .read(authTokenSyncProvider)
          .publishTokens(
            accessToken: authResponse.accessToken,
            refreshToken: authResponse.refreshToken,
          );
    }
    _connectWebSocket(authResponse.accessToken);
    if (connectSocketOnly) {
      return;
    }
  }

  Future<AuthState> _buildAuthenticatedState(UserInfo user) async {
    final repo = ref.read(authRepositoryProvider);
    try {
      final config = await repo.getBootstrapConfig();
      final mergedUser = user.copyWith(phoneNumber: config.phoneNumber);
      return AuthState(
        status: AuthStatus.authenticated,
        user: mergedUser,
        points: config.points,
        payrollStartConfig: config.payrollStartConfig,
        configRoles: config.roles,
        bootstrapStatus: config.phoneNumber == null
            ? AuthBootstrapStatus.phoneRequired
            : AuthBootstrapStatus.ready,
      );
    } on DioException catch (e) {
      return AuthState(
        status: AuthStatus.authenticated,
        user: user,
        bootstrapStatus: AuthBootstrapStatus.error,
        bootstrapErrorMessage: _extractDioErrorMessage(
          e,
          fallback: 'Không thể tải cấu hình khởi tạo.',
        ),
      );
    } catch (e) {
      return AuthState(
        status: AuthStatus.authenticated,
        user: user,
        bootstrapStatus: AuthBootstrapStatus.error,
        bootstrapErrorMessage: 'Không thể tải cấu hình khởi tạo: $e',
      );
    }
  }

  static String _deviceNameForCurrentPlatform() {
    if (kIsWeb) return 'web';

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  @override
  Future<AuthState> build() async {
    _bindAuthTokenSync();
    _bindRewardPointsRealtime();
    final storage = ref.read(secureTokenStorageProvider);
    final refreshToken = await storage.getRefreshToken();
    if (refreshToken == null) return AuthState.unauthenticated;

    try {
      final repo = ref.read(authRepositoryProvider);
      final authResponse = await repo.refresh(refreshToken);
      await _applyAuthResponse(authResponse, publishSync: false);
      final nextState = await _buildAuthenticatedState(authResponse.user);
      unawaited(resyncRewardWallet());
      return nextState;
    } catch (_) {
      await storage.clearTokens();
      clearCachedToken();
      return AuthState.unauthenticated;
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(authRepositoryProvider);
      final storage = ref.read(secureTokenStorageProvider);
      final deviceId = await storage.getOrCreateDeviceId();
      final result = await repo.login(
        email: email,
        password: password,
        deviceId: deviceId,
        deviceName: _deviceNameForCurrentPlatform(),
      );
      await _applyAuthResponse(result, publishSync: true);
      state = AsyncData(await _buildAuthenticatedState(result.user));
      unawaited(resyncRewardWallet());
    } on DioException catch (e, st) {
      state = AsyncError(
        _extractDioErrorMessage(e, fallback: 'Đăng nhập thất bại'),
        st,
      );
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<UserInfo> updateProfile({
    String? name,
    Object? avatarUrl = _profileUnsetField,
    Object? phoneNumber = _profileUnsetField,
  }) async {
    final currentState = state.valueOrNull;
    final currentUser = currentState?.user;
    if (currentState == null || currentUser == null) {
      throw StateError('Chưa có phiên đăng nhập để cập nhật hồ sơ.');
    }

    final repo = ref.read(authRepositoryProvider);
    final updatedUser = await repo.updateMe(
      name: name,
      avatarUrl: avatarUrl,
      phoneNumber: phoneNumber,
    );
    final mergedUser = updatedUser.copyWith(
      roles: updatedUser.roles.isEmpty ? currentUser.roles : updatedUser.roles,
    );

    state = AsyncData(
      currentState.copyWith(
        user: mergedUser,
        bootstrapStatus:
            (mergedUser.phoneNumber != null &&
                mergedUser.phoneNumber!.isNotEmpty)
            ? AuthBootstrapStatus.ready
            : currentState.bootstrapStatus,
        bootstrapErrorMessage: null,
      ),
    );
    return mergedUser;
  }

  Future<UserInfo> updateDisplayName(String name) async {
    return updateProfile(name: name);
  }

  Future<UserInfo> updatePhoneNumber(String phoneNumber) {
    return updateProfile(phoneNumber: phoneNumber);
  }

  Future<UserInfo> uploadAvatar(XFile file) async {
    final currentState = state.valueOrNull;
    final currentUser = currentState?.user;
    if (currentState == null || currentUser == null) {
      throw StateError('Chưa có phiên đăng nhập để cập nhật avatar.');
    }

    final repo = ref.read(authRepositoryProvider);
    final updatedUser = await repo.uploadMyAvatar(file);
    final mergedUser = updatedUser.copyWith(
      roles: updatedUser.roles.isEmpty ? currentUser.roles : updatedUser.roles,
    );

    state = AsyncData(currentState.copyWith(user: mergedUser));
    return mergedUser;
  }

  Future<void> retryBootstrapConfig() async {
    final currentState = state.valueOrNull;
    final currentUser = currentState?.user;
    if (currentState == null ||
        currentState.status != AuthStatus.authenticated ||
        currentUser == null) {
      return;
    }

    state = AsyncData(
      currentState.copyWith(
        bootstrapStatus: AuthBootstrapStatus.pending,
        bootstrapErrorMessage: null,
      ),
    );
    state = AsyncData(await _buildAuthenticatedState(currentUser));
  }

  Future<void> resyncRewardWallet({bool force = false}) async {
    final currentState = state.valueOrNull;
    if (currentState == null ||
        currentState.status != AuthStatus.authenticated ||
        currentState.user == null) {
      return;
    }

    if (!force && _walletResyncInFlight != null) {
      return _walletResyncInFlight;
    }

    final future = _performRewardWalletResync();
    _walletResyncInFlight = future;
    try {
      await future;
    } finally {
      if (identical(_walletResyncInFlight, future)) {
        _walletResyncInFlight = null;
      }
    }
  }

  Future<void> ensureRewardWalletFresh({
    Duration maxAge = const Duration(seconds: 45),
  }) async {
    final lastSyncAt = _lastRewardWalletSyncAt;
    if (lastSyncAt != null &&
        DateTime.now().difference(lastSyncAt) < maxAge) {
      return;
    }
    await resyncRewardWallet();
  }

  Future<void> _performRewardWalletResync() async {
    try {
      final wallet = await ref.read(authRepositoryProvider).getRewardWallet();
      _lastRewardWalletSyncAt = DateTime.now();
      _updatePoints(wallet.balance);
    } catch (error) {
      debugPrint('[Rewards] Wallet resync failed: $error');
    }
  }

  Future<void> logout() async {
    ref.read(webSocketManagerProvider).disconnect();
    final storage = ref.read(secureTokenStorageProvider);
    final refreshToken = await storage.getRefreshToken();
    final pushNotificationService = ref.read(pushNotificationServiceProvider);
    try {
      await pushNotificationService.clearServerToken();
    } catch (_) {
      // Best-effort FCM cleanup on server
    }
    if (refreshToken != null) {
      try {
        final repo = ref.read(authRepositoryProvider);
        await repo.logout(refreshToken);
      } catch (_) {
        // Best-effort logout on server
      }
    }
    await pushNotificationService.reset();
    await storage.clearTokens();
    await ref.read(authTokenSyncProvider).publishLogout();
    clearCachedToken();
    state = const AsyncData(AuthState(status: AuthStatus.unauthenticated));
  }
}

void scheduleRewardWalletFreshnessCheck(
  WidgetRef ref, {
  Duration maxAge = const Duration(seconds: 45),
}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(
      ref
          .read(authNotifierProvider.notifier)
          .ensureRewardWalletFresh(maxAge: maxAge),
    );
  });
}

const Object _profileUnsetField = Object();

String _extractDioErrorMessage(DioException error, {required String fallback}) {
  final data = error.response?.data;
  if (data is Map) {
    final message = _normalizeErrorMessage(data['message']);
    if (message != null) return message;

    final errorDetail = _normalizeErrorMessage(data['error']);
    if (errorDetail != null) return errorDetail;
  }

  return _normalizeErrorMessage(error.message) ?? fallback;
}

String? _normalizeErrorMessage(Object? value) {
  if (value == null) return null;

  if (value is String) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  if (value is Iterable) {
    final parts = value
        .map(_normalizeErrorMessage)
        .whereType<String>()
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    return parts.isEmpty ? null : parts.join('\n');
  }

  if (value is Map) {
    final parts = value.values
        .map(_normalizeErrorMessage)
        .whereType<String>()
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    return parts.isEmpty ? null : parts.join('\n');
  }

  final normalized = value.toString().trim();
  return normalized.isEmpty ? null : normalized;
}
