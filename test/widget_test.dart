import 'package:flutter_test/flutter_test.dart';
import 'package:lunarix_notes/core/models/note.dart';

void main() {
  test('Note preserves pinned order in map conversion', () {
    final now = DateTime(2026, 8, 25, 12);
    final note = Note(
      id: 1,
      title: '置顶笔记',
      content: '正文',
      createdAt: now,
      updatedAt: now,
      isPinned: 1,
      pinOrder: 3,
    );

    final restored = Note.fromMap(note.toMap());

    expect(restored.isPinned, 1);
    expect(restored.pinOrder, 3);
  });
}
