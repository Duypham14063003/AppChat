import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nineteen_tech_app/features/auth/data/auth_interceptor.dart';
import 'package:nineteen_tech_app/features/auth/data/secure_token_storage.dart';

void main() {
  group('AuthInterceptor', () {
    test(
      'syncs refreshed access token for WebSocket auth handshakes',
      () async {
        final adapter = _RefreshAdapter();
        final storage = _FakeSecureTokenStorage(
          accessToken: 'old-access',
          refreshToken: 'refresh-token',
        );
        String? refreshedToken;
        var authFailures = 0;

        Dio dioFactory(BaseOptions options) {
          final dio = Dio(options);
          dio.httpClientAdapter = adapter;
          return dio;
        }

        final dio = dioFactory(BaseOptions(baseUrl: 'https://api.test'));
        dio.interceptors.add(
          AuthInterceptor(
            tokenStorage: storage,
            onAuthFailure: () => authFailures++,
            onTokenRefresh: (token) => refreshedToken = token,
            dioFactory: dioFactory,
          ),
        );

        final response = await dio.get<Map<String, dynamic>>('/protected');

        expect(response.statusCode, 200);
        expect(response.data?['ok'], isTrue);
        expect(await storage.getAccessToken(), 'new-access');
        expect(await storage.getRefreshToken(), 'new-refresh');
        expect(refreshedToken, 'new-access');
        expect(authFailures, 0);
        expect(adapter.refreshCalls, 1);
        expect(adapter.protectedCalls, 2);
      },
    );

    test(
      'keeps tokens when refresh fails because of a transient transport error',
      () async {
        final adapter = _RefreshAdapter(
          refreshMode: _RefreshMode.transportFailure,
        );
        final storage = _FakeSecureTokenStorage(
          accessToken: 'old-access',
          refreshToken: 'refresh-token',
        );
        var authFailures = 0;

        Dio dioFactory(BaseOptions options) {
          final dio = Dio(options);
          dio.httpClientAdapter = adapter;
          return dio;
        }

        final dio = dioFactory(BaseOptions(baseUrl: 'https://api.test'));
        dio.interceptors.add(
          AuthInterceptor(
            tokenStorage: storage,
            onAuthFailure: () => authFailures++,
            dioFactory: dioFactory,
          ),
        );

        await expectLater(
          dio.get<Map<String, dynamic>>('/protected'),
          throwsA(isA<DioException>()),
        );

        expect(await storage.getAccessToken(), 'old-access');
        expect(await storage.getRefreshToken(), 'refresh-token');
        expect(storage.clearCalls, 0);
        expect(authFailures, 0);
        expect(adapter.refreshCalls, 1);
      },
    );

    test(
      'clears tokens when refresh fails because the session is invalid',
      () async {
        final adapter = _RefreshAdapter(
          refreshMode: _RefreshMode.invalidSession,
        );
        final storage = _FakeSecureTokenStorage(
          accessToken: 'old-access',
          refreshToken: 'refresh-token',
        );
        var authFailures = 0;

        Dio dioFactory(BaseOptions options) {
          final dio = Dio(options);
          dio.httpClientAdapter = adapter;
          return dio;
        }

        final dio = dioFactory(BaseOptions(baseUrl: 'https://api.test'));
        dio.interceptors.add(
          AuthInterceptor(
            tokenStorage: storage,
            onAuthFailure: () => authFailures++,
            dioFactory: dioFactory,
          ),
        );

        await expectLater(
          dio.get<Map<String, dynamic>>('/protected'),
          throwsA(isA<DioException>()),
        );

        expect(await storage.getAccessToken(), isNull);
        expect(await storage.getRefreshToken(), isNull);
        expect(storage.clearCalls, 1);
        expect(authFailures, 1);
        expect(adapter.refreshCalls, 1);
      },
    );
  });
}

class _RefreshAdapter implements HttpClientAdapter {
  _RefreshAdapter({this.refreshMode = _RefreshMode.success});

  int protectedCalls = 0;
  int refreshCalls = 0;
  final _RefreshMode refreshMode;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == '/auth/refresh') {
      refreshCalls++;
      if (refreshMode == _RefreshMode.transportFailure) {
        throw DioException.connectionTimeout(
          timeout: const Duration(seconds: 10),
          requestOptions: options,
        );
      }
      if (refreshMode == _RefreshMode.invalidSession) {
        return _jsonResponse(401, {
          'message': 'Session expired, please login again',
        });
      }
      return _jsonResponse(200, {
        'accessToken': 'new-access',
        'refreshToken': 'new-refresh',
        'user': {
          'id': 'user-1',
          'email': 'duy@example.com',
          'name': 'Pham Ngoc Duy',
          'roles': ['employee'],
        },
      });
    }

    if (options.path == '/protected') {
      protectedCalls++;
      final authorization = options.headers['Authorization'];
      if (authorization == 'Bearer new-access') {
        return _jsonResponse(200, {'ok': true});
      }
      return _jsonResponse(401, {'message': 'Unauthorized'});
    }

    return _jsonResponse(404, {'message': 'Not found'});
  }

  ResponseBody _jsonResponse(int statusCode, Map<String, dynamic> body) {
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

enum _RefreshMode { success, transportFailure, invalidSession }

class _FakeSecureTokenStorage extends SecureTokenStorage {
  _FakeSecureTokenStorage({String? accessToken, String? refreshToken})
    : _accessToken = accessToken,
      _refreshToken = refreshToken,
      super();

  String? _accessToken;
  String? _refreshToken;
  int clearCalls = 0;

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
    clearCalls++;
    _accessToken = null;
    _refreshToken = null;
  }
}
