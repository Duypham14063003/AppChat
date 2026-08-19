import 'dart:async';
import 'package:dio/dio.dart';
import 'package:nineteen_tech_app/features/auth/data/auth_repository.dart';
import 'package:nineteen_tech_app/features/auth/data/secure_token_storage.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.tokenStorage,
    required this.onAuthFailure,
    this.onTokenRefresh,
    this.onTokensUpdated,
    Dio Function(BaseOptions options)? dioFactory,
  }) : _dioFactory = dioFactory ?? Dio.new;

  final SecureTokenStorage tokenStorage;
  final VoidCallback onAuthFailure;
  final void Function(String token)? onTokenRefresh;
  final FutureOr<void> Function({
    required String accessToken,
    required String refreshToken,
  })?
  onTokensUpdated;
  final Dio Function(BaseOptions options) _dioFactory;

  bool _isRefreshing = false;
  final _pendingRequests =
      <
        ({
          Completer<void> completer,
          RequestOptions options,
          ErrorInterceptorHandler handler,
        })
      >[];

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await tokenStorage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }

    // Don't retry refresh or login/logout endpoints
    final path = err.requestOptions.path;
    if (path.contains('/auth/refresh') ||
        path.contains('/auth/login') ||
        path.contains('/auth/logout')) {
      return handler.next(err);
    }

    if (_isRefreshing) {
      // Queue this request until refresh completes
      final completer = Completer<void>();
      _pendingRequests.add((
        completer: completer,
        options: err.requestOptions,
        handler: handler,
      ));
      await completer.future;
      return;
    }

    _isRefreshing = true;

    try {
      final refreshToken = await tokenStorage.getRefreshToken();
      if (refreshToken == null) {
        _failAll(err);
        onAuthFailure();
        return handler.next(err);
      }

      // Create a plain Dio to avoid interceptor loop
      final plainDio = _dioFactory(
        BaseOptions(baseUrl: err.requestOptions.baseUrl),
      );
      final response = await plainDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );

      final authResponse = AuthResponse.fromJson(response.data!);
      await tokenStorage.saveTokens(
        accessToken: authResponse.accessToken,
        refreshToken: authResponse.refreshToken,
      );
      onTokenRefresh?.call(authResponse.accessToken);
      await onTokensUpdated?.call(
        accessToken: authResponse.accessToken,
        refreshToken: authResponse.refreshToken,
      );

      // Retry original request
      err.requestOptions.headers['Authorization'] =
          'Bearer ${authResponse.accessToken}';
      final retryResponse = await _dioFactory(
        BaseOptions(),
      ).fetch(err.requestOptions);
      handler.resolve(retryResponse);

      // Retry queued requests
      _retryAll(authResponse.accessToken);
    } catch (refreshError) {
      final refreshException = refreshError is DioException
          ? refreshError
          : DioException(
              requestOptions: err.requestOptions,
              error: refreshError,
            );
      _failAll(refreshException);
      if (_isHardRefreshFailure(refreshException)) {
        await tokenStorage.clearTokens();
        onAuthFailure();
      }
      handler.next(refreshException);
    } finally {
      _isRefreshing = false;
    }
  }

  void _retryAll(String newAccessToken) {
    for (final pending in _pendingRequests) {
      pending.options.headers['Authorization'] = 'Bearer $newAccessToken';
      _dioFactory(BaseOptions())
          .fetch(pending.options)
          .then(
            (response) => pending.handler.resolve(response),
            onError: (Object e) => pending.handler.next(
              e is DioException
                  ? e
                  : DioException(requestOptions: pending.options, error: e),
            ),
          );
      pending.completer.complete();
    }
    _pendingRequests.clear();
  }

  void _failAll(DioException err) {
    for (final pending in _pendingRequests) {
      pending.handler.next(err);
      pending.completer.complete();
    }
    _pendingRequests.clear();
  }

  bool _isHardRefreshFailure(DioException error) {
    final statusCode = error.response?.statusCode;
    if (statusCode == 401) {
      return true;
    }

    final message = _extractErrorMessage(error).toLowerCase();
    return message.contains('session expired') ||
        message.contains('login again') ||
        message.contains('invalid refresh') ||
        message.contains('invalid session');
  }

  String _extractErrorMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final message = _normalizeMessage(data['message']);
      if (message != null) {
        return message;
      }

      final detail = _normalizeMessage(data['error']);
      if (detail != null) {
        return detail;
      }
    }

    return error.message ?? '';
  }

  String? _normalizeMessage(Object? value) {
    if (value == null) {
      return null;
    }

    if (value is String) {
      final normalized = value.trim();
      return normalized.isEmpty ? null : normalized;
    }

    if (value is Iterable) {
      final parts = value
          .map(_normalizeMessage)
          .whereType<String>()
          .where((part) => part.isNotEmpty)
          .toList(growable: false);
      return parts.isEmpty ? null : parts.join('\n');
    }

    if (value is Map) {
      final parts = value.values
          .map(_normalizeMessage)
          .whereType<String>()
          .where((part) => part.isNotEmpty)
          .toList(growable: false);
      return parts.isEmpty ? null : parts.join('\n');
    }

    final normalized = value.toString().trim();
    return normalized.isEmpty ? null : normalized;
  }
}

typedef VoidCallback = void Function();
