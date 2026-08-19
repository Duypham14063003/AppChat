import 'package:flutter_test/flutter_test.dart';
import 'package:nineteen_tech_app/core/notifications/badge_sync_service.dart';

void main() {
  group('sumUnreadBadgeCount', () {
    test('sums unread counts across conversations', () {
      expect(sumUnreadBadgeCount([2, 0, 3]), 5);
    });
  });

  group('parseBadgeCount', () {
    test('parses badge_count from payload data', () {
      expect(parseBadgeCount({'badge_count': '7'}), 7);
    });

    test('returns null for invalid badge_count values', () {
      expect(parseBadgeCount({'badge_count': 'oops'}), isNull);
    });
  });

  group('BadgeSyncService', () {
    test('updates badge from local unread total', () async {
      final calls = <String>[];
      final service = BadgeSyncService(
        readUnreadCounts: () async => [1, 2, 4],
        isSupported: () async => true,
        updateBadge: (count) async => calls.add('update:$count'),
        removeBadge: () async => calls.add('remove'),
        manageBadgeLocallyOverride: true,
      );

      final total = await service.syncFromLocalUnreadTotal();

      expect(total, 7);
      expect(calls, ['update:7']);
    });

    test('removes badge when count becomes zero', () async {
      final calls = <String>[];
      final service = BadgeSyncService(
        readUnreadCounts: () async => [],
        isSupported: () async => true,
        updateBadge: (count) async => calls.add('update:$count'),
        removeBadge: () async => calls.add('remove'),
        manageBadgeLocallyOverride: true,
      );

      await service.applyBadgeCount(0);

      expect(calls, ['remove']);
    });

    test('applies badge count from notification payload', () async {
      final calls = <String>[];
      final service = BadgeSyncService(
        readUnreadCounts: () async => [],
        isSupported: () async => true,
        updateBadge: (count) async => calls.add('update:$count'),
        removeBadge: () async => calls.add('remove'),
        manageBadgeLocallyOverride: true,
      );

      await service.applyBadgeCountFromData({'badge_count': '3'});

      expect(calls, ['update:3']);
    });
  });
}
