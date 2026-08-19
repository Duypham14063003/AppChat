import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nineteen_tech_app/core/theme/app_theme.dart';
import 'package:nineteen_tech_app/features/chat/widgets/poc_system_message_card.dart';

void main() {
  test('accepts version 1 lifecycle and weekly metadata only', () {
    expect(
      isSupportedPocSystemMetadata({
        'schema_version': 1,
        'kind': 'poc_assigned',
        'poc_id': 'poc-1',
      }),
      isTrue,
    );
    expect(
      isSupportedPocSystemMetadata({
        'schema_version': 1,
        'kind': 'poc_weekly_summary',
        'week_start': '2026-08-10',
      }),
      isTrue,
    );
    expect(
      isSupportedPocSystemMetadata({
        'schema_version': 2,
        'kind': 'poc_assigned',
        'poc_id': 'poc-1',
      }),
      isFalse,
    );
    expect(isSupportedPocSystemMetadata({'kind': 'poc_assigned'}), isFalse);
  });

  test('resolves detail and weekly deep links', () {
    expect(
      pocSystemDeepLink({'kind': 'poc_assigned', 'poc_id': 'poc-1'}),
      '/pocs/poc-1',
    );
    expect(
      pocSystemDeepLink({
        'kind': 'poc_weekly_summary',
        'week_start': '2026-08-10',
      }),
      '/pocs/week?week=2026-08-10',
    );
  });

  for (final kind in const [
    'poc_assigned',
    'poc_plan_updated',
    'poc_demo_30m',
    'poc_overdue',
    'poc_status_ready',
    'poc_weekly_summary',
  ]) {
    testWidgets('renders $kind card and opens its deep link', (tester) async {
      String? opened;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: PocSystemMessageCard(
              kind: kind,
              metadata: {
                'schema_version': 1,
                'kind': kind,
                'poc_id': 'poc-1',
                'code': 'SALE.DEV-WA-P0001-1000-14.08.26',
                'title': 'Customer demo',
                'customer_name': 'Acme',
                'demo_at': '2026-08-14T03:00:00.000Z',
                'week_start': '2026-08-10',
                if (kind == 'poc_plan_updated')
                  'changes': {
                    'demo_at': {
                      'previous': '2026-08-13T03:00:00.000Z',
                      'current': '2026-08-14T03:00:00.000Z',
                    },
                  },
              },
              onOpen: (route) => opened = route,
            ),
          ),
        ),
      );

      expect(find.text(pocSystemTitle(kind)), findsOneWidget);
      if (kind == 'poc_plan_updated') {
        expect(find.textContaining('→'), findsOneWidget);
      }
      await tester.tap(find.byType(TextButton));
      expect(opened, isNotNull);
      expect(tester.takeException(), isNull);
    });
  }
}
