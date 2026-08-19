import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_notifier.dart';
import '../../hr/data/hr_models.dart';
import '../../hr/providers/hr_providers.dart';
import '../data/poc_repository.dart';
import '../models/poc_models.dart';

final pocRepositoryProvider = Provider<PocRepository>(
  (ref) => PocRepository(ref.watch(dioProvider)),
);

typedef PocListFilter = ({
  String mode,
  String search,
  String? status,
  String? week,
  String? developerUserId,
  String? saleUserId,
  String? priority,
  int page,
});

final pocListProvider = FutureProvider.family<PocPage, PocListFilter>((
  ref,
  filter,
) {
  return ref
      .watch(pocRepositoryProvider)
      .list(
        mode: filter.mode,
        search: filter.search,
        status: filter.status,
        week: filter.week,
        developerUserId: filter.developerUserId,
        saleUserId: filter.saleUserId,
        priority: filter.priority,
        page: filter.page,
      );
});

final pocDetailProvider = FutureProvider.family<PocRecord, String>(
  (ref, id) => ref.watch(pocRepositoryProvider).detail(id),
);

final pocCapacityProvider = FutureProvider.family<PocCapacityWeek, DateTime>(
  (ref, week) => ref.watch(pocRepositoryProvider).capacity(week),
);

final pocWeeklyReportProvider =
    FutureProvider.family<PocWeeklyReport, DateTime>(
      (ref, week) => ref.watch(pocRepositoryProvider).weeklyReport(week),
    );

final pocApprovedLeavesProvider =
    FutureProvider.family<List<LeaveRequest>, DateTime>((ref, week) async {
      final response = await ref
          .watch(hrRepositoryProvider)
          .getLeaves(status: 'approved', year: week.year, month: week.month);
      return response.leaves
          .where((leave) => leave.status == 'approved')
          .toList(growable: false);
    });

typedef PocCapacityPreviewRequest = ({
  DateTime plannedStart,
  DateTime demoAt,
  double estimatedHours,
  String? excludePocId,
});

final pocCapacityPreviewProvider =
    FutureProvider.family<PocCapacityWeek, PocCapacityPreviewRequest>(
      (ref, request) => ref
          .watch(pocRepositoryProvider)
          .previewCapacity(
            plannedStart: request.plannedStart,
            demoAt: request.demoAt,
            estimatedHours: request.estimatedHours,
            excludePocId: request.excludePocId,
          ),
    );

void invalidatePocData(WidgetRef ref, [String? id]) {
  ref.invalidate(pocListProvider);
  ref.invalidate(pocCapacityProvider);
  ref.invalidate(pocWeeklyReportProvider);
  if (id != null) ref.invalidate(pocDetailProvider(id));
}
