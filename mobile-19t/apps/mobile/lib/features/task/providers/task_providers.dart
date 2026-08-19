import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_notifier.dart';
import '../data/task_repository.dart';
import '../models/task_models.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return TaskRepository(dio);
});

// --- Project List ---

final projectListProvider =
    AsyncNotifierProvider<ProjectListNotifier, List<Project>>(
      ProjectListNotifier.new,
    );

class ProjectListNotifier extends AsyncNotifier<List<Project>> {
  @override
  Future<List<Project>> build() async {
    final repo = ref.read(taskRepositoryProvider);
    return repo.getProjects();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(taskRepositoryProvider).getProjects(),
    );
  }
}

// --- Task Stages ---

final taskStagesProvider =
    AsyncNotifierProvider<TaskStagesNotifier, List<TaskStage>>(
      TaskStagesNotifier.new,
    );

class TaskStagesNotifier extends AsyncNotifier<List<TaskStage>> {
  @override
  Future<List<TaskStage>> build() async {
    final repo = ref.read(taskRepositoryProvider);
    return repo.getStages();
  }
}

// --- My Tasks ---

final myTaskListProvider =
    AsyncNotifierProvider<MyTaskListNotifier, List<Task>>(
      MyTaskListNotifier.new,
    );

class MyTaskListNotifier extends AsyncNotifier<List<Task>> {
  int? _stageId;
  String? _stageName;
  String? _sort;

  @override
  Future<List<Task>> build() async {
    final repo = ref.read(taskRepositoryProvider);
    return repo.getMyTasks(
      stageId: _stageId,
      stageName: _stageName,
      sort: _sort,
    );
  }

  Future<void> setFilter({int? stageId, String? stageName}) async {
    _stageId = stageId;
    _stageName = stageName;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(taskRepositoryProvider)
          .getMyTasks(stageId: _stageId, stageName: _stageName, sort: _sort),
    );
  }

  Future<void> setSort(String? sort) async {
    _sort = sort;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(taskRepositoryProvider)
          .getMyTasks(stageId: _stageId, stageName: _stageName, sort: _sort),
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(taskRepositoryProvider)
          .getMyTasks(
            stageId: _stageId,
            stageName: _stageName,
            sort: _sort,
            refresh: true,
          ),
    );
  }
}

// --- Task List (per project) ---

final taskListProvider =
    AsyncNotifierProvider.family<TaskListNotifier, List<Task>, int>(
      TaskListNotifier.new,
    );

final projectTaskListProvider =
    AsyncNotifierProvider.family<ProjectTaskListNotifier, List<Task>, int>(
      ProjectTaskListNotifier.new,
    );

class TaskListNotifier extends FamilyAsyncNotifier<List<Task>, int> {
  int? _stageId;
  String? _stageName;
  String? _sort;

  bool get includeSubtasks => false;

  @override
  Future<List<Task>> build(int arg) async {
    final repo = ref.read(taskRepositoryProvider);
    return repo.getTasks(
      arg,
      stageId: _stageId,
      stageName: _stageName,
      sort: _sort,
      includeSubtasks: includeSubtasks,
    );
  }

  Future<void> setFilter({int? stageId, String? stageName}) async {
    _stageId = stageId;
    _stageName = stageName;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(taskRepositoryProvider)
          .getTasks(
            arg,
            stageId: _stageId,
            stageName: _stageName,
            sort: _sort,
            includeSubtasks: includeSubtasks,
          ),
    );
  }

  Future<void> setSort(String? sort) async {
    _sort = sort;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(taskRepositoryProvider)
          .getTasks(
            arg,
            stageId: _stageId,
            stageName: _stageName,
            sort: _sort,
            includeSubtasks: includeSubtasks,
          ),
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(taskRepositoryProvider)
          .getTasks(
            arg,
            stageId: _stageId,
            stageName: _stageName,
            sort: _sort,
            refresh: true,
            includeSubtasks: includeSubtasks,
          ),
    );
  }
}

class ProjectTaskListNotifier extends TaskListNotifier {
  @override
  bool get includeSubtasks => true;
}

// --- Task Detail ---

final taskDetailProvider =
    AsyncNotifierProvider.family<TaskDetailNotifier, Task?, int>(
      TaskDetailNotifier.new,
    );

class TaskDetailNotifier extends FamilyAsyncNotifier<Task?, int> {
  @override
  Future<Task?> build(int arg) async {
    final repo = ref.read(taskRepositoryProvider);
    return repo.getTaskDetail(arg);
  }
}

// --- Log Notes ---

final logNotesProvider =
    AsyncNotifierProvider.family<LogNotesNotifier, List<LogNote>, int>(
      LogNotesNotifier.new,
    );

class LogNotesNotifier extends FamilyAsyncNotifier<List<LogNote>, int> {
  @override
  Future<List<LogNote>> build(int arg) async {
    final repo = ref.read(taskRepositoryProvider);
    return repo.getLogNotes(arg);
  }

  Future<void> createLogNote(String body) async {
    final repo = ref.read(taskRepositoryProvider);
    final current = state.valueOrNull ?? [];

    // Optimistic update
    final optimistic = LogNote(
      id: -1,
      body: body,
      authorName: 'Bạn',
      date: DateTime.now().toIso8601String(),
      messageType: 'comment',
    );
    state = AsyncData([optimistic, ...current]);

    try {
      await repo.createLogNote(arg, body);
      state = await AsyncValue.guard(() => repo.getLogNotes(arg));
    } catch (e) {
      state = AsyncData(current);
      rethrow;
    }
  }
}

// --- Subtasks ---

final subtaskListProvider =
    AsyncNotifierProvider.family<SubtaskListNotifier, List<Task>, int>(
      SubtaskListNotifier.new,
    );

class SubtaskListNotifier extends FamilyAsyncNotifier<List<Task>, int> {
  @override
  Future<List<Task>> build(int arg) async {
    final repo = ref.read(taskRepositoryProvider);
    return repo.getSubtasks(arg);
  }
}

// --- Task Tags ---

final taskTagsProvider = AsyncNotifierProvider<TaskTagsNotifier, List<TaskTag>>(
  TaskTagsNotifier.new,
);

class TaskTagsNotifier extends AsyncNotifier<List<TaskTag>> {
  @override
  Future<List<TaskTag>> build() async {
    final repo = ref.read(taskRepositoryProvider);
    return repo.getTags();
  }
}
