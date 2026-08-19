import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum WsConnectionState { disconnected, connecting, connected }

typedef WsEventHandler = void Function(Map<String, dynamic> data);

class WsDebugLogEntry {
  const WsDebugLogEntry({
    required this.timestamp,
    required this.message,
    required this.state,
  });

  final DateTime timestamp;
  final String message;
  final WsConnectionState state;
}

/// Optional async callback to refresh the auth token before reconnecting.
/// Returns the refreshed access token, or `null` if refresh failed.
typedef WsTokenRefresher = Future<String?> Function();

class WebSocketManager {
  final String baseUrl;
  final String Function() tokenProvider;

  /// When set, the manager will call this to refresh the token before
  /// reconnecting so that expired cached tokens don't cause auth loops.
  WsTokenRefresher? tokenRefresher;

  WebSocketChannel? _channel;
  WsConnectionState _state = WsConnectionState.disconnected;
  final _stateController = StreamController<WsConnectionState>.broadcast();
  final _debugLogController = StreamController<WsDebugLogEntry>.broadcast();
  final Map<String, List<WsEventHandler>> _handlers = {};
  int _reconnectAttempt = 0;
  Timer? _reconnectTimer;
  DateTime? _lastSyncedAt;
  bool _intentionalDisconnect = false;
  bool _isDisposed = false;

  // --- Ping / Pong heartbeat (Application-level JSON ping/pong) ---
  // Flutter gửi: {"event":"ping","data":{}}
  // Backend trả: {"event":"pong","data":{}}
  // Backend cũng có native WS heartbeat riêng (socket.ping() mỗi 30s).
  static const _pingInterval = Duration(seconds: 25);
  static const _pongTimeout = Duration(seconds: 10);
  Timer? _pingTimer;
  Timer? _pongTimer;

  // --- Connection timeout ---
  static const _connectTimeout = Duration(seconds: 15);
  Timer? _connectTimeoutTimer;

  WebSocketManager({required this.baseUrl, required this.tokenProvider});

  Stream<WsConnectionState> get stateStream => _stateController.stream;
  Stream<WsDebugLogEntry> get debugLogStream => _debugLogController.stream;
  WsConnectionState get state => _state;

  void _log(String message) {
    debugPrint('[WS] $message');
    if (_debugLogController.isClosed) return;
    _debugLogController.add(
      WsDebugLogEntry(
        timestamp: DateTime.now(),
        message: message,
        state: _state,
      ),
    );
  }

  void connect() {
    if (_isDisposed) return;
    // If already connecting for too long, force-reset and retry.
    if (_state == WsConnectionState.connecting) return;
    if (_state == WsConnectionState.connected && _channel != null) return;
    _intentionalDisconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _setState(WsConnectionState.connecting);

    _startConnectTimeout();

    try {
      final wsUrl = baseUrl.replaceFirst('http', 'ws');
      _log('Connecting to $wsUrl/ws');
      _channel = WebSocketChannel.connect(Uri.parse('$wsUrl/ws'));

      _channel!.stream.listen(
        _onMessage,
        onError: (error) {
          _log('Stream error: $error');
          _onDisconnect();
        },
        onDone: _onDisconnect,
      );

      // Send auth message
      _send('auth', {'token': tokenProvider()});
    } catch (e) {
      _log('Connect failed: $e');
      _onDisconnect();
    }
  }

  // --- Connect timeout ---

  void _startConnectTimeout() {
    _connectTimeoutTimer?.cancel();
    _connectTimeoutTimer = Timer(_connectTimeout, () {
      if (_state == WsConnectionState.connecting) {
        _log('Connect timeout - forcing disconnect');
        _forceCloseChannel();
        _onDisconnect();
      }
    });
  }

  void _cancelConnectTimeout() {
    _connectTimeoutTimer?.cancel();
    _connectTimeoutTimer = null;
  }

  // --- Ping / Pong heartbeat ---

  void _startPingPong() {
    _stopPingPong();
    _pingTimer = Timer.periodic(_pingInterval, (_) {
      if (_state != WsConnectionState.connected || _channel == null) {
        _stopPingPong();
        return;
      }
      _send('ping', {});
      _pongTimer?.cancel();
      _pongTimer = Timer(_pongTimeout, () {
        _log('Pong timeout - forcing reconnect');
        _forceCloseChannel();
        _onDisconnect();
      });
    });
  }

  void _stopPingPong() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _pongTimer?.cancel();
    _pongTimer = null;
  }

  void _forceCloseChannel() {
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  void _onMessage(dynamic raw) {
    try {
      final envelope = jsonDecode(raw as String) as Map<String, dynamic>;
      final event = envelope['event'] as String?;
      final data = envelope['data'] as Map<String, dynamic>? ?? {};

      // Handle pong — cancel the pong timeout timer
      if (event == 'pong') {
        _pongTimer?.cancel();
        _pongTimer = null;
        return;
      }

      if (event == 'auth_success') {
        _log('Auth success');
        _cancelConnectTimeout();
        _setState(WsConnectionState.connected);
        _reconnectAttempt = 0;
        _startPingPong();
        // Sync missed messages
        if (_lastSyncedAt != null) {
          _send('sync', {'last_synced_at': _lastSyncedAt!.toIso8601String()});
        }
        _lastSyncedAt = DateTime.now();
        return;
      }

      if (event == 'auth_error') {
        _log('Auth error: ${data['message']}');
        _cancelConnectTimeout();
        _forceCloseChannel();
        // Không reconnect ngay — token có thể đã hết hạn.
        // Thử refresh token trước rồi mới reconnect.
        _onAuthError();
        return;
      }

      // Dispatch to registered handlers
      if (event != null) {
        final handlers = _handlers[event];
        if (handlers != null) {
          for (final handler in handlers) {
            handler(data);
          }
        }
      }
    } catch (e) {
      _log('Message parse error: $e');
    }
  }

  void _onDisconnect() {
    if (_isDisposed) return;
    _cancelConnectTimeout();
    _stopPingPong();
    _channel = null;
    _setState(WsConnectionState.disconnected);
    if (!_intentionalDisconnect) {
      _scheduleReconnect();
    }
  }

  /// Được gọi khi server trả về auth_error.
  /// Thử refresh token trước rồi mới reconnect để tránh vòng lặp
  /// reconnect liên tục với token đã hết hạn.
  Future<void> _onAuthError() async {
    _channel = null;
    _setState(WsConnectionState.disconnected);
    if (_isDisposed || _intentionalDisconnect) return;
    final refresher = tokenRefresher;
    if (refresher != null) {
      try {
        final newToken = await refresher();
        if (newToken != null && newToken.isNotEmpty) {
          _log('Token refreshed after auth_error - reconnecting');
          _reconnectAttempt = 0;
          _scheduleReconnect();
          return;
        }
      } catch (e) {
        _log('Token refresh failed after auth_error: $e');
      }
    }
    // Không có refresher hoặc refresh thất bại → dừng reconnect
    _log('Auth error - no valid token available, stopping reconnect');
    _intentionalDisconnect = true;
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final delay = min(pow(2, _reconnectAttempt).toInt(), 30);
    _reconnectAttempt++;
    _log('Reconnecting in ${delay}s (attempt $_reconnectAttempt)');
    _reconnectTimer = Timer(Duration(seconds: delay), _reconnect);
  }

  /// Reconnect with optional token refresh to avoid expired-token loops.
  Future<void> _reconnect() async {
    if (_isDisposed || _intentionalDisconnect) return;
    final refresher = tokenRefresher;
    if (refresher != null && _reconnectAttempt > 1) {
      try {
        final newToken = await refresher();
        if (newToken != null) {
          _log('Token refreshed before reconnect');
        }
      } catch (e) {
        _log('Token refresh failed before reconnect: $e');
      }
    }
    connect();
  }

  void _setState(WsConnectionState newState) {
    final oldState = _state;
    _state = newState;
    _log('State: ${oldState.name} -> ${newState.name}');
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  bool _send(String event, Map<String, dynamic> data, {String? id}) {
    if (_channel == null) {
      _log('Message dropped (no channel): $event');
      return false;
    }
    final envelope = <String, dynamic>{'event': event, 'data': data};
    if (id != null) envelope['id'] = id;
    try {
      _channel!.sink.add(jsonEncode(envelope));
    } catch (e) {
      _log('Send failed: $e');
      return false;
    }
    return true;
  }

  // --- Public API ---

  /// Ensures the WebSocket is connected. If currently disconnected, starts
  /// a new connection. If stuck in `connecting` for too long, forces a reset.
  void ensureConnected() {
    if (state == WsConnectionState.disconnected) {
      connect();
    } else if (state == WsConnectionState.connecting) {
      // The connect timeout timer will handle the stuck case.
      // If no timer is running (shouldn't happen), start one now.
      _connectTimeoutTimer ??= Timer(_connectTimeout, () {
        if (_state == WsConnectionState.connecting) {
          _log('ensureConnected: connecting stuck - forcing reset');
          _forceCloseChannel();
          _onDisconnect();
        }
      });
    }
  }

  /// Called when network connectivity changes to immediately reconnect.
  void onNetworkRestored() {
    if (_isDisposed || _intentionalDisconnect) return;
    if (_state == WsConnectionState.connected) return;
    _log('Network restored - reconnecting immediately');
    _reconnectAttempt = 0;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    // Force-close any zombie channel
    if (_state == WsConnectionState.connecting) {
      _cancelConnectTimeout();
      _forceCloseChannel();
      _state = WsConnectionState.disconnected;
    }
    connect();
  }

  bool sendMessage(Map<String, dynamic> data, {String? id}) {
    return _send('send_message', data, id: id);
  }

  bool sendMarkRead(String convId, String messageId) {
    return _send('mark_read', {'conv_id': convId, 'message_id': messageId});
  }

  bool sendMarkDelivered(String convId, String messageId, String senderId) {
    return _send('mark_delivered', {
      'conv_id': convId,
      'message_id': messageId,
      'sender_id': senderId,
    });
  }

  bool sendToggleReaction(String convId, String messageId, String emoji) {
    return _send('toggle_reaction', {
      'conv_id': convId,
      'message_id': messageId,
      'emoji': emoji,
    });
  }

  bool sendTyping(String convId) {
    return _send('typing', {'conv_id': convId});
  }

  bool sendForward(
    List<String> messageIds,
    List<String> convIds,
    bool hideSender, {
    String? id,
  }) {
    return _send('forward_message', {
      'message_ids': messageIds,
      'conv_ids': convIds,
      'hide_sender': hideSender,
    }, id: id);
  }

  bool sendEditMessage({
    required String messageId,
    String? content,
    Map<String, dynamic>? metadata,
    String? id,
  }) {
    final data = <String, dynamic>{'message_id': messageId};
    if (content != null) data['content'] = content;
    if (metadata != null) data['metadata'] = metadata;
    return _send('edit_message', data, id: id);
  }

  bool sendRecallMessage({
    required String messageId,
    String? reason,
    String? id,
  }) {
    final data = <String, dynamic>{'message_id': messageId};
    if (reason != null) data['reason'] = reason;
    return _send('recall_message', data, id: id);
  }

  void on(String event, WsEventHandler handler) {
    _handlers.putIfAbsent(event, () => []).add(handler);
  }

  void off(String event, WsEventHandler handler) {
    _handlers[event]?.remove(handler);
  }

  void disconnect() {
    _intentionalDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _cancelConnectTimeout();
    _stopPingPong();
    _forceCloseChannel();
    _setState(WsConnectionState.disconnected);
  }

  void dispose() {
    _isDisposed = true;
    disconnect();
    _stateController.close();
    _debugLogController.close();
  }
}
