import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lunarix_notes/core/models/note.dart';
import 'package:lunarix_notes/core/services/draft_service.dart';
import 'package:lunarix_notes/features/note_detail/views/note_detail_screen.dart';
import 'package:lunarix_notes/features/note_detail/widgets/note_image_gallery.dart';
import 'package:shared_preferences/shared_preferences.dart';

Note note(String content) => Note(
      id: 42,
      title: '旅行笔记',
      content: content,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('rotation in full-screen editor updates draft and can be undone',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const source = 'file:///missing/photo.jpg';
    await tester.pumpWidget(MaterialApp(
      home: NoteDetailScreen(
        note: note('![photo](<$source>)'),
        startEditing: true,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('preview-image-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('向右旋转'));
    await tester.pumpAndSettle();
    expect(
        find.byWidgetPredicate((w) => w is RotatedBox && w.quarterTurns == 1),
        findsWidgets);
    await tester.tap(find.byTooltip('关闭预览'));
    await tester.pumpAndSettle();
    expect((await DraftService().getDraft(42))?.content,
        '![photo](<$source> "lunarix-turn=1")');
    await tester.tap(find.byTooltip('撤销'));
    await tester.pumpAndSettle();
    expect((await DraftService().getDraft(42))?.content, '![photo](<$source>)');
  });

  testWidgets('reading view restores saved rotation and only exposes a menu',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: NoteDetailScreen(
        note: note('![photo](<file:///missing/photo.jpg> "lunarix-turn=3")'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(
        find.byWidgetPredicate((w) => w is RotatedBox && w.quarterTurns == 3),
        findsOneWidget);
    expect(find.text('编辑'), findsNothing);
    expect(find.text('分享'), findsNothing);
    await tester.tap(find.byTooltip('笔记操作'));
    await tester.pumpAndSettle();
    expect(find.text('分享'), findsOneWidget);
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    expect(find.text('保存'), findsOneWidget);
    expect(find.byType(NoteImageGallery), findsOneWidget);
  });

  testWidgets('share exports a PNG taller than the viewport', (tester) async {
    final cache = Directory.systemTemp.createTempSync('lunarix-test-');
    addTearDown(() => cache.deleteSync(recursive: true));
    const paths = MethodChannel('plugins.flutter.io/path_provider');
    const share = MethodChannel('com.lix.lunarix_notes/share_image');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(paths, (_) async => cache.path);
    String? sharedFile;
    messenger.setMockMethodCallHandler(share, (call) async {
      sharedFile = call.arguments as String;
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(paths, null);
      messenger.setMockMethodCallHandler(share, null);
    });

    await tester.pumpWidget(MaterialApp(
        home: NoteDetailScreen(
      note: note(List.generate(45, (i) => 'Line $i').join('\n\n')),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('笔记操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('分享'));
    for (var attempt = 0; attempt < 60 && sharedFile == null; attempt++) {
      await tester.pump(const Duration(milliseconds: 30));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
    expect(sharedFile, isNotNull);
    await tester.runAsync(() async {
      final bytes =
          File('${cache.path}/note_exports/$sharedFile').readAsBytesSync();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      expect(frame.image.height / frame.image.width, greaterThan(1.5));
      final pixels =
          (await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba))!
              .buffer
              .asUint8List();
      final firstRow = (frame.image.height * .85).floor();
      var hasTextBelowFold = false;
      for (var index = firstRow * frame.image.width * 4;
          index < pixels.length;
          index += 4) {
        if (pixels[index] < 100 && pixels[index + 3] == 255) {
          hasTextBelowFold = true;
          break;
        }
      }
      expect(hasTextBelowFold, isTrue);
      frame.image.dispose();
      codec.dispose();
    });
  });
}
