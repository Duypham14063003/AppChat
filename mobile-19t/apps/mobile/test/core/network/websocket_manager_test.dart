import 'package:flutter_test/flutter_test.dart';
import 'package:nineteen_tech_app/core/network/websocket_manager.dart';

void main() {
  group('WebSocketManager.ensureConnected', () {
    test('connects when disconnected', () {
      final manager = _FakeWebSocketManager(WsConnectionState.disconnected);

      manager.ensureConnected();

      expect(manager.connectCount, 1);
    });

    test('does not start a duplicate connection while connecting', () {
      final manager = _FakeWebSocketManager(WsConnectionState.connecting);

      manager.ensureConnected();

      expect(manager.connectCount, 0);
    });

    test('does not restart an active connection', () {
      final manager = _FakeWebSocketManager(WsConnectionState.connected);

      manager.ensureConnected();

      expect(manager.connectCount, 0);
    });
  });
}

class _FakeWebSocketManager extends WebSocketManager {
  _FakeWebSocketManager(this._state)
    : super(baseUrl: 'https://example.com', tokenProvider: () => '');

  final WsConnectionState _state;
  int connectCount = 0;

  @override
  WsConnectionState get state => _state;

  @override
  void connect() {
    connectCount++;
  }
}
