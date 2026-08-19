import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nineteen_tech_app/core/network/websocket_manager.dart';
import 'package:nineteen_tech_app/core/network/websocket_provider.dart';
import 'package:nineteen_tech_app/features/auth/data/auth_repository.dart';
import 'package:nineteen_tech_app/features/auth/data/secure_token_storage.dart';
import 'package:nineteen_tech_app/features/auth/data/auth_token_sync.dart';
import 'package:nineteen_tech_app/features/auth/providers/auth_notifier.dart';

void main() {
  group('AuthResponse', () {
    test('parses full user payload from backend', () {
      final response = AuthResponse.fromJson({
        'accessToken': 'access-token',
        'refreshToken': 'refresh-token',
        'user': {
          'id': 'user-1',
          'email': 'duy@example.com',
          'name': 'Pham Ngoc Duy',
          'department': 'Inhouse',
          'jobTitle': 'Fullstack Developer',
          'employmentStatus': 'official',
          'avatarUrl': '/uploads/avatar.png',
          'roles': ['employee'],
        },
      });

      expect(response.user.name, 'Pham Ngoc Duy');
      expect(response.user.department, 'Inhouse');
      expect(response.user.jobTitle, 'Fullstack Developer');
      expect(response.user.employmentStatus, 'official');
      expect(response.user.avatarUrl, contains('/uploads/avatar.png'));
      expect(response.user.roles, ['employee']);
    });
  });

  group('authNotifierProvider', () {
    test(
      'login success hydrates full user profile from backend response',
      () async {
        final repo = _FakeAuthRepository(
          loginResponse: const AuthResponse(
            accessToken: 'login-access',
            refreshToken: 'login-refresh',
            user: UserInfo(
              id: 'user-1',
              email: 'duy@example.com',
              name: 'Pham Ngoc Duy',
              department: 'Inhouse',
              jobTitle: 'Fullstack Developer',
              employmentStatus: 'official',
              avatarUrl: 'https://cdn.example.com/avatar.png',
              roles: ['employee'],
            ),
          ),
        );
        final storage = _FakeSecureTokenStorage();
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(repo),
            secureTokenStorageProvider.overrideWithValue(storage),
            webSocketManagerProvider.overrideWithValue(_FakeWebSocketManager()),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(authNotifierProvider.notifier)
            .login(email: 'duy@example.com', password: 'secret');

        final authState = container.read(authNotifierProvider).valueOrNull;
        expect(authState?.status, AuthStatus.authenticated);
        expect(authState?.user?.name, 'Pham Ngoc Duy');
        expect(authState?.user?.department, 'Inhouse');
        expect(authState?.user?.jobTitle, 'Fullstack Developer');
        expect(
          authState?.user?.avatarUrl,
          'https://cdn.example.com/avatar.png',
        );
        expect(authState?.user?.employmentStatus, 'official');
        expect(await storage.getAccessToken(), 'login-access');
        expect(await storage.getRefreshToken(), 'login-refresh');
      },
    );

    test(
      'login failure with list message returns AsyncError instead of hanging',
      () async {
        final repo = _FakeAuthRepository(
          loginError: DioException(
            requestOptions: RequestOptions(path: '/auth/login'),
            response: Response(
              requestOptions: RequestOptions(path: '/auth/login'),
              statusCode: 400,
              data: {
                'message': ['email must be an email'],
                'error': 'Bad Request',
              },
            ),
          ),
        );
        final storage = _FakeSecureTokenStorage();
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(repo),
            secureTokenStorageProvider.overrideWithValue(storage),
            webSocketManagerProvider.overrideWithValue(_FakeWebSocketManager()),
          ],
        );
        addTearDown(container.dispose);

        await expectLater(
          container
              .read(authNotifierProvider.notifier)
              .login(email: 'not-an-email', password: 'secret'),
          completes,
        );

        final authState = container.read(authNotifierProvider);
        expect(authState.hasError, isTrue);
        expect(authState.error, 'email must be an email');
        expect(authState.isLoading, isFalse);
        expect(await storage.getAccessToken(), isNull);
        expect(await storage.getRefreshToken(), isNull);
      },
    );

    test('refresh success restores full user profile on cold start', () async {
      final repo = _FakeAuthRepository(
        refreshResponse: const AuthResponse(
          accessToken: 'refresh-access',
          refreshToken: 'refresh-token-new',
          user: UserInfo(
            id: 'user-1',
            email: 'duy@example.com',
            name: 'Pham Ngoc Duy',
            department: 'Inhouse',
            jobTitle: 'Fullstack Developer',
            employmentStatus: 'official',
            avatarUrl: 'https://cdn.example.com/avatar.png',
            roles: ['employee'],
          ),
        ),
      );
      final storage = _FakeSecureTokenStorage(
        refreshToken: 'refresh-token-old',
      );
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
          secureTokenStorageProvider.overrideWithValue(storage),
          webSocketManagerProvider.overrideWithValue(_FakeWebSocketManager()),
        ],
      );
      addTearDown(container.dispose);

      final authState = await container.read(authNotifierProvider.future);

      expect(authState.status, AuthStatus.authenticated);
      expect(authState.user?.name, 'Pham Ngoc Duy');
      expect(authState.user?.department, 'Inhouse');
      expect(authState.user?.jobTitle, 'Fullstack Developer');
      expect(authState.user?.avatarUrl, 'https://cdn.example.com/avatar.png');
      expect(authState.user?.employmentStatus, 'official');
      expect(await storage.getAccessToken(), 'refresh-access');
      expect(await storage.getRefreshToken(), 'refresh-token-new');
    });

    test('refresh failure clears auth state and stored tokens', () async {
      final repo = _FakeAuthRepository(
        refreshError: DioException(
          requestOptions: RequestOptions(path: '/auth/refresh'),
        ),
      );
      final storage = _FakeSecureTokenStorage(
        accessToken: 'old-access',
        refreshToken: 'bad-refresh',
      );
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
          secureTokenStorageProvider.overrideWithValue(storage),
          webSocketManagerProvider.overrideWithValue(_FakeWebSocketManager()),
        ],
      );
      addTearDown(container.dispose);

      final authState = await container.read(authNotifierProvider.future);

      expect(authState.status, AuthStatus.unauthenticated);
      expect(authState.user, isNull);
      expect(await storage.getAccessToken(), isNull);
      expect(await storage.getRefreshToken(), isNull);
    });

    test(
      'token sync event restores authenticated state in another tab',
      () async {
        final repo = _FakeAuthRepository(
          refreshResponse: const AuthResponse(
            accessToken: 'refresh-access',
            refreshToken: 'refresh-token-new',
            user: UserInfo(
              id: 'user-1',
              email: 'duy@example.com',
              name: 'Pham Ngoc Duy',
              roles: ['employee'],
            ),
          ),
        );
        final storage = _FakeSecureTokenStorage();
        final tokenSync = _FakeAuthTokenSync();
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(repo),
            secureTokenStorageProvider.overrideWithValue(storage),
            authTokenSyncProvider.overrideWithValue(tokenSync),
            webSocketManagerProvider.overrideWithValue(_FakeWebSocketManager()),
          ],
        );
        addTearDown(container.dispose);

        final initialState = await container.read(authNotifierProvider.future);
        expect(initialState.status, AuthStatus.unauthenticated);

        tokenSync.emit(
          const AuthTokenSyncEvent.tokens(
            accessToken: 'shared-access',
            refreshToken: 'shared-refresh',
          ),
        );
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final syncedState = container.read(authNotifierProvider).valueOrNull;
        expect(syncedState?.status, AuthStatus.authenticated);
        expect(syncedState?.user?.id, 'user-1');
        expect(await storage.getAccessToken(), 'refresh-access');
        expect(await storage.getRefreshToken(), 'refresh-token-new');
        expect(repo.refreshCalls, 1);
      },
    );

    test(
      'token sync logout event clears another tab without redirect loop',
      () async {
        final repo = _FakeAuthRepository(
          loginResponse: const AuthResponse(
            accessToken: 'login-access',
            refreshToken: 'login-refresh',
            user: UserInfo(
              id: 'user-1',
              email: 'duy@example.com',
              name: 'Pham Ngoc Duy',
              roles: ['employee'],
            ),
          ),
        );
        final storage = _FakeSecureTokenStorage();
        final tokenSync = _FakeAuthTokenSync();
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(repo),
            secureTokenStorageProvider.overrideWithValue(storage),
            authTokenSyncProvider.overrideWithValue(tokenSync),
            webSocketManagerProvider.overrideWithValue(_FakeWebSocketManager()),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(authNotifierProvider.notifier)
            .login(email: 'duy@example.com', password: 'secret');

        tokenSync.emit(const AuthTokenSyncEvent.logout());
        await Future<void>.delayed(Duration.zero);

        final syncedState = container.read(authNotifierProvider).valueOrNull;
        expect(syncedState?.status, AuthStatus.unauthenticated);
        expect(await storage.getAccessToken(), isNull);
        expect(await storage.getRefreshToken(), isNull);
      },
    );
  });
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository({
    this.loginResponse,
    this.loginError,
    this.refreshResponse,
    this.refreshError,
  }) : super(Dio());

  final AuthResponse? loginResponse;
  final Object? loginError;
  final AuthResponse? refreshResponse;
  final Object? refreshError;
  int refreshCalls = 0;

  @override
  Future<AuthResponse> login({
    required String email,
    required String password,
    String? deviceId,
    String? deviceName,
  }) async {
    if (loginError != null) {
      throw loginError!;
    }
    return loginResponse ??
        const AuthResponse(
          accessToken: 'default-access',
          refreshToken: 'default-refresh',
          user: UserInfo(
            id: 'user-default',
            email: 'default@example.com',
            name: 'Default User',
            roles: ['employee'],
          ),
        );
  }

  @override
  Future<AuthResponse> refresh(String refreshToken) async {
    refreshCalls++;
    if (refreshError != null) {
      throw refreshError!;
    }
    return refreshResponse ??
        const AuthResponse(
          accessToken: 'default-access',
          refreshToken: 'default-refresh',
          user: UserInfo(
            id: 'user-default',
            email: 'default@example.com',
            name: 'Default User',
            roles: ['employee'],
          ),
        );
  }
}

class _FakeSecureTokenStorage extends SecureTokenStorage {
  _FakeSecureTokenStorage({String? accessToken, String? refreshToken})
    : _accessToken = accessToken,
      _refreshToken = refreshToken,
      super();

  String? _accessToken;
  String? _refreshToken;
  String? _deviceId;

  @override
  Future<String?> getAccessToken() async => _accessToken;

  @override
  Future<String?> getRefreshToken() async => _refreshToken;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }

  @override
  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
  }

  @override
  Future<String> getOrCreateDeviceId() async {
    _deviceId ??= 'device-1';
    return _deviceId!;
  }
}

class _FakeWebSocketManager extends WebSocketManager {
  _FakeWebSocketManager()
    : super(baseUrl: 'https://example.com', tokenProvider: () => '');

  bool didConnect = false;
  bool didDisconnect = false;

  @override
  void connect() {
    didConnect = true;
  }

  @override
  void disconnect() {
    didDisconnect = true;
  }
}

class _FakeAuthTokenSync implements AuthTokenSync {
  final _controller = StreamController<AuthTokenSyncEvent>.broadcast();

  @override
  Stream<AuthTokenSyncEvent> get events => _controller.stream;

  @override
  Future<void> publishLogout() async {}

  @override
  Future<void> publishTokens({
    required String accessToken,
    required String refreshToken,
  }) async {}

  void emit(AuthTokenSyncEvent event) {
    _controller.add(event);
  }

  @override
  void dispose() {
    _controller.close();
  }
}
