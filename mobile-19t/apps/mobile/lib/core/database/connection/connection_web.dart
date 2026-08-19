import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:sqlite3/wasm.dart';

QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final sqlite3 = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
    try {
      sqlite3.registerVirtualFileSystem(
        await IndexedDbFileSystem.open(dbName: 'app_19t'),
        makeDefault: true,
      );
    } catch (_) {
      // IndexedDB conflict on hot restart — use in-memory fallback
      sqlite3.registerVirtualFileSystem(
        InMemoryFileSystem(),
        makeDefault: true,
      );
    }
    return WasmDatabase(sqlite3: sqlite3, path: '/app_19t.db');
  });
}
