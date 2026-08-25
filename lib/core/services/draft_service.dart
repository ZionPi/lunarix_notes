import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class NoteDraft {
  final String title;
  final String content;
  final DateTime savedAt;

  const NoteDraft({
    required this.title,
    required this.content,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'content': content,
      'saved_at': savedAt.toIso8601String(),
    };
  }

  factory NoteDraft.fromJson(Map<String, dynamic> json) {
    return NoteDraft(
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      savedAt: DateTime.tryParse(json['saved_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class DraftService {
  static const _newNoteDraftKey = 'note_draft_new';

  Future<SharedPreferences> _getPrefs() async {
    return SharedPreferences.getInstance();
  }

  String _keyForNoteId(int? noteId) {
    return noteId == null ? _newNoteDraftKey : 'note_draft_$noteId';
  }

  Future<NoteDraft?> getDraft(int? noteId) async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(_keyForNoteId(noteId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      return NoteDraft.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveDraft({
    required int? noteId,
    required String title,
    required String content,
  }) async {
    final prefs = await _getPrefs();
    final draft = NoteDraft(
      title: title,
      content: content,
      savedAt: DateTime.now(),
    );
    await prefs.setString(_keyForNoteId(noteId), jsonEncode(draft.toJson()));
  }

  Future<void> clearDraft(int? noteId) async {
    final prefs = await _getPrefs();
    await prefs.remove(_keyForNoteId(noteId));
  }
}
