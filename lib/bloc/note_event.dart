import 'dart:async';

abstract class NoteEvent {}

class LoadNotes extends NoteEvent {}

class AddNote extends NoteEvent {
  final String content;
  AddNote(this.content);
}

class ToggleFavorite extends NoteEvent {
  final String noteId;
  ToggleFavorite(this.noteId);
}

class DeleteNote extends NoteEvent {
  final String noteId;
  DeleteNote(this.noteId);
}

class RefreshRemoteNotes extends NoteEvent {
  final Completer<void>? completer;
  RefreshRemoteNotes({this.completer});
}

class SyncNotes extends NoteEvent {}

class SimulateSingleSyncFailure extends NoteEvent {}

class ConnectivityRestored extends NoteEvent {}
