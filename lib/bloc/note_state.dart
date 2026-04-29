import '../data/models.dart';

class NoteState {
  final bool isLoading;
  final bool isSyncing;
  final List<Note> notes;
  final int pendingQueueSize;
  final int syncSuccessCount;
  final int syncFailCount;
  final String? lastMessage;

  const NoteState({
    required this.isLoading,
    required this.isSyncing,
    required this.notes,
    required this.pendingQueueSize,
    required this.syncSuccessCount,
    required this.syncFailCount,
    this.lastMessage,
  });

  factory NoteState.initial() => const NoteState(
    isLoading: true,
    isSyncing: false,
    notes: [],
    pendingQueueSize: 0,
    syncSuccessCount: 0,
    syncFailCount: 0,
    lastMessage: null,
  );

  NoteState copyWith({
    bool? isLoading,
    bool? isSyncing,
    List<Note>? notes,
    int? pendingQueueSize,
    int? syncSuccessCount,
    int? syncFailCount,
    String? lastMessage,
  }) {
    return NoteState(
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      notes: notes ?? this.notes,
      pendingQueueSize: pendingQueueSize ?? this.pendingQueueSize,
      syncSuccessCount: syncSuccessCount ?? this.syncSuccessCount,
      syncFailCount: syncFailCount ?? this.syncFailCount,
      lastMessage: lastMessage,
    );
  }
}
