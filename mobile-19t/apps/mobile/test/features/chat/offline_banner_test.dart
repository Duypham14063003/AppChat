import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nineteen_tech_app/core/network/connection_banner_policy.dart';
import 'package:nineteen_tech_app/core/network/websocket_manager.dart';
import 'package:nineteen_tech_app/core/network/websocket_provider.dart';
import 'package:nineteen_tech_app/features/chat/widgets/offline_banner.dart';

void main() {
  Future<void> pumpBanner(
    WidgetTester tester, {
    required WsConnectionState state,
    required DateTime now,
    DateTime? recoveryStartedAt,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          webSocketConnectionProvider.overrideWith(
            (ref) => Stream.value(state),
          ),
          connectionBannerNowProvider.overrideWith((ref) => Stream.value(now)),
          recentConnectionRecoveryStartedAtProvider.overrideWith(
            (ref) => recoveryStartedAt,
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: OfflineBanner())),
      ),
    );
    await tester.pump();
  }

  group('OfflineBanner', () {
    testWidgets('stays hidden during the reconnect grace period', (
      tester,
    ) async {
      final now = DateTime(2026, 7, 15, 14, 45);
      await pumpBanner(
        tester,
        state: WsConnectionState.disconnected,
        now: now,
        recoveryStartedAt: now.subtract(const Duration(seconds: 1)),
      );

      expect(find.text('Đang khôi phục kết nối...'), findsNothing);
      expect(find.text('Kết nối đang gián đoạn'), findsNothing);
    });

    testWidgets('shows soft reconnect messaging after the grace period', (
      tester,
    ) async {
      final now = DateTime(2026, 7, 15, 14, 45);
      await pumpBanner(
        tester,
        state: WsConnectionState.disconnected,
        now: now,
        recoveryStartedAt: now.subtract(const Duration(seconds: 4)),
      );

      expect(find.text('Đang khôi phục kết nối...'), findsOneWidget);
    });
  });
}
