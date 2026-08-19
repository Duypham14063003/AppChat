import 'package:dio/dio.dart';
import '../models/task_models.dart';

class TaskRepository {
  final Dio _dio;

  TaskRepository(this._dio);

  Future<List<Project>> getProjects() async {
    final res = await _dio.get('/tasks/projects');
    final list = res.data as List;
    return list
        .map((e) => Project.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<TaskStage>> getStages() async {
    final res = await _dio.get('/tasks/stages');
    final list = res.data as List;
    return list
        .map((e) => TaskStage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Task>> getTasks(
    int projectId, {
    int? stageId,
    String? stageName,
    String? sort,
    bool refresh = false,
    bool includeSubtasks = false,
  }) async {
    final params = <String, dynamic>{};
    if (stageId != null) params['stage_id'] = stageId.toString();
    if (stageName != null) params['stage_name'] = stageName;
    if (sort != null) params['sort'] = sort;
    if (refresh) params['refresh'] = 'true';
    if (includeSubtasks) params['include_subtasks'] = 'true';
    final res = await _dio.get(
      '/tasks/projects/$projectId/tasks',
      queryParameters: params,
    );
    final list = res.data as List;
    return list.map((e) => Task.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Task>> getMyTasks({
    int? stageId,
    String? stageName,
    String? sort,
    bool refresh = false,
  }) async {
    final params = <String, dynamic>{};
    if (stageId != null) params['stage_id'] = stageId.toString();
    if (stageName != null) params['stage_name'] = stageName;
    if (sort != null) params['sort'] = sort;
    if (refresh) params['refresh'] = 'true';
    final res = await _dio.get('/tasks/me', queryParameters: params);
    final list = res.data as List;
    return list.map((e) => Task.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Task?> getTaskDetail(int taskId) async {
    final res = await _dio.get('/tasks/$taskId');
    if (res.data == null) return null;
    return Task.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<LogNote>> getLogNotes(int taskId) async {
    final res = await _dio.get('/tasks/$taskId/log-notes');
    final list = res.data as List;
    return list
        .map((e) => LogNote.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> createLogNote(int taskId, String body) async {
    final res = await _dio.post(
      '/tasks/$taskId/log-notes',
      data: {'body': body},
    );
    return res.data as Map<String, dynamic>;
  }

  Future<List<Task>> getSubtasks(int taskId) async {
    final res = await _dio.get('/tasks/$taskId/subtasks');
    final list = res.data as List;
    return list.map((e) => Task.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<TaskTag>> getTags() async {
    final res = await _dio.get('/tasks/tags');
    final list = res.data as List;
    return list
        .map((e) => TaskTag.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
