import 'package:drift/drift.dart';
import 'app_database.dart';
import 'tables.dart';

part 'chat_dao.g.dart';

@DriftAccessor(
  tables: [
    LocalConversations,
    LocalMessages,
    PendingUploads,
    LocalMessageReactions,
    LocalPinnedMessages,
    LocalBookmarkedMessages,
  ],
)
class ChatDao extends DatabaseAccessor<AppDatabase> with _$ChatDaoMixin {
  ChatDao(super.db);

  Future<void> _syncMessageToFts({
    required String id,
    required String convId,
    String? content,
    DateTime? deletedAt,
  }) async {
    if (deletedAt != null || content == null || content.isEmpty) {
      await customStatement('DELETE FROM messages_fts WHERE id = ?', [id]);
      return;
    }

    await customStatement(
      'INSERT OR REPLACE INTO messages_fts (id, content, conv_id) VALUES (?, ?, ?)',
      [id, content, convId],
    );
  }

  // --- Conversations ---

  Future<void> insertConversation(LocalConversationsCompanion entry) {
    return into(localConversations).insertOnConflictUpdate(entry);
  }

  Future<void> insertConversations(
    List<LocalConversationsCompanion> entries,
  ) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(localConversations, entries);
    });
  }

  Stream<List<LocalConversation>> watchConversations() {
    return (select(
      localConversations,
    )..orderBy([(t) => OrderingTerm.desc(t.lastMessageAt)])).watch();
  }

  Future<List<LocalConversation>> getConversations() {
    return (select(
      localConversations,
    )..orderBy([(t) => OrderingTerm.desc(t.lastMessageAt)])).get();
  }

  Future<LocalConversation?> getConversation(String id) {
    return (select(
      localConversations,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> updateConversation(
    String id,
    LocalConversationsCompanion entry,
  ) {
    return (update(
      localConversations,
    )..where((t) => t.id.equals(id))).write(entry);
  }

  // --- Messages ---

  Future<void> insertMessage(LocalMessagesCompanion entry) async {
    await into(localMessages).insertOnConflictUpdate(entry);
    final id = entry.id.value;
    final content = entry.content.present ? entry.content.value : null;
    final convId = entry.convId.value;
    final deletedAt = entry.deletedAt.present ? entry.deletedAt.value : null;
    await _syncMessageToFts(
      id: id,
      convId: convId,
      content: content,
      deletedAt: deletedAt,
    );
  }

  Future<void> insertMessages(List<LocalMessagesCompanion> entries) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(localMessages, entries);
    });
  }

  Stream<List<LocalMessage>> watchMessages(String convId, {int limit = 50}) {
    return (select(localMessages)
          ..where((t) => t.convId.equals(convId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(limit))
        .watch();
  }

  Future<List<LocalMessage>> getMessages(
    String convId, {
    int limit = 50,
    DateTime? before,
  }) {
    final query = select(localMessages)
      ..where((t) => t.convId.equals(convId))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
      ..limit(limit);
    if (before != null) {
      query.where((t) => t.createdAt.isSmallerThanValue(before));
    }
    return query.get();
  }

  Future<LocalMessage?> getMessage(String id) {
    return (select(
      localMessages,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> updateMessageStatus(String id, String status) {
    return (update(localMessages)..where((t) => t.id.equals(id))).write(
      LocalMessagesCompanion(status: Value(status)),
    );
  }

  Future<void> updateMessageMetadata(String id, String metadata) {
    return (update(localMessages)..where((t) => t.id.equals(id))).write(
      LocalMessagesCompanion(metadata: Value(metadata)),
    );
  }

  Future<void> updateMessageFromRemote(
    String id, {
    String? content,
    String? metadata,
    DateTime? editedAt,
    DateTime? deletedAt,
  }) async {
    final existing = await getMessage(id);
    if (existing == null) return;

    await (update(localMessages)..where((t) => t.id.equals(id))).write(
      LocalMessagesCompanion(
        content: Value(content),
        metadata: Value(metadata),
        editedAt: Value(editedAt),
        deletedAt: Value(deletedAt),
      ),
    );

    await _syncMessageToFts(
      id: existing.id,
      convId: existing.convId,
      content: content,
      deletedAt: deletedAt,
    );
  }

  Future<List<LocalMessage>> getPendingMessages() {
    return (select(localMessages)
          ..where((t) => t.status.equals('pending'))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<void> incrementRetryCount(String id) async {
    await customStatement(
      'UPDATE local_messages SET retry_count = retry_count + 1 WHERE id = ?',
      [id],
    );
  }

  Future<void> resetRetryCount(String id) async {
    await (update(localMessages)..where((t) => t.id.equals(id))).write(
      const LocalMessagesCompanion(retryCount: Value(0)),
    );
  }

  Future<void> resetUnreadCount(String convId) {
    return (update(localConversations)..where((t) => t.id.equals(convId)))
        .write(const LocalConversationsCompanion(unreadCount: Value(0)));
  }

  Future<void> resetUnreadMentionCount(String convId) {
    return (update(localConversations)..where((t) => t.id.equals(convId)))
        .write(const LocalConversationsCompanion(unreadMentionCount: Value(0)));
  }

  Future<void> markConversationViewed(String convId, {DateTime? viewedAt}) {
    return (update(
      localConversations,
    )..where((t) => t.id.equals(convId))).write(
      LocalConversationsCompanion(
        unreadCount: const Value(0),
        unreadMentionCount: const Value(0),
        lastViewedAt: Value(viewedAt ?? DateTime.now()),
      ),
    );
  }

  // --- Search (FTS5) ---

  static String _buildFtsQuery(String query) {
    return query
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => '"$w"*')
        .join(' ');
  }

  Future<List<LocalMessage>> searchMessages(String query) async {
    final ftsQuery = _buildFtsQuery(query);
    final results = await customSelect(
      '''SELECT m.* FROM messages_fts fts
         INNER JOIN local_messages m ON m.id = fts.id
         WHERE messages_fts MATCH ? AND m.deleted_at IS NULL
         ORDER BY m.created_at DESC LIMIT 50''',
      variables: [Variable.withString(ftsQuery)],
      readsFrom: {localMessages},
    ).get();

    return results.map((row) => localMessages.map(row.data)).toList();
  }

  Future<List<LocalMessage>> searchMessagesInConversation(
    String convId,
    String query,
  ) async {
    final ftsQuery = _buildFtsQuery(query);
    final results = await customSelect(
      '''SELECT m.* FROM messages_fts fts
         INNER JOIN local_messages m ON m.id = fts.id
         WHERE messages_fts MATCH ? AND m.conv_id = ? AND m.deleted_at IS NULL
         ORDER BY m.created_at DESC LIMIT 100''',
      variables: [Variable.withString(ftsQuery), Variable.withString(convId)],
      readsFrom: {localMessages},
    ).get();

    return results.map((row) => localMessages.map(row.data)).toList();
  }

  Future<List<Map<String, dynamic>>> searchMessagesWithContext(
    String query, {
    int limit = 20,
  }) async {
    final ftsQuery = _buildFtsQuery(query);
    final results = await customSelect(
      '''SELECT m.*, c.name AS conv_name, c.avatar_url AS conv_avatar,
                c.type AS conv_type, c.other_member_name, c.other_member_avatar
         FROM messages_fts fts
         INNER JOIN local_messages m ON m.id = fts.id
         INNER JOIN local_conversations c ON c.id = m.conv_id
         WHERE messages_fts MATCH ? AND m.deleted_at IS NULL
         ORDER BY m.created_at DESC LIMIT ?''',
      variables: [Variable.withString(ftsQuery), Variable.withInt(limit)],
      readsFrom: {localMessages, localConversations},
    ).get();

    return results.map((row) => row.data).toList();
  }

  // --- Sync ---

  Future<void> deleteConversationsNotIn(Set<String> ids) {
    return (delete(localConversations)..where((t) => t.id.isNotIn(ids))).go();
  }

  // --- Eviction ---

  Future<void> evictOldData() async {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

    // Delete messages older than 7 days
    await (delete(
      localMessages,
    )..where((t) => t.createdAt.isSmallerThanValue(sevenDaysAgo))).go();

    // Delete conversations not viewed in 30 days
    await (delete(localConversations)..where(
          (t) =>
              t.lastViewedAt.isNotNull() &
              t.lastViewedAt.isSmallerThanValue(thirtyDaysAgo),
        ))
        .go();
  }

  // --- Pending Uploads ---

  Future<void> insertPendingUpload(PendingUploadsCompanion entry) {
    return into(pendingUploads).insertOnConflictUpdate(entry);
  }

  Future<List<PendingUpload>> getPendingUploads() {
    return (select(pendingUploads)
          ..where((t) => t.status.equals('queued'))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<void> updatePendingUploadStatus(
    String id,
    String status, {
    int? retryCount,
  }) {
    final companion = PendingUploadsCompanion(
      status: Value(status),
      retryCount: retryCount != null ? Value(retryCount) : const Value.absent(),
    );
    return (update(
      pendingUploads,
    )..where((t) => t.id.equals(id))).write(companion);
  }

  Future<void> deletePendingUpload(String id) {
    return (delete(pendingUploads)..where((t) => t.id.equals(id))).go();
  }

  // --- Reactions ---

  Future<void> upsertReaction(
    String messageId,
    String userId,
    String emoji,
    String userName,
  ) {
    return into(localMessageReactions).insertOnConflictUpdate(
      LocalMessageReactionsCompanion.insert(
        messageId: messageId,
        userId: userId,
        emoji: emoji,
        userName: userName,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> deleteReaction(String messageId, String userId, String emoji) {
    return (delete(localMessageReactions)..where(
          (t) =>
              t.messageId.equals(messageId) &
              t.userId.equals(userId) &
              t.emoji.equals(emoji),
        ))
        .go();
  }

  Future<List<LocalMessageReaction>> getReactionsForMessage(String messageId) {
    return (select(localMessageReactions)
          ..where((t) => t.messageId.equals(messageId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Stream<List<LocalMessageReaction>> watchReactionsForMessage(
    String messageId,
  ) {
    return (select(localMessageReactions)
          ..where((t) => t.messageId.equals(messageId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  Future<void> replaceReactionsForMessage(
    String messageId,
    List<LocalMessageReactionsCompanion> reactions,
  ) async {
    await transaction(() async {
      await (delete(
        localMessageReactions,
      )..where((t) => t.messageId.equals(messageId))).go();
      if (reactions.isNotEmpty) {
        await batch((b) {
          b.insertAllOnConflictUpdate(localMessageReactions, reactions);
        });
      }
    });
  }

  // --- Pinned Messages ---

  Future<void> insertPinnedMessage(LocalPinnedMessagesCompanion entry) {
    return into(localPinnedMessages).insertOnConflictUpdate(entry);
  }

  Future<void> deletePinnedMessage(String convId, String messageId) {
    return (delete(localPinnedMessages)..where(
          (t) => t.convId.equals(convId) & t.messageId.equals(messageId),
        ))
        .go();
  }

  Future<void> deleteAllPinnedMessages(String convId) {
    return (delete(
      localPinnedMessages,
    )..where((t) => t.convId.equals(convId))).go();
  }

  Future<List<LocalPinnedMessage>> getPinnedMessages(String convId) {
    return (select(localPinnedMessages)
          ..where((t) => t.convId.equals(convId))
          ..orderBy([(t) => OrderingTerm.desc(t.pinnedAt)]))
        .get();
  }

  Stream<List<LocalPinnedMessage>> watchPinnedMessages(String convId) {
    return (select(localPinnedMessages)
          ..where((t) => t.convId.equals(convId))
          ..orderBy([(t) => OrderingTerm.desc(t.pinnedAt)]))
        .watch();
  }

  // --- Bookmarked Messages ---

  Future<void> insertBookmarkedMessage(LocalBookmarkedMessagesCompanion entry) {
    return into(localBookmarkedMessages).insertOnConflictUpdate(entry);
  }

  Future<void> deleteBookmarkedMessage(
    String userId,
    String convId,
    String messageId,
  ) {
    return (delete(localBookmarkedMessages)..where(
          (t) =>
              t.userId.equals(userId) &
              t.convId.equals(convId) &
              t.messageId.equals(messageId),
        ))
        .go();
  }

  Future<void> deleteAllBookmarkedMessages(String userId, String convId) {
    return (delete(
      localBookmarkedMessages,
    )..where((t) => t.userId.equals(userId) & t.convId.equals(convId))).go();
  }

  Future<List<LocalBookmarkedMessage>> getBookmarkedMessages(
    String userId,
    String convId,
  ) {
    return (select(localBookmarkedMessages)
          ..where((t) => t.userId.equals(userId) & t.convId.equals(convId))
          ..orderBy([(t) => OrderingTerm.desc(t.markedAt)]))
        .get();
  }

  Future<List<LocalBookmarkedMessage>> getAllBookmarkedMessagesForUser(
    String userId,
  ) {
    return (select(localBookmarkedMessages)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([
            (t) => OrderingTerm.desc(t.markedAt),
            (t) => OrderingTerm.desc(t.messageId),
          ]))
        .get();
  }

  Stream<List<LocalBookmarkedMessage>> watchBookmarkedMessages(
    String userId,
    String convId,
  ) {
    return (select(localBookmarkedMessages)
          ..where((t) => t.userId.equals(userId) & t.convId.equals(convId))
          ..orderBy([(t) => OrderingTerm.desc(t.markedAt)]))
        .watch();
  }

  Future<void> deleteAllBookmarkedMessagesForUser(String userId) {
    return (delete(
      localBookmarkedMessages,
    )..where((t) => t.userId.equals(userId))).go();
  }

  Future<List<Map<String, dynamic>>> getGlobalBookmarkedMessages(
    String userId, {
    String? conversationType,
    int limit = 20,
  }) async {
    final variables = <Variable<Object>>[Variable.withString(userId)];
    var paramIdx = 2;
    final buffer = StringBuffer('''SELECT
            b.user_id,
            b.conv_id,
            b.message_id,
            b.marked_at,
            b.message_content,
            b.message_type,
            b.sender_id,
            b.sender_name,
            b.message_created_at,
            c.type AS conversation_type,
            CASE
              WHEN c.type = 'DIRECT' THEN COALESCE(c.other_member_name, c.name)
              ELSE c.name
            END AS conversation_name,
            CASE
              WHEN c.type = 'DIRECT' THEN COALESCE(c.other_member_avatar, c.avatar_url)
              ELSE c.avatar_url
            END AS conversation_avatar_url
          FROM local_bookmarked_messages b
          LEFT JOIN local_conversations c
            ON c.id = b.conv_id
          WHERE b.user_id = ?1''');

    if (conversationType != null && conversationType.isNotEmpty) {
      buffer.write(' AND c.type = ?$paramIdx');
      variables.add(Variable.withString(conversationType));
      paramIdx += 1;
    }

    buffer.write(
      ' ORDER BY b.marked_at DESC, b.message_id DESC LIMIT ?$paramIdx',
    );
    variables.add(Variable.withInt(limit));

    final rows = await customSelect(
      buffer.toString(),
      variables: variables,
      readsFrom: {localBookmarkedMessages, localConversations},
    ).get();

    return rows.map((row) => row.data).toList(growable: false);
  }
}
