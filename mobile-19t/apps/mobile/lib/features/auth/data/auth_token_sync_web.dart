// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'package:uuid/uuid.dart';

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

AuthTokenSync createAuthTokenSync() => _WebAuthTokenSync();

class _WebAuthTokenSync implements AuthTokenSync {
  _WebAuthTokenSync() {
    _subscription = html.window.onStorage.listen(_handleStorageEvent);
  }

  static const _storageKey = 'nineteen_auth_token_sync';
  static const _uuid = Uuid();

  final _controller = StreamController<AuthTokenSyncEvent>.broadcast();
  final _tabId = _uuid.v4();
  late final StreamSubscription<html.StorageEvent> _subscription;

  @override
  Stream<AuthTokenSyncEvent> get events => _controller.stream;

  @override
  Future<void> publishTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _writePayload({
      'type': 'tokens',
      'accessToken': accessToken,
      'refreshToken': refreshToken,
    });
  }

  @override
  Future<void> publishLogout() async {
    _writePayload({'type': 'logout'});
  }

  @override
  void dispose() {
    _subscription.cancel();
    _controller.close();
  }

  void _writePayload(Map<String, Object?> payload) {
    html.window.localStorage[_storageKey] = jsonEncode({
      ...payload,
      'senderId': _tabId,
      'sentAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void _handleStorageEvent(html.StorageEvent event) {
    if (event.key != _storageKey || event.newValue == null) {
      return;
    }

    final decoded = jsonDecode(event.newValue!);
    if (decoded is! Map<String, dynamic>) {
      return;
    }
    if (decoded['senderId'] == _tabId) {
      return;
    }

    final type = decoded['type'];
    if (type == 'logout') {
      _controller.add(const AuthTokenSyncEvent.logout());
      return;
    }

    if (type == 'tokens') {
      final accessToken = decoded['accessToken'];
      final refreshToken = decoded['refreshToken'];
      if (accessToken is String && refreshToken is String) {
        _controller.add(
          AuthTokenSyncEvent.tokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
          ),
        );
      }
    }
  }
}
