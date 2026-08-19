import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_notifier.dart';

class CallApiService {
  final Dio _dio;

  CallApiService(this._dio);

  Future<Map<String, dynamic>> startCall({
    required String receiverId,
    required String conversationId,
    required bool isVideo,
  }) async {
    // Chỉ gửi duy nhất 2 trường mà API yêu cầu trong tài liệu
    final Map<String, dynamic> body = {
      'receiverId': receiverId,
      'type': isVideo ? 'video' : 'audio',
    };

    debugPrint('[CallAPI] Request Body: $body');

    final response = await _dio.post('/calls/start', data: body);
    return response.data;
  }

  Future<void> acceptCall(String callId) async {
    await _dio.post('/calls/$callId/accept');
  }

  Future<void> rejectCall(String callId) async {
    await _dio.post('/calls/$callId/reject');
  }

  Future<void> endCall(String callId) async {
    await _dio.post('/calls/$callId/end');
  }

  Future<Map<String, dynamic>> getAgoraToken(String callId) async {
    final response = await _dio.get('/calls/$callId/token');
    return response.data;
  }

  /// Lấy cuộc gọi đến đang chờ (ringing) mà user hiện tại là người nhận.
  /// Trả về null nếu không có. Dùng để đồng bộ lại khi WS (re)connect,
  /// tránh mất sự kiện incoming_call khi socket bị rớt/zombie.
  Future<Map<String, dynamic>?> getActiveIncomingCall() async {
    final response = await _dio.get('/calls/active');
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    return null;
  }
}

final callApiServiceProvider = Provider<CallApiService>((ref) {
  final dio = ref.watch(dioProvider);
  return CallApiService(dio);
});
