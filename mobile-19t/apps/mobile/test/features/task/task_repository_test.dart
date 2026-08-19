import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nineteen_tech_app/features/task/data/task_repository.dart';
import 'package:nineteen_tech_app/features/task/models/task_models.dart';

void main() {
  test('getTasks sends include_subtasks when requested', () async {
    final dio = Dio();
    Map<String, dynamic>? capturedParams;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          capturedParams = Map<String, dynamic>.from(options.queryParameters);
          handler.resolve(
            Response(
              requestOptions: options,
              data: [
                {
                  'id': 1,
                  'name': 'Parent',
                  'user_ids': [],
                  'stage_id': false,
                  'child_ids': [2],
                  'tag_ids': [],
                  'subtask_count': 1,
                  'parent_id': false,
                },
              ],
            ),
          );
        },
      ),
    );

    final repo = TaskRepository(dio);
    final tasks = await repo.getTasks(18, refresh: true, includeSubtasks: true);

    expect(tasks.single.id, 1);
    expect(capturedParams, containsPair('refresh', 'true'));
    expect(capturedParams, containsPair('include_subtasks', 'true'));
  });

  test('Task model recognizes subtasks from parent_id', () {
    final task = Task.fromJson({
      'id': 2,
      'name': 'Subtask',
      'user_ids': [],
      'stage_id': false,
      'child_ids': [],
      'tag_ids': [],
      'subtask_count': 0,
      'parent_id': [1, 'Parent task'],
    });

    expect(task.isSubtask, isTrue);
    expect(task.parentName, 'Parent task');
  });
}
