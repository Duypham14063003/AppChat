import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'chat_providers.dart';

part 'conversation_assets_provider.g.dart';

List<Map<String, dynamic>> _normalizeAssetItemsResponse(Object? response) {
  if (response is List) {
    return response
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  if (response is Map<String, dynamic>) {
    final items = response['items'];
    if (items is List) {
      return items
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    }

    if (response.containsKey('message_id')) {
      return [response];
    }
  }

  if (response is Map) {
    final mapped = Map<String, dynamic>.from(response);
    final items = mapped['items'];
    if (items is List) {
      return items
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    }

    if (mapped.containsKey('message_id')) {
      return [mapped];
    }
  }

  return const [];
}

String? _readCursor(Object? response) {
  if (response is Map<String, dynamic>) return response['next_cursor'] as String?;
  if (response is Map) return response['next_cursor'] as String?;
  return null;
}

bool _readHasMore(Object? response, int itemCount) {
  if (response is Map<String, dynamic>) {
    return response['has_more'] as bool? ?? false;
  }
  if (response is Map) {
    return response['has_more'] as bool? ?? false;
  }
  return false;
}

// Models
class ConversationMediaItem {
  final String messageId;
  final String type; // image, album, video
  final List<String> urls;
  final String? thumbnail;
  final String? caption;
  final DateTime createdAt;
  final String senderId;
  final String? senderName;

  const ConversationMediaItem({
    required this.messageId,
    required this.type,
    required this.urls,
    this.thumbnail,
    this.caption,
    required this.createdAt,
    required this.senderId,
    this.senderName,
  });

  factory ConversationMediaItem.fromJson(Map<String, dynamic> json) {
    final metadataRaw = json['metadata'];
    final metadata = metadataRaw is Map<String, dynamic>
        ? metadataRaw
        : metadataRaw is Map
        ? Map<String, dynamic>.from(metadataRaw)
        : null;
    List<String> urls = [];

    if (json['type'] == 'album' && metadata != null) {
      final images = metadata['images'] as List?;
      if (images != null) {
        urls = images
            .map((img) => (img as Map<String, dynamic>)['url'] as String? ?? '')
            .where((u) => u.isNotEmpty)
            .toList();
      }
    } else if (metadata?['url'] != null) {
      urls = [metadata!['url'] as String];
    }

    return ConversationMediaItem(
      messageId:
          json['message_id'] as String? ?? json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'image',
      urls: urls,
      thumbnail: metadata?['thumbnail'] as String?,
      caption: metadata?['caption'] as String? ?? json['content'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      senderId: json['sender_id'] as String,
      senderName: json['sender_name'] as String?,
    );
  }
}

class ConversationFileItem {
  final String messageId;
  final String name;
  final String? url;
  final String? mimeType;
  final int? size;
  final DateTime createdAt;
  final String senderId;
  final String? senderName;

  const ConversationFileItem({
    required this.messageId,
    required this.name,
    this.url,
    this.mimeType,
    this.size,
    required this.createdAt,
    required this.senderId,
    this.senderName,
  });

  factory ConversationFileItem.fromJson(Map<String, dynamic> json) {
    final metadataRaw = json['metadata'];
    final metadata = metadataRaw is Map<String, dynamic>
        ? metadataRaw
        : metadataRaw is Map
        ? Map<String, dynamic>.from(metadataRaw)
        : null;
    final originalName = metadata?['originalName'] as String?;
    final content = json['content'] as String?;
    final name = (originalName?.trim().isNotEmpty ?? false)
        ? originalName!.trim()
        : ((content?.trim().isNotEmpty ?? false) ? content!.trim() : 'File');

    return ConversationFileItem(
      messageId:
          json['message_id'] as String? ?? json['id'] as String? ?? '',
      name: name,
      url: metadata?['url'] as String?,
      mimeType: metadata?['mimeType'] as String?,
      size: (metadata?['size'] as num?)?.toInt(),
      createdAt: DateTime.parse(json['created_at'] as String),
      senderId: json['sender_id'] as String,
      senderName: json['sender_name'] as String?,
    );
  }
}

class ConversationLinkItem {
  final String messageId;
  final String url;
  final String content;
  final DateTime createdAt;
  final String senderId;
  final String? senderName;

  const ConversationLinkItem({
    required this.messageId,
    required this.url,
    required this.content,
    required this.createdAt,
    required this.senderId,
    this.senderName,
  });

  factory ConversationLinkItem.fromJson(Map<String, dynamic> json) {
    final linksRaw = json['links'];
    final links = linksRaw is List
        ? linksRaw.whereType<String>().toList(growable: false)
        : const <String>[];
    final url = links.isNotEmpty ? links.first : '';

    return ConversationLinkItem(
      messageId:
          json['message_id'] as String? ?? json['id'] as String? ?? '',
      url: url,
      content: json['content'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      senderId: json['sender_id'] as String,
      senderName: json['sender_name'] as String?,
    );
  }
}

class ConversationAssetsSummary {
  final int membersCount;
  final int mediaCount;
  final int filesCount;
  final int linksCount;

  const ConversationAssetsSummary({
    required this.membersCount,
    required this.mediaCount,
    required this.filesCount,
    required this.linksCount,
  });

  factory ConversationAssetsSummary.fromJson(Map<String, dynamic> json) {
    return ConversationAssetsSummary(
      membersCount: json['members_count'] as int? ?? 0,
      mediaCount: json['media_count'] as int? ?? 0,
      filesCount: json['files_count'] as int? ?? 0,
      linksCount: json['links_count'] as int? ?? 0,
    );
  }
}

// Providers
@riverpod
class ConversationMediaList extends _$ConversationMediaList {
  static const _pageSize = 30;
  static const _maxPages = 20;
  String? _nextCursor;
  bool _hasMore = true;

  @override
  Future<List<ConversationMediaItem>> build(String conversationId) async {
    _nextCursor = null;
    _hasMore = true;
    return _fetchAllMedia();
  }

  Future<List<ConversationMediaItem>> _fetchMedia({String? cursor}) async {
    final repo = ref.read(chatRepositoryProvider);
    final response = await repo.getConversationMedia(
      convId: conversationId,
      cursor: cursor,
      limit: _pageSize,
    );

    final rawItems = _normalizeAssetItemsResponse(response);
    final items = rawItems.map(ConversationMediaItem.fromJson).toList();

    _nextCursor = _readCursor(response);
    _hasMore = _readHasMore(response, items.length);

    return items;
  }

  Future<List<ConversationMediaItem>> _fetchAllMedia() async {
    final allItems = <ConversationMediaItem>[];
    String? cursor;
    var page = 0;

    while (page < _maxPages) {
      final pageItems = await _fetchMedia(cursor: cursor);
      allItems.addAll(pageItems);
      page++;

      if (!_hasMore || _nextCursor == null || _nextCursor == cursor) {
        break;
      }
      cursor = _nextCursor;
    }

    return allItems;
  }

  Future<void> loadMore() async {
    if (!_hasMore || _nextCursor == null) return;

    final current = state.valueOrNull ?? [];
    final newItems = await _fetchMedia(cursor: _nextCursor);
    state = AsyncValue.data([...current, ...newItems]);
  }

  bool get hasMore => _hasMore;
}

@riverpod
class ConversationFilesList extends _$ConversationFilesList {
  static const _pageSize = 30;
  static const _maxPages = 20;
  String? _nextCursor;
  bool _hasMore = true;

  @override
  Future<List<ConversationFileItem>> build(String conversationId) async {
    _nextCursor = null;
    _hasMore = true;
    return _fetchAllFiles();
  }

  Future<List<ConversationFileItem>> _fetchFiles({String? cursor}) async {
    final repo = ref.read(chatRepositoryProvider);
    final response = await repo.getConversationFiles(
      convId: conversationId,
      cursor: cursor,
      limit: _pageSize,
    );

    final rawItems = _normalizeAssetItemsResponse(response);
    final items = rawItems.map(ConversationFileItem.fromJson).toList();

    _nextCursor = _readCursor(response);
    _hasMore = _readHasMore(response, items.length);

    return items;
  }

  Future<List<ConversationFileItem>> _fetchAllFiles() async {
    final allItems = <ConversationFileItem>[];
    String? cursor;
    var page = 0;

    while (page < _maxPages) {
      final pageItems = await _fetchFiles(cursor: cursor);
      allItems.addAll(pageItems);
      page++;

      if (!_hasMore || _nextCursor == null || _nextCursor == cursor) {
        break;
      }
      cursor = _nextCursor;
    }

    return allItems;
  }

  Future<void> loadMore() async {
    if (!_hasMore || _nextCursor == null) return;

    final current = state.valueOrNull ?? [];
    final newItems = await _fetchFiles(cursor: _nextCursor);
    state = AsyncValue.data([...current, ...newItems]);
  }

  bool get hasMore => _hasMore;
}

@riverpod
class ConversationLinksList extends _$ConversationLinksList {
  static const _pageSize = 30;
  static const _maxPages = 20;
  String? _nextCursor;
  bool _hasMore = true;

  @override
  Future<List<ConversationLinkItem>> build(String conversationId) async {
    _nextCursor = null;
    _hasMore = true;
    return _fetchAllLinks();
  }

  Future<List<ConversationLinkItem>> _fetchLinks({String? cursor}) async {
    final repo = ref.read(chatRepositoryProvider);
    final response = await repo.getConversationLinks(
      convId: conversationId,
      cursor: cursor,
      limit: _pageSize,
    );

    final rawItems = _normalizeAssetItemsResponse(response);
    final items = rawItems.map(ConversationLinkItem.fromJson).toList();

    _nextCursor = _readCursor(response);
    _hasMore = _readHasMore(response, items.length);

    return items;
  }

  Future<List<ConversationLinkItem>> _fetchAllLinks() async {
    final allItems = <ConversationLinkItem>[];
    String? cursor;
    var page = 0;

    while (page < _maxPages) {
      final pageItems = await _fetchLinks(cursor: cursor);
      allItems.addAll(pageItems);
      page++;

      if (!_hasMore || _nextCursor == null || _nextCursor == cursor) {
        break;
      }
      cursor = _nextCursor;
    }

    return allItems;
  }

  Future<void> loadMore() async {
    if (!_hasMore || _nextCursor == null) return;

    final current = state.valueOrNull ?? [];
    final newItems = await _fetchLinks(cursor: _nextCursor);
    state = AsyncValue.data([...current, ...newItems]);
  }

  bool get hasMore => _hasMore;
}

@riverpod
Future<ConversationAssetsSummary> conversationAssetsSummary(
  ConversationAssetsSummaryRef ref,
  String conversationId,
) async {
  final repo = ref.read(chatRepositoryProvider);
  final response = await repo.getConversationAssetsSummary(convId: conversationId);
  return ConversationAssetsSummary.fromJson(response);
}
