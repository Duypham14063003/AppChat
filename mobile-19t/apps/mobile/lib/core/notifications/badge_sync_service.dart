import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nineteen_tech_app/core/database/app_database.dart';

typedef BadgeSupportChecker = Future<bool> Function();
typedef BadgeCountUpdater = Future<void> Function(int count);
typedef BadgeRemover = Future<void> Function();
typedef UnreadCountReader = Future<List<int>> Function();

int sumUnreadBadgeCount(Iterable<int> unreadCounts) {
  return unreadCounts.fold(0, (sum, count) => sum + count);
}

int? parseBadgeCount(Map<String, dynamic> data) {
  final raw = data['badge_count'];
  if (raw == null) return null;
  return int.tryParse('$raw');
}

final badgeSyncServiceProvider = Provider<BadgeSyncService>((ref) {
  final dao = ref.read(chatDaoProvider);
  return BadgeSyncService(
    readUnreadCounts: () async {
      final conversations = await dao.getConversations();
      return conversations.map((conversation) => conversation.unreadCount).toList();
    },
  );
});

class BadgeSyncService {
  BadgeSyncService({
    required UnreadCountReader readUnreadCounts,
    BadgeSupportChecker? isSupported,
    BadgeCountUpdater? updateBadge,
    BadgeRemover? removeBadge,
    bool? manageBadgeLocallyOverride,
  }) : _readUnreadCounts = readUnreadCounts,
       _isSupported = isSupported ?? FlutterAppBadger.isAppBadgeSupported,
       _updateBadge = updateBadge ?? FlutterAppBadger.updateBadgeCount,
       _removeBadge = removeBadge ?? FlutterAppBadger.removeBadge,
       _manageBadgeLocallyOverride = manageBadgeLocallyOverride;

  final UnreadCountReader _readUnreadCounts;
  final BadgeSupportChecker _isSupported;
  final BadgeCountUpdater _updateBadge;
  final BadgeRemover _removeBadge;
  final bool? _manageBadgeLocallyOverride;

  Future<void> applyBadgeCountFromData(Map<String, dynamic> data) async {
    final badgeCount = parseBadgeCount(data);
    if (badgeCount == null) return;
    await applyBadgeCount(badgeCount);
  }

  Future<int> syncFromLocalUnreadTotal() async {
    final unreadCounts = await _readUnreadCounts();
    final total = sumUnreadBadgeCount(unreadCounts);
    await applyBadgeCount(total);
    return total;
  }

  Future<void> clearBadge() => applyBadgeCount(0);

  Future<void> applyBadgeCount(int count) async {
    if (!_shouldManageBadgeLocally()) return;
    final supported = await _isSupported();
    if (!supported) return;

    if (count <= 0) {
      await _removeBadge();
      return;
    }

    await _updateBadge(count);
  }

  bool _shouldManageBadgeLocally() {
    if (_manageBadgeLocallyOverride != null) {
      return _manageBadgeLocallyOverride;
    }
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }
}
