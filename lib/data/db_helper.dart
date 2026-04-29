import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await initDb();
    return _db!;
  }

  Future<Database> initDb() async {
    final path = join(await getDatabasesPath(), 'app.db');

    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE notes ADD COLUMN is_favorite INTEGER DEFAULT 0",
          );
          await db.execute(
            "ALTER TABLE sync_queue ADD COLUMN note_id TEXT DEFAULT ''",
          );
          await db.execute(
            "ALTER TABLE sync_queue ADD COLUMN status TEXT DEFAULT 'pending'",
          );
          await db.execute(
            "ALTER TABLE sync_queue ADD COLUMN created_at INTEGER DEFAULT 0",
          );
        }
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notes(
        id TEXT PRIMARY KEY,
        content TEXT,
        is_favorite INTEGER DEFAULT 0,
        updated_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue(
        id TEXT PRIMARY KEY,
        note_id TEXT,
        type TEXT,
        payload TEXT,
        retry_count INTEGER DEFAULT 0,
        status TEXT DEFAULT 'pending',
        created_at INTEGER
      )
    ''');
  }

  // Notes
  Future<void> insertNote(Map<String, dynamic> note) async {
    final database = await db;
    await database.insert(
      "notes",
      note,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getNotes() async {
    final database = await db;
    return database.query("notes", orderBy: "updated_at DESC");
  }

  Future<Map<String, dynamic>?> getNoteById(String id) async {
    final database = await db;
    final result = await database.query(
      "notes",
      where: "id=?",
      whereArgs: [id],
    );
    if (result.isEmpty) {
      return null;
    }
    return result.first;
  }

  Future<void> upsertNotes(List<Map<String, dynamic>> notes) async {
    final database = await db;
    final batch = database.batch();
    for (final note in notes) {
      batch.insert("notes", note, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> deleteNote(String id) async {
    final database = await db;
    await database.delete("notes", where: "id=?", whereArgs: [id]);
  }

  // Queue
  Future<void> insertQueue(Map<String, dynamic> action) async {
    final database = await db;
    await database.insert(
      "sync_queue",
      action,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getQueue() async {
    final database = await db;
    return database.query(
      "sync_queue",
      where: "status = ?",
      whereArgs: ["pending"],
      orderBy: "created_at ASC",
    );
  }

  Future<void> deleteQueue(String id) async {
    final database = await db;
    await database.delete("sync_queue", where: "id=?", whereArgs: [id]);
  }

  Future<void> deleteQueueByNoteId(String noteId) async {
    final database = await db;
    await database.delete("sync_queue", where: "note_id=?", whereArgs: [noteId]);
  }

  Future<void> updateRetry(String id, int retry) async {
    final database = await db;
    await database.update(
      "sync_queue",
      {"retry_count": retry},
      where: "id=?",
      whereArgs: [id],
    );
  }

  Future<void> updateQueueStatus(String id, String status) async {
    final database = await db;
    await database.update(
      "sync_queue",
      {"status": status},
      where: "id=?",
      whereArgs: [id],
    );
  }

  Future<int> getPendingQueueSize() async {
    final database = await db;
    final result = await database.rawQuery(
      "SELECT COUNT(*) as count FROM sync_queue WHERE status = 'pending'",
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<Set<String>> getPendingDeleteNoteIds() async {
    final database = await db;
    final rows = await database.query(
      "sync_queue",
      columns: ["note_id"],
      where: "status = ? AND type = ?",
      whereArgs: ["pending", "delete_note"],
    );
    return rows
        .map((row) => row["note_id"]?.toString() ?? "")
        .where((id) => id.isNotEmpty)
        .toSet();
  }
}
