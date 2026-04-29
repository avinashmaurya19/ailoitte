import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'note_event.dart';
import 'note_state.dart';
import '../data/repository.dart';

class NoteBloc extends Bloc<NoteEvent, NoteState> {
  final NoteRepository repository;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  NoteBloc(this.repository) : super(NoteState.initial()) {
    on<LoadNotes>(_onLoadNotes);
    on<AddNote>(_onAddNote);
    on<ToggleFavorite>(_onToggleFavorite);
    on<DeleteNote>(_onDeleteNote);
    on<RefreshRemoteNotes>(_onRefreshRemoteNotes);
    on<SyncNotes>(_onSyncNotes);
    on<SimulateSingleSyncFailure>(_onSimulateSingleSyncFailure);
    on<ConnectivityRestored>(_onConnectivityRestored);
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final isOffline = results.contains(ConnectivityResult.none);
      if (!isOffline) {
        add(ConnectivityRestored());
      }
    });
  }

  Future<void> _onLoadNotes(LoadNotes event, Emitter<NoteState> emit) async {
    emit(state.copyWith(isLoading: true));
    await _reloadLocalState(emit, isLoading: false);
    add(RefreshRemoteNotes());
  }

  Future<void> _onAddNote(AddNote event, Emitter<NoteState> emit) async {
    final content = event.content.trim();
    if (content.isEmpty) return;
    await repository.addNote(content);
    add(LoadNotes());
  }

  Future<void> _onToggleFavorite(
    ToggleFavorite event,
    Emitter<NoteState> emit,
  ) async {
    await repository.toggleFavorite(event.noteId);
    add(LoadNotes());
  }

  Future<void> _onDeleteNote(DeleteNote event, Emitter<NoteState> emit) async {
    await repository.deleteNote(event.noteId);
    add(LoadNotes());
  }

  Future<void> _onRefreshRemoteNotes(
    RefreshRemoteNotes event,
    Emitter<NoteState> emit,
  ) async {
    try {
      await repository.refreshFromRemote();
      await _reloadLocalState(emit, lastMessage: "Background refresh complete");
    } catch (_) {
      emit(state.copyWith(lastMessage: "Background refresh failed (offline)"));
    } finally {
      event.completer?.complete();
    }
  }

  Future<void> _onSyncNotes(SyncNotes event, Emitter<NoteState> emit) async {
    emit(state.copyWith(isSyncing: true));
    await repository.syncQueue();
    await _reloadLocalState(emit, isSyncing: false);
  }

  Future<void> _onSimulateSingleSyncFailure(
    SimulateSingleSyncFailure event,
    Emitter<NoteState> emit,
  ) async {
    repository.sync.enableSingleFailureSimulation();
    emit(
      state.copyWith(lastMessage: "Next sync call will fail once, then retry"),
    );
  }

  Future<void> _onConnectivityRestored(
    ConnectivityRestored event,
    Emitter<NoteState> emit,
  ) async {
    await repository.syncQueue();
    await _reloadLocalState(
      emit,
      lastMessage: "Network restored: queued actions synced",
    );
    add(RefreshRemoteNotes());
  }

  Future<void> _reloadLocalState(
    Emitter<NoteState> emit, {
    bool? isLoading,
    bool? isSyncing,
    String? lastMessage,
  }) async {
    final notes = await repository.getLocalNotes();
    final pendingQueueSize = await repository.getPendingQueueSize();
    final metrics = repository.sync.metrics.value;
    emit(
      state.copyWith(
        isLoading: isLoading ?? state.isLoading,
        isSyncing: isSyncing ?? state.isSyncing,
        notes: notes,
        pendingQueueSize: pendingQueueSize,
        syncSuccessCount: metrics.successCount,
        syncFailCount: metrics.failCount,
        lastMessage: lastMessage ?? state.lastMessage,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _connectivitySub?.cancel();
    return super.close();
  }
}
