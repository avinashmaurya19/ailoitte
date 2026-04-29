import 'package:ailoitte/data/repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NoteRepository.buildIdempotencyKey', () {
    test('returns deterministic key for same input', () {
      final key1 = NoteRepository.buildIdempotencyKey(
        type: 'add_note',
        noteId: 'note-1',
        timestampMs: 123456,
      );
      final key2 = NoteRepository.buildIdempotencyKey(
        type: 'add_note',
        noteId: 'note-1',
        timestampMs: 123456,
      );

      expect(key1, key2);
      expect(key1, 'add_note:note-1:123456');
    });

    test('returns different key when timestamp changes', () {
      final key1 = NoteRepository.buildIdempotencyKey(
        type: 'toggle_favorite',
        noteId: 'note-1',
        timestampMs: 111,
      );
      final key2 = NoteRepository.buildIdempotencyKey(
        type: 'toggle_favorite',
        noteId: 'note-1',
        timestampMs: 222,
      );

      expect(key1, isNot(key2));
    });
  });
}
