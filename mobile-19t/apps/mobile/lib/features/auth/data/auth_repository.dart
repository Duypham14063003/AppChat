import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nineteen_tech_app/core/config/app_config.dart';

class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  Future<AuthResponse> login({
    required String email,
    required String password,
    String? deviceId,
    String? deviceName,
  }) async {
    final data = <String, dynamic>{'email': email, 'password': password};
    if (deviceId != null) {
      data['device_id'] = deviceId;
    }
    if (deviceName != null) {
      data['device_name'] = deviceName;
    }
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: data,
    );
    return AuthResponse.fromJson(response.data!);
  }

  Future<AuthResponse> refresh(String refreshToken) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
    );
    return AuthResponse.fromJson(response.data!);
  }

  Future<void> logout(String refreshToken) async {
    await _dio.post('/auth/logout', data: {'refreshToken': refreshToken});
  }

  Future<List<SessionInfo>> getSessions() async {
    final response = await _dio.get<List<dynamic>>('/auth/sessions');
    return response.data!
        .cast<Map<String, dynamic>>()
        .map(SessionInfo.fromJson)
        .toList();
  }

  Future<UserInfo> updateMe({
    String? name,
    Object? avatarUrl = _unsetField,
    Object? phoneNumber = _unsetField,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) {
      data['name'] = name;
    }
    if (!identical(avatarUrl, _unsetField)) {
      data['avatar_url'] = avatarUrl;
    }
    if (!identical(phoneNumber, _unsetField)) {
      data['phone_number'] = phoneNumber;
    }

    final response = await _dio.patch<Map<String, dynamic>>(
      '/users/me',
      data: data,
    );
    return UserInfo.fromJson(response.data!);
  }

  Future<BootstrapConfig> getBootstrapConfig() async {
    final response = await _dio.get<Map<String, dynamic>>('/config');
    return BootstrapConfig.fromJson(response.data ?? const {});
  }

  Future<RewardWallet> getRewardWallet() async {
    final response = await _dio.get<dynamic>('/rewards/wallet');
    return RewardWallet.fromJson(response.data);
  }

  Future<UserInfo> uploadMyAvatar(XFile file) async {
    final bytes = await file.readAsBytes();
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: file.name,
        contentType: DioMediaType.parse(file.mimeType ?? 'image/jpeg'),
      ),
    });

    final response = await _dio.post<Map<String, dynamic>>(
      '/users/me/avatar',
      data: formData,
    );
    return UserInfo.fromJson(response.data!);
  }
}

class AuthResponse {
  const AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      user: UserInfo.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  final String accessToken;
  final String refreshToken;
  final UserInfo user;
}

class UserInfo {
  const UserInfo({
    required this.id,
    required this.email,
    required this.name,
    this.department,
    this.jobTitle,
    this.employmentStatus,
    this.avatarUrl,
    this.phoneNumber,
    required this.roles,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    final rawAvatarUrl = (json['avatarUrl'] ?? json['avatar_url']) as String?;
    return UserInfo(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      department: (json['department'] ?? json['department_name']) as String?,
      jobTitle: (json['jobTitle'] ?? json['job_title']) as String?,
      employmentStatus:
          (json['employmentStatus'] ?? json['employment_status']) as String?,
      avatarUrl: _resolveAvatarUrl(rawAvatarUrl),
      phoneNumber: (json['phoneNumber'] ?? json['phone_number']) as String?,
      roles: ((json['roles'] as List<dynamic>?) ?? const <dynamic>[])
          .cast<String>(),
    );
  }

  UserInfo copyWith({
    String? id,
    String? email,
    String? name,
    String? department,
    String? jobTitle,
    String? employmentStatus,
    Object? avatarUrl = _unsetField,
    Object? phoneNumber = _unsetField,
    List<String>? roles,
  }) {
    return UserInfo(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      department: department ?? this.department,
      jobTitle: jobTitle ?? this.jobTitle,
      employmentStatus: employmentStatus ?? this.employmentStatus,
      avatarUrl: identical(avatarUrl, _unsetField)
          ? this.avatarUrl
          : avatarUrl as String?,
      phoneNumber: identical(phoneNumber, _unsetField)
          ? this.phoneNumber
          : phoneNumber as String?,
      roles: roles ?? this.roles,
    );
  }

  final String id;
  final String email;
  final String name;
  final String? department;
  final String? jobTitle;
  final String? employmentStatus;
  final String? avatarUrl;
  final String? phoneNumber;
  final List<String> roles;
}

class BootstrapConfig {
  const BootstrapConfig({this.phoneNumber, this.points, this.payrollStartConfig, this.roles = const []});

  factory BootstrapConfig.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'];
    return BootstrapConfig(
      phoneNumber: json['phone_number'] as String?,
      points: rawPoints is num ? rawPoints.toInt() : int.tryParse('$rawPoints'),
      payrollStartConfig: json['payroll_start_config'] as int?,
      roles: (json['roles'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  final String? phoneNumber;
  final int? points;
  final int? payrollStartConfig;
  final List<String> roles;
}

class RewardWallet {
  const RewardWallet({required this.balance});

  factory RewardWallet.fromJson(dynamic json) {
    if (json is num) {
      return RewardWallet(balance: json.toInt());
    }

    if (json is Map<String, dynamic>) {
      final balance = _toInt(
        json['balance'] ?? json['points'] ?? json['current_balance'],
      );
      if (balance != null) {
        return RewardWallet(balance: balance);
      }

      final nestedData = json['data'];
      if (nestedData is Map<String, dynamic>) {
        final nestedBalance = _toInt(
          nestedData['balance'] ??
              nestedData['points'] ??
              nestedData['current_balance'],
        );
        if (nestedBalance != null) {
          return RewardWallet(balance: nestedBalance);
        }
      }
    }

    return const RewardWallet(balance: 0);
  }

  final int balance;
}

const Object _unsetField = Object();

int? _toInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

String? _resolveAvatarUrl(String? avatarUrl) {
  if (avatarUrl == null || avatarUrl.isEmpty) return avatarUrl;
  if (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://')) {
    return avatarUrl;
  }
  if (avatarUrl.startsWith('/')) {
    return '${AppConfig.instance.apiUrl}$avatarUrl';
  }
  return avatarUrl;
}

class SessionInfo {
  const SessionInfo({
    required this.id,
    this.deviceName,
    required this.lastUsedAt,
    this.lastIp,
    required this.createdAt,
  });

  factory SessionInfo.fromJson(Map<String, dynamic> json) {
    return SessionInfo(
      id: json['id'] as String,
      deviceName: json['deviceName'] as String?,
      lastUsedAt: DateTime.parse(json['lastUsedAt'] as String),
      lastIp: json['lastIp'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String? deviceName;
  final DateTime lastUsedAt;
  final String? lastIp;
  final DateTime createdAt;
}
