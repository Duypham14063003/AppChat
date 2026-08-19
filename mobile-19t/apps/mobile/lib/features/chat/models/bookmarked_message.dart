enum GlobalBookmarkFilter { all, direct, group }

extension GlobalBookmarkFilterX on GlobalBookmarkFilter {
  String get label => switch (this) {
    GlobalBookmarkFilter.all => 'Tất cả',
    GlobalBookmarkFilter.direct => 'Trò chuyện',
    GlobalBookmarkFilter.group => 'Nhóm',
  };

  String? get apiQueryValue => switch (this) {
    GlobalBookmarkFilter.all => null,
    GlobalBookmarkFilter.direct => 'direct',
    GlobalBookmarkFilter.group => 'group',
  };

  String? get localConversationType => switch (this) {
    GlobalBookmarkFilter.all => null,
    GlobalBookmarkFilter.direct => 'DIRECT',
    GlobalBookmarkFilter.group => 'GROUP',
  };
}

class BookmarkedMessageData {
  final String messageId;
  final String convId;
  final String userId;
  final DateTime markedAt;
  final String? messageContent;
  final String? messageType;
  final String? senderId;
  final String? senderName;
  final DateTime? messageCreatedAt;
  final String? conversationType;
  final String? conversationName;
  final String? conversationAvatarUrl;

  const BookmarkedMessageData({
    required this.messageId,
    required this.convId,
    required this.userId,
    required this.markedAt,
    this.messageContent,
    this.messageType,
    this.senderId,
    this.senderName,
    this.messageCreatedAt,
    this.conversationType,
    this.conversationName,
    this.conversationAvatarUrl,
  });

  factory BookmarkedMessageData.fromJson(
    Map<String, dynamic> json, {
    String? fallbackConvId,
  }) {
    return BookmarkedMessageData(
      messageId: json['message_id'] as String,
      convId:
          (json['conv_id'] as String?) ??
          fallbackConvId ??
          (throw ArgumentError('conv_id is required for bookmarked messages')),
      userId: json['user_id'] as String? ?? '',
      markedAt: _parseDateTime(json['marked_at']) ?? DateTime.now(),
      messageContent: json['message_content'] as String?,
      messageType: json['message_type'] as String?,
      senderId: json['sender_id'] as String?,
      senderName: json['sender_name'] as String?,
      messageCreatedAt: _parseDateTime(json['message_created_at']),
      conversationType:
          json['conversation_type'] as String? ?? json['conv_type'] as String?,
      conversationName:
          json['conversation_name'] as String? ?? json['conv_name'] as String?,
      conversationAvatarUrl:
          json['conversation_avatar_url'] as String? ??
          json['conv_avatar_url'] as String?,
    );
  }

  bool get isGroupConversation => conversationType == 'GROUP';
}

class GlobalBookmarkedMessagesPage {
  final List<BookmarkedMessageData> items;
  final String? nextCursor;
  final bool hasMore;

  const GlobalBookmarkedMessagesPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  factory GlobalBookmarkedMessagesPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? const [];
    return GlobalBookmarkedMessagesPage(
      items: rawItems
          .map(
            (item) =>
                BookmarkedMessageData.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
      nextCursor: json['next_cursor'] as String?,
      hasMore: json['has_more'] as bool? ?? false,
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
