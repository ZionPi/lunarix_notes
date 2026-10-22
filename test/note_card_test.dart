import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:lunarix_notes/core/models/note.dart';
import 'package:lunarix_notes/core/theme/app_theme.dart';
import 'package:lunarix_notes/features/note_list/widgets/note_card.dart';

void main() {
  for (final scale in [1.0, 1.5]) {
    testWidgets('swipe labels fit small screen at text scale $scale',
        (tester) async {
      tester.view.physicalSize = const Size(335, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final now = DateTime(2026, 10, 22);
      var pins = 0;
      var deletes = 0;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: Scaffold(
            body: SlidableAutoCloseBehavior(
                child: ListView(children: [
          NoteCard(
              note: Note(
                  id: 1,
                  title: '置顶笔记',
                  content: '正文内容',
                  createdAt: now,
                  updatedAt: now,
                  isPinned: 1),
              onDelete: () => deletes++,
              onTogglePin: () => pins++,
              onToggleStar: () {},
              onCopyContent: () {},
              onNoteUpdated: (_) {}),
        ]))),
      ));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.drag_indicator_rounded), findsNothing);
      await tester.drag(find.byType(Card), const Offset(-280, 0));
      await tester.pumpAndSettle();
      final pinLabel = find.text('取消置顶');
      expect(pinLabel, findsOneWidget);
      final text = tester.renderObject<RenderParagraph>(pinLabel);
      expect(text.didExceedMaxLines, isFalse);
      expect((tester.widget<Text>(pinLabel)).overflow,
          isNot(TextOverflow.ellipsis));
      final labelRect = tester.getRect(pinLabel);
      expect(labelRect.left, greaterThanOrEqualTo(20));
      expect(labelRect.right, lessThanOrEqualTo(315));
      expect(
          tester
              .getSize(find
                  .ancestor(of: pinLabel, matching: find.byType(Material))
                  .first)
              .height,
          88);
      expect(tester.takeException(), isNull);
      expect(deletes, 0);
      await tester.tap(pinLabel);
      await tester.pumpAndSettle();
      expect(pins, 1);
      expect(deletes, 0);
    });
  }
}
