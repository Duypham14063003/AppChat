import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'connection/connection_stub.dart'
    if (dart.library.ffi) 'connection/connection_native.dart'
    if (dart.library.js_interop) 'connection/connection_web.dart';
import 'tables.dart';
import 'chat_dao.dart';
import 'hr_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    LocalConversations,
    LocalMessages,
    PendingUploads,
    LocalMessageReactions,
    LocalPinnedMessages,
    LocalBookmarkedMessages,
    LocalAttendance,
  ],
  daos: [ChatDao, HrDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        // Create FTS5 virtual table for message content search
        await customStatement(
          'CREATE VIRTUAL TABLE IF NOT EXISTS messages_fts USING fts5(id UNINDEXED, content, conv_id UNINDEXED)',
        );
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await customStatement(
            'ALTER TABLE local_conversations ADD COLUMN other_member_last_seen_at INTEGER',
          );
        }
        if (from < 3) {
          await m.createTable(pendingUploads);
        }
        if (from < 4) {
          await m.createTable(localMessageReactions);
        }
        if (from < 5) {
          await customStatement(
            'ALTER TABLE local_conversations ADD COLUMN unread_mention_count INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (from < 6) {
          await customStatement(
            'ALTER TABLE local_messages ADD COLUMN forwarded_from_id TEXT',
          );
          await customStatement(
            'ALTER TABLE local_messages ADD COLUMN forwarded_from_sender TEXT',
          );
        }
        if (from < 7) {
          await m.createTable(localPinnedMessages);
        }
        if (from < 8) {
          await m.createTable(localAttendance);
        }
        if (from < 9) {
          await m.createTable(localBookmarkedMessages);
        }
      },
    );
  }
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final chatDaoProvider = Provider<ChatDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.chatDao;
});

final hrDaoProvider = Provider<HrDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.hrDao;
});
