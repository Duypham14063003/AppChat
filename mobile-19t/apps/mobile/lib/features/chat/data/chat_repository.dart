import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as vt;
import '../models/link_preview.dart';
import '../models/bookmarked_message.dart';
import '../models/message_seen_by.dart';

class ChatRepository {
  final Dio _dio;

  ChatRepository(this._dio);

  Future<Map<String, dynamic>> createConversation(String memberId) async {
    final res = await _dio.post(
      '/conversations',
      data: {'member_id': memberId},
    );
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getConversations({String? cursor}) async {
    final params = <String, dynamic>{};
    if (cursor != null) params['cursor'] = cursor;
    final res = await _dio.get('/conversations', queryParameters: params);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getConversation(String id) async {
    final res = await _dio.get('/conversations/$id');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getConversationEncryptionKey(
    String convId,
  ) async {
    final res = await _dio.get('/conversations/$convId/encryption-key');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMessages(
    String convId, {
    String? cursor,
    String dir = 'before',
    int limit = 30,
  }) async {
    final params = <String, dynamic>{'dir': dir};
    if (cursor != null) params['cursor'] = cursor;
    final res = await _dio.get(
      '/conversations/$convId/messages',
      queryParameters: params,
    );
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMessage(String messageId) async {
    final res = await _dio.get('/messages/$messageId');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> editMessage(
    String convId,
    String messageId, {
    String? content,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? blindIndex,
  }) async {
    final data = <String, dynamic>{};
    if (content != null) data['content'] = content;
    if (metadata != null) data['metadata'] = metadata;
    if (blindIndex != null) data['blind_index_v1'] = blindIndex;
    final res = await _dio.patch(
      '/conversations/$convId/messages/$messageId',
      data: data,
    );
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> recallMessage(
    String convId,
    String messageId,
  ) async {
    final res = await _dio.delete('/conversations/$convId/messages/$messageId');
    return res.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getMessageReminders(
    String convId,
    String messageId,
  ) async {
    final res = await _dio.get(
      '/conversations/$convId/messages/$messageId/reminders',
    );
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getConversationReminders(
    String convId,
  ) async {
    final res = await _dio.get('/conversations/$convId/reminders');
    return (res.data as List).cast<Map<String, dynamic>>();
  }

  Future<MessageSeenByResponse> getMessageSeenBy(
    String convId,
    String messageId,
  ) async {
    final res = await _dio.get(
      '/conversations/$convId/messages/$messageId/seen-by',
    );
    return MessageSeenByResponse.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> createMessageReminder(
    String convId, {
    required String messageId,
    required String scope,
    required DateTime remindAt,
  }) async {
    final res = await _dio.post(
      '/conversations/$convId/reminders',
      data: {
        'message_id': messageId,
        'scope': scope,
        'remind_at': remindAt.toUtc().toIso8601String(),
      },
    );
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateMessageReminder(
    String convId,
    String reminderId, {
    String? scope,
    DateTime? remindAt,
  }) async {
    final data = <String, dynamic>{};
    if (scope != null) data['scope'] = scope;
    if (remindAt != null) {
      data['remind_at'] = remindAt.toUtc().toIso8601String();
    }

    final res = await _dio.patch(
      '/conversations/$convId/reminders/$reminderId',
      data: data,
    );
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> cancelMessageReminder(
    String convId,
    String reminderId,
  ) async {
    final res = await _dio.delete(
      '/conversations/$convId/reminders/$reminderId',
    );
    return res.data as Map<String, dynamic>;
  }

  // --- Group operations ---

  Future<Map<String, dynamic>> createGroupConversation(
    String name,
    List<String> memberIds,
  ) async {
    final res = await _dio.post(
      '/conversations/group',
      data: {'name': name, 'member_ids': memberIds},
    );
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateConversation(
    String id, {
    String? name,
    String? avatarUrl,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (avatarUrl != null) data['avatar_url'] = avatarUrl;
    final res = await _dio.patch('/conversations/$id', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> addMembers(
    String convId,
    List<String> memberIds,
  ) async {
    final res = await _dio.post(
      '/conversations/$convId/members',
      data: {'member_ids': memberIds},
    );
    return res.data as Map<String, dynamic>;
  }

  Future<void> removeMember(String convId, String userId) async {
    await _dio.delete('/conversations/$convId/members/$userId');
  }

  Future<void> updateMemberRole(
    String convId,
    String userId,
    String role,
  ) async {
    await _dio.patch(
      '/conversations/$convId/members/$userId',
      data: {'role': role},
    );
  }

  Future<void> deleteGroup(String convId) async {
    await _dio.delete('/conversations/$convId');
  }

  // --- Media upload ---

  Future<List<Map<String, dynamic>>> uploadFiles(
    List<XFile> files, {
    void Function(int count, int total)? onSendProgress,
  }) async {
    final formData = FormData();
    for (final file in files) {
      final bytes = await file.readAsBytes();
      final mimeType = file.mimeType ?? _guessMimeType(file.name);
      formData.files.add(
        MapEntry(
          'files',
          MultipartFile.fromBytes(
            bytes,
            filename: file.name,
            contentType: MediaType.parse(mimeType),
          ),
        ),
      );
    }
    final res = await _dio.post(
      '/chat/upload',
      data: formData,
      onSendProgress: onSendProgress,
    );
    final data = res.data as Map<String, dynamic>;
    return (data['files'] as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> uploadImages(
    List<XFile> files, {
    void Function(int count, int total)? onSendProgress,
  }) {
    return uploadFiles(files, onSendProgress: onSendProgress);
  }

  static String _guessMimeType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'pdf' => 'application/pdf',
      'txt' => 'text/plain',
      'md' => 'text/markdown',
      'csv' => 'text/csv',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls' => 'application/vnd.ms-excel',
      'xlsx' =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'ppt' => 'application/vnd.ms-powerpoint',
      'pptx' =>
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'rtf' => 'application/rtf',
      'zip' => 'application/zip',
      'rar' => 'application/vnd.rar',
      'mp3' => 'audio/mpeg',
      'm4a' => 'audio/mp4',
      'aac' => 'audio/aac',
      'wav' => 'audio/wav',
      'ogg' => 'audio/ogg',
      _ => 'application/octet-stream',
    };
  }

  // --- Voice upload ---

  Future<Map<String, dynamic>> uploadVoice(
    String filePath, {
    void Function(int count, int total)? onSendProgress,
  }) async {
    final fileName = filePath.split('/').last;
    final formData = FormData.fromMap({
      'files': await MultipartFile.fromFile(
        filePath,
        filename: fileName,
        contentType: MediaType('audio', 'aac'),
      ),
    });
    final res = await _dio.post(
      '/chat/upload',
      data: formData,
      onSendProgress: onSendProgress,
    );
    final data = res.data as Map<String, dynamic>;
    final files = (data['files'] as List).cast<Map<String, dynamic>>();
    return files.first;
  }

  // --- Video thumbnail ---

  Future<Uint8List?> generateVideoThumbnail(String videoPath) async {
    if (kIsWeb) return null; // video_thumbnail doesn't support web
    try {
      final uint8list = await vt.VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: vt.ImageFormat.JPEG,
        maxWidth: 320,
        quality: 70,
        timeMs: 1000,
      );
      debugPrint('[Chat] Thumbnail generated: ${uint8list?.length ?? 0} bytes');
      return uint8list;
    } catch (e) {
      debugPrint('[Chat] Failed to generate thumbnail: $e');
      return null;
    }
  }

  // --- Video upload ---

  Future<Map<String, dynamic>> uploadVideo(
    XFile video,
    Uint8List? thumbnailBytes, {
    void Function(int sent, int total)? onSendProgress,
  }) async {
    final formData = FormData();

    final videoBytes = await video.readAsBytes();
    final videoMimeType = video.mimeType ?? _guessVideoMimeType(video.name);
    formData.files.add(
      MapEntry(
        'video',
        MultipartFile.fromBytes(
          videoBytes,
          filename: video.name,
          contentType: MediaType.parse(videoMimeType),
        ),
      ),
    );

    if (thumbnailBytes != null) {
      formData.files.add(
        MapEntry(
          'thumbnail',
          MultipartFile.fromBytes(
            thumbnailBytes,
            filename: 'thumbnail.jpg',
            contentType: MediaType.parse('image/jpeg'),
          ),
        ),
      );
    }

    final res = await _dio.post(
      '/chat/upload-video',
      data: formData,
      onSendProgress: onSendProgress,
      options: Options(
        sendTimeout: const Duration(minutes: 5),
        receiveTimeout: const Duration(minutes: 5),
      ),
    );

    return res.data as Map<String, dynamic>;
  }

  // --- Link preview ---

  Future<LinkPreview?> fetchLinkPreview(String url) async {
    try {
      final res = await _dio.post('/chat/link-preview', data: {'url': url});
      if (res.data == null) return null;
      return LinkPreview.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[ChatRepository] Failed to fetch link preview: $e');
      return null;
    }
  }

  // --- Pin ---

  Future<void> pinMessage(String convId, String messageId) async {
    await _dio.post(
      '/conversations/$convId/pins',
      data: {'message_id': messageId},
    );
  }

  Future<void> unpinMessage(String convId, String messageId) async {
    await _dio.delete('/conversations/$convId/pins/$messageId');
  }

  Future<List<dynamic>> getPinnedMessages(String convId) async {
    final res = await _dio.get('/conversations/$convId/pins');
    return res.data as List<dynamic>;
  }

  Future<void> unpinAllMessages(String convId) async {
    await _dio.delete('/conversations/$convId/pins');
  }

  // --- Bookmarks ---

  Future<void> bookmarkMessage(String convId, String messageId) async {
    await _dio.post(
      '/conversations/$convId/bookmarks',
      data: {'message_id': messageId},
    );
  }

  Future<void> unbookmarkMessage(String convId, String messageId) async {
    await _dio.delete('/conversations/$convId/bookmarks/$messageId');
  }

  Future<List<dynamic>> getBookmarkedMessages(String convId) async {
    final res = await _dio.get('/conversations/$convId/bookmarks');
    return res.data as List<dynamic>;
  }

  Future<GlobalBookmarkedMessagesPage> getGlobalBookmarkedMessages({
    GlobalBookmarkFilter filter = GlobalBookmarkFilter.all,
    String? cursor,
    int limit = 20,
  }) async {
    final queryParameters = <String, dynamic>{'limit': limit};
    final convType = filter.apiQueryValue;
    if (convType != null) {
      queryParameters['conv_type'] = convType;
    }
    if (cursor != null && cursor.isNotEmpty) {
      queryParameters['cursor'] = cursor;
    }

    final res = await _dio.get(
      '/users/me/bookmarks',
      queryParameters: queryParameters,
    );
    return GlobalBookmarkedMessagesPage.fromJson(
      res.data as Map<String, dynamic>,
    );
  }

  // --- Search ---

  Future<Map<String, dynamic>> searchMessages({
    String? query,
    List<String>? blindIndexTokens,
    String? convId,
    String? cursor,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (blindIndexTokens != null && blindIndexTokens.isNotEmpty) {
      params['q_hashes'] = blindIndexTokens;
    } else if (query != null && query.trim().isNotEmpty) {
      params['q'] = query;
    } else {
      throw ArgumentError(
        'Either query or blindIndexTokens must be provided for searchMessages.',
      );
    }
    if (convId != null) params['conv_id'] = convId;
    if (cursor != null) params['cursor'] = cursor;
    final res = await _dio.get('/search/messages', queryParameters: params);
    return res.data as Map<String, dynamic>;
  }

  // --- Group Info Assets ---

  Future<Object?> getConversationMedia({
    required String convId,
    String? cursor,
    int limit = 20,
    String type = 'all', // all|image|video
  }) async {
    final params = <String, dynamic>{'limit': limit, 'type': type};
    if (cursor != null) params['cursor'] = cursor;
    final res = await _dio.get(
      '/conversations/$convId/media',
      queryParameters: params,
    );
    return res.data;
  }

  Future<Object?> getConversationFiles({
    required String convId,
    String? cursor,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (cursor != null) params['cursor'] = cursor;
    final res = await _dio.get(
      '/conversations/$convId/files',
      queryParameters: params,
    );
    return res.data;
  }

  Future<Object?> getConversationLinks({
    required String convId,
    String? cursor,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (cursor != null) params['cursor'] = cursor;
    final res = await _dio.get(
      '/conversations/$convId/links',
      queryParameters: params,
    );
    return res.data;
  }

  Future<Map<String, dynamic>> getConversationAssetsSummary({
    required String convId,
  }) async {
    final res = await _dio.get('/conversations/$convId/assets-summary');
    return res.data as Map<String, dynamic>;
  }

  static String _guessVideoMimeType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return switch (ext) {
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'avi' => 'video/x-msvideo',
      'mkv' => 'video/x-matroska',
      'webm' => 'video/webm',
      _ => 'video/mp4',
    };
  }
}
