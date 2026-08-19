class ChatReminder {
  final String id;
  final String convId;
  final String messageId;
  final String creatorUserId;
  final String scope;
  final String status;
  final DateTime remindAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChatReminder({
    required this.id,
    required this.convId,
    required this.messageId,
    required this.creatorUserId,
    required this.scope,
    required this.status,
    required this.remindAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatReminder.fromJson(Map<String, dynamic> json) {
    return ChatReminder(
      id: json['id'] as String? ?? '',
      convId: json['conv_id'] as String? ?? '',
      messageId: json['message_id'] as String? ?? '',
      creatorUserId: json['creator_user_id'] as String? ?? '',
      scope: json['scope'] as String? ?? 'self',
      status: json['status'] as String? ?? 'pending',
      remindAt: _parseDateTime(json['remind_at']) ?? DateTime.now(),
      createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDateTime(json['updated_at']) ?? DateTime.now(),
    );
  }
}

DateTime? _parseDateTime(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  if (value is! String || value.trim().isEmpty) return null;
  return DateTime.tryParse(value);
}
