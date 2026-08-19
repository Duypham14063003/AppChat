import 'package:drift/drift.dart';
import 'app_database.dart';
import 'tables.dart';

part 'hr_dao.g.dart';

@DriftAccessor(tables: [LocalAttendance])
class HrDao extends DatabaseAccessor<AppDatabase> with _$HrDaoMixin {
  HrDao(super.db);

  Future<void> insertAttendance(LocalAttendanceCompanion entry) {
    return into(localAttendance).insertOnConflictUpdate(entry);
  }

  Future<void> updateCheckout(String id, DateTime checkoutAt, double? totalHours, double? otHours) {
    return (update(localAttendance)..where((t) => t.id.equals(id))).write(
      LocalAttendanceCompanion(
        checkoutAt: Value(checkoutAt),
        totalHours: Value(totalHours),
        otHours: Value(otHours),
      ),
    );
  }

  Future<List<LocalAttendanceData>> getPendingSync() {
    return (select(localAttendance)
          ..where((t) => t.syncStatus.equals('pending_sync'))
          ..orderBy([(t) => OrderingTerm.asc(t.checkinAt)]))
        .get();
  }

  Future<void> markSynced(String id) {
    return (update(localAttendance)..where((t) => t.id.equals(id))).write(
      const LocalAttendanceCompanion(syncStatus: Value('synced')),
    );
  }

  Future<LocalAttendanceData?> getTodayAttendance(String userId) {
    final todayStart = DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0);
    final todayEnd = todayStart.add(const Duration(days: 1));
    return (select(localAttendance)
          ..where((t) => t.userId.equals(userId) & t.checkinAt.isBiggerOrEqualValue(todayStart) & t.checkinAt.isSmallerThanValue(todayEnd)))
        .getSingleOrNull();
  }

  Future<List<LocalAttendanceData>> getAttendanceByDateRange(String userId, DateTime from, DateTime to) {
    return (select(localAttendance)
          ..where((t) => t.userId.equals(userId) & t.checkinAt.isBiggerOrEqualValue(from) & t.checkinAt.isSmallerOrEqualValue(to))
          ..orderBy([(t) => OrderingTerm.desc(t.checkinAt)]))
        .get();
  }
}

