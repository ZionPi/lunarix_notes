import 'package:flutter/services.dart';

import '../models/note.dart';

class SharedText {
  final String text;
  final String subject;
  final String id;

  const SharedText({required this.text, this.subject = '', required this.id});

  Note toNote({DateTime? now}) {
    final timestamp = now ?? DateTime.now();
    final firstLine = text
        .split('\n')
        .firstWhere(
          (line) => line.trim().isNotEmpty,
          orElse: () => '分享的笔记',
        )
        .trim();
    return Note(
      title: subject.trim().isNotEmpty
          ? subject.trim()
          : String.fromCharCodes(firstLine.runes.take(60)),
      content: text,
      sourceFilename: 'android-share:$id',
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }
}

class SharedTextService {
  static const channel = MethodChannel('com.lix.lunarix_notes/shared_text');

  void listen(Future<void> Function() onAvailable) {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'available') await onAvailable();
    });
  }

  Future<SharedText?> peek() async {
    try {
      final data = await channel.invokeMapMethod<String, dynamic>('peek');
      final text = data?['text'] as String?;
      if (text == null || text.trim().isEmpty) return null;
      return SharedText(
          text: text,
          subject: data?['subject'] as String? ?? '',
          id: data!['id'] as String);
    } on MissingPluginException {
      return null;
    }
  }

  Future<void> acknowledge() => channel.invokeMethod<void>('acknowledge');

  void dispose() => channel.setMethodCallHandler(null);
}
