import 'package:flutter_test/flutter_test.dart';
import 'package:lunarix_notes/core/services/shared_text_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() =>
      messenger.setMockMethodCallHandler(SharedTextService.channel, null));

  test('share preserves full text and uses subject as title', () {
    const text = '第一段\n\n第二段 https://example.org\n';
    final note = const SharedText(
            id: 'delivery-1', text: text, subject: '  localshare 笔记  ')
        .toNote();
    expect(note.title, 'localshare 笔记');
    expect(note.content, text);
    expect(note.id, isNull);
    expect(note.sourceFilename, 'android-share:delivery-1');
  });

  test('title fallback does not split Unicode characters or lose body', () {
    final text = '\n${List.filled(80, '🌱').join()}\n正文';
    final note = SharedText(id: 'delivery-2', text: text).toNote();
    expect(note.title.runes.length, 60);
    expect(note.title.runes.every((rune) => rune == 0x1F331), isTrue);
    expect(note.content, text);
  });

  test('peek leaves incoming share pending until persistence is acknowledged',
      () async {
    var acknowledged = false;
    messenger.setMockMethodCallHandler(SharedTextService.channel, (call) async {
      if (call.method == 'acknowledge') {
        acknowledged = true;
        return null;
      }
      return acknowledged ? null : {'id': '1', 'text': '文字', 'subject': '标题'};
    });
    final service = SharedTextService();
    expect((await service.peek())?.text, '文字');
    expect((await service.peek())?.text, '文字');
    await service.acknowledge();
    expect(await service.peek(), isNull);
  });

  test('empty text and absent native implementation do not create notes',
      () async {
    messenger.setMockMethodCallHandler(SharedTextService.channel,
        (_) async => {'id': '1', 'text': '  \n', 'subject': '标题'});
    expect(await SharedTextService().peek(), isNull);
    messenger.setMockMethodCallHandler(SharedTextService.channel, null);
    expect(await SharedTextService().peek(), isNull);
  });
}
