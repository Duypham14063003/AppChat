import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:nineteen_tech_app/core/config/app_config.dart';
import 'package:nineteen_tech_app/features/auth/data/auth_repository.dart';
import 'package:nineteen_tech_app/features/auth/data/secure_token_storage.dart';

import 'daily_report_audit_log_models.dart';
import 'daily_report_audit_log_sse_transport.dart';
import 'daily_report_audit_log_sse_transport_base.dart';

enum DailyReportAuditLogStreamState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

sealed class DailyReportAuditLogStreamEvent {
  const DailyReportAuditLogStreamEvent();
}

class DailyReportAuditLogSnapshotStreamEvent
    extends DailyReportAuditLogStreamEvent {
  const DailyReportAuditLogSnapshotStreamEvent(this.items);

  final List<DailyReportAuditLog> items;
}

class DailyReportAuditLogInsertStreamEvent
    extends DailyReportAuditLogStreamEvent {
  const DailyReportAuditLogInsertStreamEvent(this.item);

  final DailyReportAuditLog item;
}

class DailyReportAuditLogSseService {
  DailyReportAuditLogSseService({
    required SecureTokenStorage tokenStorage,
    required AuthRepository authRepository,
  })  : _tokenStorage = tokenStorage,
        _authRepository = authRepository;

  final SecureTokenStorage _tokenStorage;
  final AuthRepository _authRepository;

  final _eventController =
      StreamController<DailyReportAuditLogStreamEvent>.broadcast();
  final _stateController =
      StreamController<DailyReportAuditLogStreamState>.broadcast();

  DailyReportAuditLogSseTransport? _transport;
  StreamSubscription<String>? _transportSubscription;
  Timer? _reconnectTimer;
  DailyReportAuditLogQuery _query = const DailyReportAuditLogQuery();
  DailyReportAuditLogStreamState _state =
      DailyReportAuditLogStreamState.disconnected;
  String _buffer = '';
  int _reconnectAttempt = 0;
  bool _shouldRun = false;
  bool _isDisposed = false;

  Stream<DailyReportAuditLogStreamEvent> get events => _eventController.stream;
  Stream<DailyReportAuditLogStreamState> get stateStream => _stateController.stream;
  DailyReportAuditLogStreamState get state => _state;

  Future<void> start({DailyReportAuditLogQuery query = const DailyReportAuditLogQuery()}) async {
    if (_isDisposed) return;
    _query = query;
    _shouldRun = true;
    _reconnectTimer?.cancel();
    await _closeTransport();
    await _connect(initial: true);
  }

  Future<void> restart({
    DailyReportAuditLogQuery query = const DailyReportAuditLogQuery(),
  }) async {
    _query = query;
    if (!_shouldRun) {
      await start(query: query);
      return;
    }
    _reconnectAttempt = 0;
    _reconnectTimer?.cancel();
    await _closeTransport();
    await _connect(initial: true);
  }

  Future<void> stop() async {
    _shouldRun = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _closeTransport();
    _setState(DailyReportAuditLogStreamState.disconnected);
  }

  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    await stop();
    await _eventController.close();
    await _stateController.close();
  }

  Future<void> _connect({required bool initial}) async {
    if (_isDisposed || !_shouldRun) return;
    _setState(
      initial
          ? DailyReportAuditLogStreamState.connecting
          : DailyReportAuditLogStreamState.reconnecting,
    );

    final token = await _tokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      _scheduleReconnect();
      return;
    }

    try {
      final transport = await openDailyReportAuditLogSseTransport(
        uri: _buildStreamUri(_query),
        headers: {
          'Accept': 'text/event-stream',
          'Cache-Control': 'no-cache',
          'Authorization': 'Bearer $token',
        },
      );
      _transport = transport;
      _buffer = '';
      _reconnectAttempt = 0;
      _setState(DailyReportAuditLogStreamState.connected);
      _transportSubscription = transport.stream.listen(
        _onChunk,
        onError: _handleStreamError,
        onDone: _handleStreamDone,
        cancelOnError: true,
      );
    } catch (error) {
      final recovered = await _tryRefreshTokenIfNeeded(error);
      if (!recovered) {
        _scheduleReconnect();
      }
    }
  }

  void _onChunk(String chunk) {
    if (_isDisposed || !_shouldRun) return;
    _buffer = (_buffer + chunk).replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    while (true) {
      final separatorIndex = _buffer.indexOf('\n\n');
      if (separatorIndex < 0) return;
      final rawEvent = _buffer.substring(0, separatorIndex);
      _buffer = _buffer.substring(separatorIndex + 2);
      _handleEventBlock(rawEvent);
    }
  }

  void _handleEventBlock(String rawEvent) {
    final lines = rawEvent
        .split('\n')
        .map((line) => line.trimRight())
        .where((line) => line.isNotEmpty && !line.startsWith(':'));
    String? eventType;
    final dataLines = <String>[];

    for (final line in lines) {
      if (line.startsWith('event:')) {
        eventType = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        dataLines.add(line.substring(5).trimLeft());
      }
    }

    if (eventType == null || dataLines.isEmpty) {
      return;
    }

    try {
      final payload = jsonDecode(dataLines.join('\n'));
      switch (eventType) {
        case 'snapshot':
          if (payload is Map<String, dynamic>) {
            final rawItems = payload['items'] as List? ?? const [];
            final items = rawItems
                .whereType<Map<String, dynamic>>()
                .map(DailyReportAuditLog.fromJson)
                .toList(growable: false);
            _eventController.add(
              DailyReportAuditLogSnapshotStreamEvent(
                sortDailyReportAuditLogsNewestFirst(items),
              ),
            );
          }
          break;
        case 'audit_log':
          if (payload is Map<String, dynamic>) {
            _eventController.add(
              DailyReportAuditLogInsertStreamEvent(
                DailyReportAuditLog.fromJson(payload),
              ),
            );
          }
          break;
      }
    } catch (error) {
      debugPrint('[AuditLogSSE] Failed to parse event: $error');
    }
  }

  void _handleStreamError(Object error, [StackTrace? stackTrace]) {
    if (_isDisposed || !_shouldRun) return;
    unawaited(_closeTransport());
    unawaited(_tryRefreshTokenIfNeeded(error).then((recovered) {
      if (!recovered) {
        _scheduleReconnect();
      }
    }));
  }

  void _handleStreamDone() {
    if (_isDisposed || !_shouldRun) return;
    unawaited(_closeTransport());
    _scheduleReconnect();
  }

  Future<bool> _tryRefreshTokenIfNeeded(Object error) async {
    final statusCode = switch (error) {
      DailyReportAuditLogSseTransportException exception => exception.statusCode,
      _ => null,
    };

    if (statusCode != 401 && statusCode != 403) {
      return false;
    }

    try {
      final refreshToken = await _tokenStorage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        return false;
      }

      final authResponse = await _authRepository.refresh(refreshToken);
      await _tokenStorage.saveTokens(
        accessToken: authResponse.accessToken,
        refreshToken: authResponse.refreshToken,
      );
      _reconnectAttempt = 0;
      await _connect(initial: false);
      return true;
    } catch (refreshError) {
      debugPrint('[AuditLogSSE] Token refresh failed: $refreshError');
      return false;
    }
  }

  void _scheduleReconnect() {
    if (_isDisposed || !_shouldRun) return;
    _reconnectTimer?.cancel();
    final delaySeconds = min(pow(2, _reconnectAttempt).toInt(), 30);
    _reconnectAttempt++;
    _setState(DailyReportAuditLogStreamState.reconnecting);
    _reconnectTimer = Timer(
      Duration(seconds: delaySeconds),
      () => _connect(initial: false),
    );
  }

  Future<void> _closeTransport() async {
    await _transportSubscription?.cancel();
    _transportSubscription = null;
    await _transport?.close();
    _transport = null;
  }

  void _setState(DailyReportAuditLogStreamState nextState) {
    _state = nextState;
    if (!_stateController.isClosed) {
      _stateController.add(nextState);
    }
  }
}

Uri _buildStreamUri(DailyReportAuditLogQuery query) {
  final base = Uri.parse(
    '${AppConfig.instance.apiUrl}/api/v1/daily-reports/audit-logs/stream',
  );
  final queryParameters = query.toQueryParameters().map(
    (key, value) => MapEntry(key, value.toString()),
  );
  return base.replace(queryParameters: queryParameters);
}
