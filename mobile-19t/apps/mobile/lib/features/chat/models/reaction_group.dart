class ReactionUser {
  final String id;
  final String name;

  const ReactionUser({required this.id, required this.name});

  factory ReactionUser.fromJson(Map<String, dynamic> json) {
    return ReactionUser(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }
}

class ReactionGroup {
  final String emoji;
  final int count;
  final List<ReactionUser> users;
  final bool isMine;

  const ReactionGroup({
    required this.emoji,
    required this.count,
    required this.users,
    required this.isMine,
  });

  factory ReactionGroup.fromJson(Map<String, dynamic> json, String currentUserId) {
    final users = (json['users'] as List)
        .map((u) => ReactionUser.fromJson(u as Map<String, dynamic>))
        .toList();
    return ReactionGroup(
      emoji: json['emoji'] as String,
      count: json['count'] as int? ?? users.length,
      users: users,
      isMine: users.any((u) => u.id == currentUserId),
    );
  }
}
