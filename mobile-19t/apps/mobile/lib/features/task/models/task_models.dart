class Project {
  final int id;
  final String name;
  final String? managerName;
  final String? dateStart;
  final String? dateEnd;
  final int taskCount;

  const Project({
    required this.id,
    required this.name,
    this.managerName,
    this.dateStart,
    this.dateEnd,
    required this.taskCount,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    final userId = json['user_id'];
    return Project(
      id: json['id'] as int,
      name: json['name'] as String,
      managerName: userId is List ? userId[1] as String : null,
      dateStart: json['date_start'] is String
          ? json['date_start'] as String
          : null,
      dateEnd: json['date'] is String ? json['date'] as String : null,
      taskCount: json['task_count'] as int? ?? 0,
    );
  }
}

class Task {
  final int id;
  final String name;
  final List<TaskAssignee> assignees;
  final TaskStageRef? stage;
  final String? dateDeadline;
  final int priority;
  final String? description;
  final int subtaskCount;
  final List<int> childIds;
  final List<int> tagIds;
  final dynamic parentId;

  const Task({
    required this.id,
    required this.name,
    required this.assignees,
    this.stage,
    this.dateDeadline,
    required this.priority,
    this.description,
    this.subtaskCount = 0,
    this.childIds = const [],
    this.tagIds = const [],
    this.parentId,
  });

  bool get isSubtask => parentId != null && parentId != false;

  String? get parentName {
    final parent = parentId;
    if (parent is List && parent.length > 1) {
      final name = parent[1]?.toString().trim();
      return name == null || name.isEmpty ? null : name;
    }
    return null;
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    final userIds = json['user_ids'] as List? ?? [];
    final stageId = json['stage_id'];
    final rawChildIds = json['child_ids'] as List? ?? [];
    final rawTagIds = json['tag_ids'] as List? ?? [];
    return Task(
      id: json['id'] as int,
      name: json['name'] as String,
      assignees: userIds.map((u) {
        if (u is List) {
          return TaskAssignee(id: u[0] as int, name: u[1] as String);
        }
        return TaskAssignee(id: u as int, name: '#$u');
      }).toList(),
      stage: stageId is List
          ? TaskStageRef(id: stageId[0] as int, name: stageId[1] as String)
          : null,
      dateDeadline: json['date_deadline'] is String
          ? json['date_deadline'] as String
          : null,
      priority: int.tryParse(json['priority']?.toString() ?? '0') ?? 0,
      description: json['description'] is String
          ? json['description'] as String
          : null,
      subtaskCount: json['subtask_count'] as int? ?? 0,
      childIds: rawChildIds.map((e) => e as int).toList(),
      tagIds: rawTagIds.whereType<int>().toList(),
      parentId: json['parent_id'],
    );
  }

  /// Serialize back to raw Odoo format for daily report API
  Map<String, dynamic> toRawJson() => {
    'id': id,
    'name': name,
    'user_ids': assignees.map((a) => a.id).toList(),
    'stage_id': stage != null ? [stage!.id, stage!.name] : false,
    'tag_ids': tagIds,
    'date_deadline': dateDeadline ?? false,
    'priority': priority.toString(),
    'description': description ?? false,
    'parent_id': parentId ?? false,
    'child_ids': childIds,
    'subtask_count': subtaskCount,
  };
}

class TaskAssignee {
  final int id;
  final String name;
  const TaskAssignee({required this.id, required this.name});
}

class TaskStageRef {
  final int id;
  final String name;
  const TaskStageRef({required this.id, required this.name});
}

enum TaskStageName {
  backlog('BACKLOG', 'BACKLOG'),
  coding('CODING', 'CODING'),
  staging('STAGING', 'STAGING'),
  production('PRODUCTION', 'PRODUCTION'),
  completed('COMPLETED', 'COMPLETED');

  const TaskStageName(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

class TaskStage {
  final int id;
  final String name;
  final int sequence;

  const TaskStage({
    required this.id,
    required this.name,
    required this.sequence,
  });

  factory TaskStage.fromJson(Map<String, dynamic> json) {
    return TaskStage(
      id: json['id'] as int,
      name: json['name'] as String,
      sequence: json['sequence'] as int? ?? 0,
    );
  }
}

class LogNote {
  final int id;
  final String body;
  final String? authorName;
  final int? authorId;
  final String date;
  final String messageType;

  const LogNote({
    required this.id,
    required this.body,
    this.authorName,
    this.authorId,
    required this.date,
    required this.messageType,
  });

  factory LogNote.fromJson(Map<String, dynamic> json) {
    final authorId = json['author_id'];
    return LogNote(
      id: json['id'] as int,
      body: json['body'] as String? ?? '',
      authorName: authorId is List ? authorId[1] as String : null,
      authorId: authorId is List ? authorId[0] as int : null,
      date: json['date'] as String,
      messageType: json['message_type'] as String? ?? 'comment',
    );
  }
}

class TaskTag {
  final int id;
  final String name;

  const TaskTag({required this.id, required this.name});

  factory TaskTag.fromJson(Map<String, dynamic> json) {
    return TaskTag(id: json['id'] as int, name: json['name'] as String);
  }
}
