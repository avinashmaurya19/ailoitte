import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'note_event.dart';
import 'note_state.dart';
import '../data/repository.dart';

class NoteBloc extends Bloc<NoteEvent, NoteState> {
  final NoteRepository repo;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  NoteBloc(this.repo) : super(NoteState.initial()) {
    on<LoadNotes>(_onLoadNotes);
    on<AddNote>(_onAddNote);
    on<ToggleFavorite>(_onToggleFavorite);
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
    final notes = await repo.getLocalNotes();
    final pending = await repo.getPendingQueueSize();
    final metrics = repo.sync.metrics.value;
    emit(
      state.copyWith(
        isLoading: false,
        notes: notes,
        pendingQueueSize: pending,
        syncSuccessCount: metrics.successCount,
        syncFailCount: metrics.failCount,
      ),
    );
    add(RefreshRemoteNotes());
  }

  Future<void> _onAddNote(AddNote event, Emitter<NoteState> emit) async {
    final content = event.content.trim();
    if (content.isEmpty) return;
    await repo.addNote(content);
    add(LoadNotes());
  }

  Future<void> _onToggleFavorite(
    ToggleFavorite event,
    Emitter<NoteState> emit,
  ) async {
    await repo.toggleFavorite(event.noteId);
    add(LoadNotes());
  }

  Future<void> _onRefreshRemoteNotes(
    RefreshRemoteNotes event,
    Emitter<NoteState> emit,
  ) async {
    try {
      await repo.refreshFromRemote();
      final refreshed = await repo.getLocalNotes();
      emit(
        state.copyWith(
          notes: refreshed,
          lastMessage: "Background refresh complete",
        ),
      );
    } catch (_) {
      emit(state.copyWith(lastMessage: "Background refresh failed (offline)"));
    } finally {
      event.completer?.complete();
    }
  }

  Future<void> _onSyncNotes(SyncNotes event, Emitter<NoteState> emit) async {
    emit(state.copyWith(isSyncing: true));
    await repo.syncQueue();
    final pending = await repo.getPendingQueueSize();
    final metrics = repo.sync.metrics.value;
    emit(
      state.copyWith(
        isSyncing: false,
        pendingQueueSize: pending,
        syncSuccessCount: metrics.successCount,
        syncFailCount: metrics.failCount,
      ),
    );
  }

  Future<void> _onSimulateSingleSyncFailure(
    SimulateSingleSyncFailure event,
    Emitter<NoteState> emit,
  ) async {
    repo.sync.enableSingleFailureSimulation();
    emit(
      state.copyWith(lastMessage: "Next sync call will fail once, then retry"),
    );
  }

  Future<void> _onConnectivityRestored(
    ConnectivityRestored event,
    Emitter<NoteState> emit,
  ) async {
    await repo.syncQueue();
    final pending = await repo.getPendingQueueSize();
    final metrics = repo.sync.metrics.value;
    emit(
      state.copyWith(
        pendingQueueSize: pending,
        syncSuccessCount: metrics.successCount,
        syncFailCount: metrics.failCount,
        lastMessage: "Network restored: queued actions synced",
      ),
    );
    add(RefreshRemoteNotes());
  }

  @override
  Future<void> close() async {
    await _connectivitySub?.cancel();
    return super.close();
  }
}
