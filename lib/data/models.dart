class Note {
  final String id;
  final String content;
  final bool isFavorite;
  final int updatedAt;

  Note({
    required this.id,
    required this.content,
    required this.isFavorite,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    "id": id,
    "content": content,
    "is_favorite": isFavorite ? 1 : 0,
    "updated_at": updatedAt,
  };

  Map<String, dynamic> toFirestoreMap() => {
    "id": id,
    "content": content,
    "is_favorite": isFavorite,
    "updated_at": updatedAt,
  };

  factory Note.fromMap(Map<String, dynamic> map) => Note(
    id: map["id"],
    content: map["content"],
    isFavorite: map["is_favorite"] == 1 || map["is_favorite"] == true,
    updatedAt: map["updated_at"],
  );
}

class SyncAction {
  final String id;
  final String noteId;
  final String type;
  final String payload;
  int retryCount;
  final String status;
  final int createdAt;

  SyncAction({
    required this.id,
    required this.noteId,
    required this.type,
    required this.payload,
    required this.retryCount,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    "id": id,
    "note_id": noteId,
    "type": type,
    "payload": payload,
    "retry_count": retryCount,
    "status": status,
    "created_at": createdAt,
  };

  factory SyncAction.fromMap(Map<String, dynamic> map) => SyncAction(
    id: map["id"],
    noteId: map["note_id"],
    type: map["type"],
    payload: map["payload"],
    retryCount: map["retry_count"] ?? 0,
    status: map["status"] ?? "pending",
    createdAt: map["created_at"] ?? 0,
  );
}
