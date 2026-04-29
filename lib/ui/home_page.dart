import 'dart:async';

import 'package:ailoitte/bloc/note_bloc.dart';
import 'package:ailoitte/bloc/note_event.dart';
import 'package:ailoitte/bloc/note_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController noteController = TextEditingController();

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<NoteBloc>();

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text("Offline-first Notes"),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              _buildComposerCard(bloc),
              const SizedBox(height: 10),
              Expanded(
                child: BlocBuilder<NoteBloc, NoteState>(
                  builder: (context, state) {
                    if (state.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return Column(
                      children: [
                        _StatusStrip(state: state),
                        const SizedBox(height: 10),
                        Expanded(
                          child: _NotesList(
                            state: state,
                            onRefresh: _refreshNotes,
                            onToggleFavorite: (noteId) {
                              bloc.add(ToggleFavorite(noteId));
                            },
                            onDelete: (noteId) async {
                              final shouldDelete = await _confirmDelete(
                                context,
                              );
                              if (shouldDelete == true && mounted) {
                                bloc.add(DeleteNote(noteId));
                              }
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComposerCard(NoteBloc bloc) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: noteController,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Write a note...",
                filled: true,
                fillColor: const Color(0xFFF0F3FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  bloc.add(AddNote(noteController.text));
                  noteController.clear();
                },
                icon: const Icon(Icons.add),
                label: const Text("Add Note"),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => bloc.add(SyncNotes()),
                icon: const Icon(Icons.sync),
                label: const Text("Sync Now"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshNotes() {
    final bloc = context.read<NoteBloc>();
    final completer = Completer<void>();
    bloc.add(RefreshRemoteNotes(completer: completer));
    return completer.future;
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Delete note?"),
          content: const Text(
            "This will remove the note locally and sync deletion to Firestore.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
  }
}

class _NotesList extends StatelessWidget {
  final NoteState state;
  final Future<void> Function() onRefresh;
  final void Function(String noteId) onToggleFavorite;
  final Future<void> Function(String noteId) onDelete;

  const _NotesList({
    required this.state,
    required this.onRefresh,
    required this.onToggleFavorite,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: state.notes.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 140),
                Center(
                  child: Text(
                    "No notes yet.\nPull down to refresh.",
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: state.notes.length,
              separatorBuilder: (_, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final note = state.notes[index];
                return Card(
                  margin: EdgeInsets.zero,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    title: Text(
                      note.content.isEmpty ? "(empty note)" : note.content,
                    ),
                    subtitle: Text(
                      "updatedAt: ${note.updatedAt}",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => onToggleFavorite(note.id),
                          icon: Icon(
                            note.isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: note.isFavorite
                                ? Colors.red
                                : Colors.grey.shade600,
                          ),
                        ),
                        IconButton(
                          onPressed: () => onDelete(note.id),
                          icon: const Icon(Icons.delete_outline),
                          color: Colors.red.shade400,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  final NoteState state;

  const _StatusStrip({required this.state});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricChip(
                  icon: Icons.pending_actions_outlined,
                  label: "Pending ${state.pendingQueueSize}",
                  bgColor: const Color(0xFFFFF4D9),
                ),
                _MetricChip(
                  icon: Icons.check_circle_outline,
                  label: "Success ${state.syncSuccessCount}",
                  bgColor: const Color(0xFFDFF8E6),
                ),
                _MetricChip(
                  icon: Icons.error_outline,
                  label: "Failed ${state.syncFailCount}",
                  bgColor: const Color(0xFFFFE3E3),
                ),
                if (state.isSyncing)
                  const _MetricChip(
                    icon: Icons.sync,
                    label: "Syncing...",
                    bgColor: Color(0xFFE3EDFF),
                  ),
              ],
            ),
            if (state.lastMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                state.lastMessage!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bgColor;

  const _MetricChip({
    required this.icon,
    required this.label,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
