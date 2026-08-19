import 'package:dio/dio.dart';
import 'chat_avatar_resolver.dart';

class UserContact {
  final String id;
  final String name;
  final String email;
  final String? department;
  final String? jobTitle;
  final String? avatarUrl;

  const UserContact({
    required this.id,
    required this.name,
    required this.email,
    this.department,
    this.jobTitle,
    this.avatarUrl,
  });

  factory UserContact.fromJson(Map<String, dynamic> json) {
    return UserContact(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      department: (json['department'] ?? json['department_name']) as String?,
      jobTitle: (json['jobTitle'] ?? json['job_title']) as String?,
      avatarUrl: resolveChatAvatarUrl(
        (json['avatarUrl'] ?? json['avatar_url']) as String?,
      ),
    );
  }
}

class UserListResponse {
  final List<UserContact> users;
  final int total;
  final String? nextCursor;
  final bool hasMore;

  const UserListResponse({
    required this.users,
    required this.total,
    this.nextCursor,
    required this.hasMore,
  });
}

class UserRepository {
  final Dio _dio;

  UserRepository(this._dio);

  Future<UserListResponse> getUsers({
    String? search,
    String? cursor,
    int limit = 50,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (cursor != null) params['cursor'] = cursor;

    final res = await _dio.get('/users', queryParameters: params);
    final data = res.data as Map<String, dynamic>;
    final users = (data['users'] as List)
        .map((u) => UserContact.fromJson(u as Map<String, dynamic>))
        .toList();

    return UserListResponse(
      users: users,
      total: data['total'] as int,
      nextCursor: data['nextCursor'] as String?,
      hasMore: data['hasMore'] as bool,
    );
  }
}
