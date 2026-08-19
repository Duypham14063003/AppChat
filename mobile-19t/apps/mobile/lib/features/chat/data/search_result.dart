import 'chat_avatar_resolver.dart';

class SearchResult {
  final String messageId;
  final String convId;
  final String convName;
  final String? convAvatar;
  final String convType;
  final String snippet;
  final String senderId;
  final String? senderName;
  final DateTime createdAt;
  final String messageType;

  const SearchResult({
    required this.messageId,
    required this.convId,
    required this.convName,
    this.convAvatar,
    required this.convType,
    required this.snippet,
    required this.senderId,
    this.senderName,
    required this.createdAt,
    required this.messageType,
  });

  factory SearchResult.fromLocalRow(Map<String, dynamic> row, String query) {
    final content = row['content'] as String? ?? '';
    final snippet = _buildSnippet(content, query);
    final convType = row['conv_type'] as String? ?? 'DIRECT';
    final convName = convType == 'DIRECT'
        ? (row['other_member_name'] as String? ?? 'Chat')
        : (row['conv_name'] as String? ?? 'Nhóm');
    final convAvatar = resolveChatAvatarUrl(
      convType == 'DIRECT'
          ? row['other_member_avatar'] as String?
          : row['conv_avatar'] as String?,
    );

    return SearchResult(
      messageId: row['id'] as String,
      convId: row['conv_id'] as String,
      convName: convName,
      convAvatar: convAvatar,
      convType: convType,
      snippet: snippet,
      senderId: row['sender_id'] as String,
      createdAt: row['created_at'] is DateTime
          ? row['created_at'] as DateTime
          : DateTime.fromMillisecondsSinceEpoch(
              (row['created_at'] as int) * 1000,
            ),
      messageType: row['type'] as String? ?? 'text',
    );
  }

  factory SearchResult.fromServerResponse(Map<String, dynamic> json) {
    final snippet = (json['snippet'] as String?)?.trim().isNotEmpty == true
        ? json['snippet'] as String
        : (json['content'] as String? ?? '');
    return SearchResult(
      messageId: json['id'] as String,
      convId: json['conv_id'] as String,
      convName: json['conv_name'] as String? ?? '',
      convAvatar: resolveChatAvatarUrl(json['conv_avatar_url'] as String?),
      convType: json['conv_type'] as String? ?? 'DIRECT',
      snippet: snippet,
      senderId: json['sender_id'] as String,
      senderName: json['sender_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      messageType: json['type'] as String? ?? 'text',
    );
  }

  static String _buildSnippet(String content, String query) {
    final lowerContent = content.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final idx = lowerContent.indexOf(lowerQuery);
    if (idx < 0) {
      final end = content.length > 60 ? 60 : content.length;
      return content.substring(0, end) + (content.length > 60 ? '...' : '');
    }
    final start = (idx - 20).clamp(0, content.length);
    final end = (idx + query.length + 20).clamp(0, content.length);
    final prefix = start > 0 ? '...' : '';
    final suffix = end < content.length ? '...' : '';
    final before = content.substring(start, idx);
    final match = content.substring(idx, idx + query.length);
    final after = content.substring(idx + query.length, end);
    return '$prefix$before<mark>$match</mark>$after$suffix';
  }
}
