class MessageSeenByUser {
  final String userId;
  final String name;
  final String? avatarUrl;
  final DateTime? seenAt;

  const MessageSeenByUser({
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.seenAt,
  });

  factory MessageSeenByUser.fromJson(Map<String, dynamic> json) {
    return MessageSeenByUser(
      userId: json['user_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      seenAt: DateTime.tryParse(json['seen_at'] as String? ?? '')?.toLocal(),
    );
  }
}

class MessageSeenByResponse {
  final String convId;
  final String messageId;
  final List<MessageSeenByUser> seenBy;

  const MessageSeenByResponse({
    required this.convId,
    required this.messageId,
    required this.seenBy,
  });

  factory MessageSeenByResponse.fromJson(Map<String, dynamic> json) {
    final rawSeenBy = json['seen_by'] as List? ?? const [];
    return MessageSeenByResponse(
      convId: json['conv_id'] as String? ?? '',
      messageId: json['message_id'] as String? ?? '',
      seenBy: rawSeenBy
          .whereType<Map<String, dynamic>>()
          .map(MessageSeenByUser.fromJson)
          .toList(),
    );
  }
}
