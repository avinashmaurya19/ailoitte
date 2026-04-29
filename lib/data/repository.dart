import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'db_helper.dart';
import 'models.dart';
import 'sync_manager.dart';

class NoteRepository {
  final DBHelper db;
  final SyncManager sync;
  final firestore = FirebaseFirestore.instance;
  final uuid = Uuid();

  NoteRepository(this.db, this.sync);

  Future<List<Note>> getLocalNotes() async {
    final data = await db.getNotes();
    return data.map((e) => Note.fromMap(e)).toList();
  }

  Future<void> addNote(String content) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final note = Note(
      id: uuid.v4(),
      content: content,
      isFavorite: false,
      updatedAt: now,
    );

    await db.insertNote(note.toMap());
    await _enqueueSyncAction(
      type: "add_note",
      note: note,
      idempotencyKey: buildIdempotencyKey(
        type: "add_note",
        noteId: note.id,
        timestampMs: now,
      ),
    );
    await sync.processQueue();
  }

  Future<void> toggleFavorite(String noteId) async {
    final local = await db.getNoteById(noteId);
    if (local == null) return;

    final oldNote = Note.fromMap(local);
    final now = DateTime.now().millisecondsSinceEpoch;
    final updated = Note(
      id: oldNote.id,
      content: oldNote.content,
      isFavorite: !oldNote.isFavorite,
      updatedAt: now,
    );

    await db.insertNote(updated.toMap());
    await _enqueueSyncAction(
      type: "toggle_favorite",
      note: updated,
      idempotencyKey: buildIdempotencyKey(
        type: "toggle_favorite",
        noteId: updated.id,
        timestampMs: now,
      ),
    );
    await sync.processQueue();
  }

  Future<void> deleteNote(String noteId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.deleteNote(noteId);
    await db.insertQueue({
      "id": buildIdempotencyKey(
        type: "delete_note",
        noteId: noteId,
        timestampMs: now,
      ),
      "note_id": noteId,
      "type": "delete_note",
      "payload": jsonEncode({"id": noteId, "updated_at": now}),
      "retry_count": 0,
      "status": "pending",
      "created_at": now,
    });
    await sync.processQueue();
  }

  Future<void> refreshFromRemote() async {
    final snapshot = await firestore.collection("notes").get();
    final localNotes = await getLocalNotes();
    final localById = {for (final note in localNotes) note.id: note};
    final upserts = <Map<String, dynamic>>[];

    for (final doc in snapshot.docs) {
      final remote = doc.data();
      final remoteNote = Note(
        id: remote["id"]?.toString() ?? doc.id,
        content: remote["content"]?.toString() ?? "",
        isFavorite: remote["is_favorite"] == true,
        updatedAt: remote["updated_at"] is int
            ? remote["updated_at"] as int
            : 0,
      );
      final local = localById[remoteNote.id];

      // LWW conflict strategy: newest updated_at wins.
      if (local == null || remoteNote.updatedAt >= local.updatedAt) {
        upserts.add(remoteNote.toMap());
      }
    }

    if (upserts.isNotEmpty) {
      await db.upsertNotes(upserts);
    }
  }

  Future<int> getPendingQueueSize() => db.getPendingQueueSize();

  Future<void> syncQueue() async {
    await sync.processQueue();
  }

  static String buildIdempotencyKey({
    required String type,
    required String noteId,
    required int timestampMs,
  }) {
    return "$type:$noteId:$timestampMs";
  }

  Future<void> _enqueueSyncAction({
    required String type,
    required Note note,
    required String idempotencyKey,
  }) async {
    await db.insertQueue({
      "id": idempotencyKey,
      "note_id": note.id,
      "type": type,
      "payload": jsonEncode(note.toFirestoreMap()),
      "retry_count": 0,
      "status": "pending",
      "created_at": DateTime.now().millisecondsSinceEpoch,
    });
  }
}
