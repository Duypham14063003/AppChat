import 'dart:async';

class AuthTokenSyncEvent {
  const AuthTokenSyncEvent.tokens({
    required this.accessToken,
    required this.refreshToken,
  }) : isLogout = false;

  const AuthTokenSyncEvent.logout()
    : accessToken = null,
      refreshToken = null,
      isLogout = true;

  final String? accessToken;
  final String? refreshToken;
  final bool isLogout;
}

abstract class AuthTokenSync {
  Stream<AuthTokenSyncEvent> get events;

  Future<void> publishTokens({
    required String accessToken,
    required String refreshToken,
  });

  Future<void> publishLogout();

  void dispose();
}

AuthTokenSync createAuthTokenSync() => _NoopAuthTokenSync();

class _NoopAuthTokenSync implements AuthTokenSync {
  final _controller = StreamController<AuthTokenSyncEvent>.broadcast();

  @override
  Stream<AuthTokenSyncEvent> get events => _controller.stream;

  @override
  Future<void> publishTokens({
    required String accessToken,
    required String refreshToken,
  }) async {}

  @override
  Future<void> publishLogout() async {}

  @override
  void dispose() {
    _controller.close();
  }
}
