import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'websocket_manager.dart';

@visibleForTesting
const connectionBannerGracePeriod = Duration(seconds: 3);

@visibleForTesting
const connectionBannerHardFailureThreshold = Duration(seconds: 8);

final recentConnectionRecoveryStartedAtProvider = StateProvider<DateTime?>(
  (ref) => null,
);

final connectionBannerNowProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream<DateTime>.periodic(
    const Duration(seconds: 1),
    (_) => DateTime.now(),
  );
});

DateTime? nextConnectionRecoveryStartedAt({
  required WsConnectionState connectionState,
  required DateTime now,
  required DateTime? currentRecoveryStartedAt,
}) {
  if (connectionState == WsConnectionState.connected) {
    return null;
  }
  return currentRecoveryStartedAt ?? now;
}

enum ConnectionBannerSeverity { hidden, soft, hard }

@immutable
class ConnectionBannerPresentation {
  const ConnectionBannerPresentation._({
    required this.severity,
    this.message,
    this.showRetry = false,
    this.showSpinner = false,
  });

  const ConnectionBannerPresentation.hidden()
    : this._(severity: ConnectionBannerSeverity.hidden);

  const ConnectionBannerPresentation.soft(String message)
    : this._(
        severity: ConnectionBannerSeverity.soft,
        message: message,
        showSpinner: true,
      );

  const ConnectionBannerPresentation.hard(String message)
    : this._(
        severity: ConnectionBannerSeverity.hard,
        message: message,
        showRetry: true,
      );

  final ConnectionBannerSeverity severity;
  final String? message;
  final bool showRetry;
  final bool showSpinner;

  bool get isVisible => severity != ConnectionBannerSeverity.hidden;
}

bool isConnectionRecoveryGraceActive({
  required DateTime now,
  required DateTime? recoveryStartedAt,
  Duration gracePeriod = connectionBannerGracePeriod,
}) {
  if (recoveryStartedAt == null) return false;
  return now.difference(recoveryStartedAt) < gracePeriod;
}

ConnectionBannerPresentation resolveConnectionBannerPresentation({
  required WsConnectionState connectionState,
  required DateTime now,
  required DateTime? recoveryStartedAt,
  Duration gracePeriod = connectionBannerGracePeriod,
  Duration hardFailureThreshold = connectionBannerHardFailureThreshold,
}) {
  if (connectionState == WsConnectionState.connected) {
    return const ConnectionBannerPresentation.hidden();
  }

  if (isConnectionRecoveryGraceActive(
    now: now,
    recoveryStartedAt: recoveryStartedAt,
    gracePeriod: gracePeriod,
  )) {
    return const ConnectionBannerPresentation.hidden();
  }

  final recoveryElapsed = recoveryStartedAt == null
      ? null
      : now.difference(recoveryStartedAt);
  final isSustainedFailure =
      recoveryElapsed != null && recoveryElapsed >= hardFailureThreshold;

  if (connectionState == WsConnectionState.connecting) {
    return isSustainedFailure
        ? const ConnectionBannerPresentation.hard('Kết nối đang gián đoạn')
        : const ConnectionBannerPresentation.soft('Đang khôi phục kết nối...');
  }

  if (connectionState == WsConnectionState.disconnected) {
    if (recoveryElapsed == null) {
      return const ConnectionBannerPresentation.hard('Kết nối đang gián đoạn');
    }

    return isSustainedFailure
        ? const ConnectionBannerPresentation.hard('Kết nối đang gián đoạn')
        : const ConnectionBannerPresentation.soft('Đang khôi phục kết nối...');
  }

  return const ConnectionBannerPresentation.hidden();
}
