import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lunarix_notes/core/models/note.dart';
import 'package:lunarix_notes/core/services/draft_service.dart';
import 'package:lunarix_notes/core/services/settings_service.dart';
import 'package:lunarix_notes/core/services/app_info_service.dart';
import 'package:lunarix_notes/core/theme/app_theme.dart';
import 'package:lunarix_notes/features/note_detail/views/note_detail_screen.dart';
import 'package:lunarix_notes/features/note_detail/widgets/note_image_gallery.dart';
import 'package:lunarix_notes/features/settings/views/settings_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('settings reads the installed package version', (tester) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        AppInfoService.channel, (_) async => {'name': '9.8.7', 'build': 42});
    addTearDown(
        () => messenger.setMockMethodCallHandler(AppInfoService.channel, null));
    await tester.pumpWidget(
        MaterialApp(theme: AppTheme.build(), home: const SettingsScreen()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('v9.8.7+42'), 400);
    expect(find.text('v9.8.7+42'), findsOneWidget);
  });

  testWidgets('title clear shortcut can be undone', (tester) async {
    await tester.pumpWidget(
        MaterialApp(theme: AppTheme.build(), home: const NoteDetailScreen()));
    await tester.pumpAndSettle();
    expect(find.byTooltip('清空标题'), findsNothing);
    await tester.enterText(find.byType(TextField).first, '需要保留的标题');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byTooltip('清空标题'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byTooltip('清空标题'), findsNothing);
    expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        isEmpty);
    await tester.tap(find.byTooltip('撤销'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '需要保留的标题');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'sorting separates criterion and direction and persists selection',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        MaterialApp(theme: AppTheme.build(), home: const SettingsScreen()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('更新时间 · 新的在前'), 200);
    await tester.ensureVisible(find.text('更新时间 · 新的在前'));
    await tester.tap(find.text('更新时间 · 新的在前'));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    await tester.tap(find.text('创建时间'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('旧的在前'));
    await tester.pumpAndSettle();
    expect(await SettingsService().getLastSortOrder(), 'created_at ASC');
    await tester.tap(find.byTooltip('关闭排序设置'));
    await tester.pumpAndSettle();
    expect(find.text('创建时间 · 旧的在前'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('discarding a new note clears its draft and exits',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(),
        home: Builder(
            builder: (context) => TextButton(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) => const NoteDetailScreen())),
                child: const Text('新建')))));
    await tester.tap(find.text('新建'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '不想保留的内容');
    await tester.pump(const Duration(milliseconds: 500));
    expect((await DraftService().getDraft(null))?.content, '不想保留的内容');
    await tester.tap(find.byTooltip('返回笔记'));
    await tester.pumpAndSettle();
    expect(find.text('保存这篇笔记？'), findsOneWidget);
    expect(find.text('保存笔记'), findsOneWidget);
    expect(find.text('放弃修改'), findsNothing);
    await tester.tap(find.text('不保存'));
    await tester.pumpAndSettle();
    expect(await DraftService().getDraft(null), isNull);
    expect(find.text('新建'), findsOneWidget);
  });

  testWidgets('settings sections preserve working material tap surfaces',
      (tester) async {
    await tester.pumpWidget(
        MaterialApp(theme: AppTheme.build(), home: const SettingsScreen()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('导入 JSON 笔记'), 250);
    expect(tester.takeException(), isNull);
    expect(find.text('从数据库备份恢复'), findsOneWidget);
  });

  testWidgets('removing an image requires confirmation and undo restores it',
      (tester) async {
    final now = DateTime(2026, 10, 22);
    final note = Note(
        id: 9,
        title: '图文笔记',
        content: '正文\n\n![first](invalid:first)\n\n![second](invalid:second)',
        createdAt: now,
        updatedAt: now);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(),
        home: NoteDetailScreen(note: note, startEditing: true)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('图片操作').first);
    await tester.tap(find.byTooltip('图片操作').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('移除图片'));
    await tester.pumpAndSettle();
    expect(find.text('从笔记移除这张图片？'), findsOneWidget);
    expect(find.byType(LongPressDraggable<int>), findsNWidgets(2));
    await tester.tap(find.text('移除'));
    await tester.pumpAndSettle();
    expect(find.byType(LongPressDraggable<int>), findsOneWidget);
    await tester.tap(find.byTooltip('撤销'));
    await tester.pumpAndSettle();
    expect(find.byType(LongPressDraggable<int>), findsNWidgets(2));
    expect(find.widgetWithText(TextField, '正文'), findsOneWidget);
    expect(note.content, contains('![first](invalid:first)'));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('editor fits a small screen with keyboard and large text',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!),
        home: const NoteDetailScreen()));
    await tester.pumpAndSettle();
    expect(find.text('标题（可选）'), findsOneWidget);
    expect(find.text('保存'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField).last, '一段需要保留的正文');
    await tester.pump(const Duration(milliseconds: 500));
    final draft = await DraftService().getDraft(null);
    expect(draft?.content, '一段需要保留的正文');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'images use a vertical grid and support drag reorder and zoom preview',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final moves = <List<int>>[];
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(),
        home: Scaffold(
          body: Padding(
              padding: const EdgeInsets.all(24),
              child: NoteImageGallery(
                uris: const [
                  'invalid:first',
                  'invalid:second',
                  'invalid:third'
                ],
                onRemove: (_) {},
                onReorder: (from, to) => moves.add([from, to]),
                onAdd: () {},
              )),
        )));
    await tester.pumpAndSettle();
    final tiles = find.byType(LongPressDraggable<int>);
    expect(tiles, findsNWidgets(3));
    expect(tester.getTopLeft(tiles.at(2)).dy,
        greaterThan(tester.getTopLeft(tiles.first).dy));
    final from = tester.getCenter(tiles.first);
    final to = tester.getCenter(tiles.at(1));
    final gesture = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(to);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(moves, [
      [0, 1]
    ]);
    await tester.tap(find.byKey(const ValueKey('preview-image-0')));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsWidgets);
    expect(find.text('1 / 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dismissing exit sheet continues editing with automatic draft',
      (tester) async {
    final now = DateTime(2026, 10, 22);
    final note = Note(
        id: 5, title: '原笔记', content: '原正文', createdAt: now, updatedAt: now);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(),
        home: Builder(
          builder: (context) => TextButton(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                      builder: (_) =>
                          NoteDetailScreen(note: note, startEditing: true))),
              child: const Text('打开')),
        )));
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '修改后的正文');
    await tester.tap(find.byTooltip('返回笔记'));
    await tester.pumpAndSettle();
    final discardButton = tester.getCenter(find.text('放弃修改'));
    final saveButton = tester.getCenter(find.text('保存退出'));
    expect(discardButton.dy, saveButton.dy);
    expect(find.text('保留草稿'), findsNothing);
    await tester.tapAt(const Offset(20, 40));
    await tester.pumpAndSettle();
    expect((await DraftService().getDraft(5))?.content, '修改后的正文');
    expect(note.content, '原正文');
    expect(find.widgetWithText(TextField, '修改后的正文'), findsOneWidget);
    await tester.tap(find.byTooltip('返回笔记'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('放弃修改'));
    await tester.pumpAndSettle();
    expect(await DraftService().getDraft(5), isNull);
    expect(note.content, '原正文');
    expect(find.text('打开'), findsOneWidget);
  });
}
