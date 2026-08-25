import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/models/note.dart';
import '../../../core/services/draft_service.dart';
import '../../../core/services/settings_service.dart';

enum NoteDetailMode { viewMarkdown, editRaw }

class NoteDetailScreen extends StatefulWidget {
  final Note? note;

  const NoteDetailScreen({super.key, this.note});

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final DraftService _draftService = DraftService();
  final SettingsService _settingsService = SettingsService();

  late Note _currentNote;
  late TextEditingController _titleController;
  late TextEditingController _contentController;

  bool _isNewNote = false;
  bool _isSaving = false;
  bool _isInitialized = false;
  bool _didPersistChanges = false;
  bool _newNoteDefaultTitleActive = false;
  String? _newNoteDefaultTitle;
  double _contentFontSize = 16.0;
  NoteDetailMode _currentMode = NoteDetailMode.editRaw;
  final List<_EditableImage> _insertedImages = [];
  final List<_EditorSnapshot> _history = [];
  int _historyIndex = -1;
  bool _isApplyingHistory = false;
  Timer? _draftTimer;
  Timer? _historyTimer;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final contentFontSize = await _settingsService.getNoteContentFontSize();
    final now = DateTime.now();

    if (widget.note == null) {
      final defaultTitle = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
      _isNewNote = true;
      _newNoteDefaultTitleActive = true;
      _newNoteDefaultTitle = defaultTitle;
      _currentNote = Note(
        title: defaultTitle,
        content: '',
        createdAt: now,
        updatedAt: now,
      );
      _currentMode = NoteDetailMode.editRaw;
      _titleController = TextEditingController(text: defaultTitle);
      _contentController = TextEditingController();
      await _restoreDraftIfNeeded(null);
    } else {
      _currentNote = widget.note!;
      final parsed = _parseContentForEditing(_currentNote.content);
      _insertedImages.addAll(parsed.images);
      _titleController = TextEditingController(
        text: _displayTitleForEditing(_currentNote.title),
      );
      _contentController = TextEditingController(text: parsed.text);
      _currentMode = NoteDetailMode.viewMarkdown;
      await _restoreDraftIfNeeded(_currentNote.id);
    }

    _titleController.addListener(_notifyDraftChanged);
    _contentController.addListener(_notifyDraftChanged);
    _recordHistoryNow();

    if (mounted) {
      setState(() {
        _contentFontSize = contentFontSize;
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _historyTimer?.cancel();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  bool _isGeneratedTimestampTitle(String title) {
    return RegExp(
      r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$',
    ).hasMatch(title.trim());
  }

  String _displayTitleForEditing(String title) {
    return _isGeneratedTimestampTitle(title) ? '' : title;
  }

  String _currentTitleForChangeTracking() {
    if (_isNewNote && _newNoteDefaultTitleActive) return _currentNote.title;
    return _displayTitleForEditing(_currentNote.title);
  }

  void _notifyDraftChanged() {
    if (_isApplyingHistory) return;
    if (_newNoteDefaultTitleActive &&
        _titleController.text != _newNoteDefaultTitle) {
      _newNoteDefaultTitleActive = false;
    }
    if (mounted) setState(() {});
    _scheduleDraftSave();
    _scheduleHistoryRecord();
  }

  Future<void> _restoreDraftIfNeeded(int? noteId) async {
    final draft = await _draftService.getDraft(noteId);
    if (draft == null || draft.content.isEmpty && draft.title.isEmpty) return;
    if (noteId != null && !draft.savedAt.isAfter(_currentNote.updatedAt)) {
      return;
    }

    final parsed = _parseContentForEditing(draft.content);
    _titleController.text = draft.title;
    _contentController.text = parsed.text;
    _insertedImages
      ..clear()
      ..addAll(parsed.images);
    _newNoteDefaultTitleActive = false;
  }

  void _scheduleDraftSave() {
    if (!_isInitialized) return;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 450), () {
      _draftService.saveDraft(
        noteId: _isNewNote ? null : _currentNote.id,
        title: _titleController.text.trim(),
        content: _composeContentForSaving(),
      );
    });
  }

  void _scheduleHistoryRecord() {
    _historyTimer?.cancel();
    _historyTimer = Timer(const Duration(milliseconds: 350), _recordHistoryNow);
  }

  void _recordHistoryNow() {
    final snapshot = _EditorSnapshot(
      title: _titleController.text,
      content: _contentController.text,
      images: List<_EditableImage>.from(_insertedImages),
    );
    if (_history.isNotEmpty && _history[_historyIndex] == snapshot) return;
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    _history.add(snapshot);
    if (_history.length > 60) _history.removeAt(0);
    _historyIndex = _history.length - 1;
    if (mounted && _isInitialized) setState(() {});
  }

  bool get _canUndo => _historyIndex > 0;
  bool get _canRedo =>
      _historyIndex >= 0 && _historyIndex < _history.length - 1;

  void _applyHistory(int index) {
    if (index < 0 || index >= _history.length) return;
    final snapshot = _history[index];
    _isApplyingHistory = true;
    _titleController.text = snapshot.title;
    _contentController.text = snapshot.content;
    _insertedImages
      ..clear()
      ..addAll(snapshot.images);
    _historyIndex = index;
    _isApplyingHistory = false;
    setState(() {});
    _scheduleDraftSave();
  }

  void _undo() => _applyHistory(_historyIndex - 1);

  void _redo() => _applyHistory(_historyIndex + 1);

  void _markStructuredDraftChanged() {
    if (mounted) setState(() {});
    _scheduleDraftSave();
    _recordHistoryNow();
  }

  _ParsedContent _parseContentForEditing(String content) {
    final images = <_EditableImage>[];
    final textLines = <String>[];
    for (final line in content.split('\n')) {
      final parsedImage = _tryParseImageMarkdownLine(line);
      if (parsedImage == null) {
        textLines.add(line);
        continue;
      }
      final uri = Uri.tryParse(parsedImage.uri);
      if (uri == null) continue;
      images.add(parsedImage);
    }

    final text =
        textLines.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trimRight();

    return _ParsedContent(text: text, images: images);
  }

  _EditableImage? _tryParseImageMarkdownLine(String line) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('![') || !trimmed.endsWith(')')) return null;
    final splitIndex = trimmed.indexOf('](');
    if (splitIndex <= 2) return null;
    final alt = trimmed.substring(2, splitIndex).trim();
    var href = trimmed.substring(splitIndex + 2, trimmed.length - 1).trim();
    if (href.startsWith('<') && href.endsWith('>') && href.length > 2) {
      href = href.substring(1, href.length - 1);
    }
    href = href
        .replaceAll(' ', '%20')
        .replaceAll('(', '%28')
        .replaceAll(')', '%29');
    return _EditableImage(alt: alt.isEmpty ? '图片' : alt, uri: href);
  }

  String _composeContentForSaving() {
    final text = _contentController.text.trimRight();
    if (_insertedImages.isEmpty) return text;
    final imageBlock =
        _insertedImages.map((image) => image.markdown).join('\n\n');
    return text.isEmpty ? imageBlock : '$text\n\n$imageBlock';
  }

  Future<void> _saveNote() async {
    if (_isSaving) return;

    final content = _composeContentForSaving();
    final now = DateTime.now();
    final title = _titleController.text.trim();

    if (_isNewNote && title.isEmpty && content.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入笔记内容后保存。')));
      return;
    }

    if (title.isEmpty && content.isEmpty) {
      Navigator.pop(context, false);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final noteToSave = _currentNote.copyWith(
      title: title,
      content: content,
      updatedAt: now,
    );

    try {
      if (_isNewNote) {
        _currentNote = await _dbHelper.createNote(noteToSave);
        await _draftService.clearDraft(null);
        _isNewNote = false;
      } else {
        await _dbHelper.updateNote(noteToSave);
        _currentNote = noteToSave;
      }
      await _draftService.clearDraft(_currentNote.id);

      final parsed = _parseContentForEditing(_currentNote.content);
      _titleController.text = _displayTitleForEditing(_currentNote.title);
      _contentController.text = parsed.text;
      _insertedImages
        ..clear()
        ..addAll(parsed.images);

      if (!mounted) return;
      setState(() {
        _didPersistChanges = true;
        _isSaving = false;
        _currentMode = NoteDetailMode.viewMarkdown;
      });
      _history
        ..clear()
        ..add(
          _EditorSnapshot(
            title: _displayTitleForEditing(_currentNote.title),
            content: _contentController.text,
            images: List<_EditableImage>.from(_insertedImages),
          ),
        );
      _historyIndex = 0;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已保存')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存失败: $e')));
      setState(() {
        _isSaving = false;
      });
    }
  }

  String get _draftTitle => _titleController.text.trim();
  String get _draftContent => _composeContentForSaving();

  bool get _hasUnsavedChanges {
    return _draftTitle != _currentTitleForChangeTracking() ||
        _draftContent != _currentNote.content.trimRight();
  }

  Future<bool> _confirmDiscardChanges() async {
    if (!_hasUnsavedChanges) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('放弃这次修改？'),
        content: const Text(
          '当前内容还没有保存。放弃后，本次编辑和对应草稿都会被清除。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('继续编辑'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.deepOrange),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('放弃'),
          ),
        ],
      ),
    );
    if (result == true) {
      await _draftService.clearDraft(_isNewNote ? null : _currentNote.id);
    }
    return result == true;
  }

  Future<void> _handleBack() async {
    final shouldLeave = await _shouldLeavePage();
    if (!shouldLeave || !mounted) return;
    Navigator.of(context).pop(_didPersistChanges);
  }

  Future<bool> _shouldLeavePage() async {
    if (_currentMode == NoteDetailMode.editRaw && _hasUnsavedChanges) {
      return await _confirmDiscardChanges();
    }
    return true;
  }

  void _switchToEditMode() {
    setState(() {
      _currentMode = NoteDetailMode.editRaw;
    });
  }

  TextSelection get _safeSelection {
    final selection = _contentController.selection;
    if (!selection.isValid) {
      final offset = _contentController.text.length;
      return TextSelection.collapsed(offset: offset);
    }
    return selection;
  }

  void _replaceSelection(String replacement) {
    final selection = _safeSelection;
    final text = _contentController.text;
    final start = selection.start.clamp(0, text.length);
    final end = selection.end.clamp(0, text.length);
    final newText = text.replaceRange(start, end, replacement);
    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + replacement.length),
    );
  }

  void _insertListBlock(String marker, {String placeholder = '列表项'}) {
    final selection = _safeSelection;
    final text = _contentController.text;
    final start = selection.start.clamp(0, text.length);
    final end = selection.end.clamp(0, text.length);
    final selected = start == end ? placeholder : text.substring(start, end);
    final lines = selected.split('\n');
    final replacement = lines.map((line) {
      final clean = line.trim();
      return clean.isEmpty ? '$marker $placeholder' : '$marker $clean';
    }).join('\n');
    final prefix = start == 0 ? '' : '\n';
    _replaceSelection('$prefix$replacement');
  }

  Future<Directory> _ensureAttachmentDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, 'attachments'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String> _copyPickedFile(PlatformFile pickedFile) async {
    final originalPath = pickedFile.path;
    if (originalPath == null) {
      throw Exception('未能读取所选文件路径。');
    }

    final sourceFile = File(originalPath);
    if (!await sourceFile.exists()) {
      throw Exception('所选文件不存在。');
    }

    final dir = await _ensureAttachmentDirectory();
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}';
    final targetPath = p.join(dir.path, fileName);
    final copied = await sourceFile.copy(targetPath);
    return copied.uri.toString();
  }

  Future<void> _insertImage() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      dialogTitle: '选择要插入的图片',
    );

    if (picked == null || picked.files.isEmpty) return;

    try {
      final inserted = <_EditableImage>[];
      for (final file in picked.files) {
        final uri = await _copyPickedFile(file);
        inserted.add(
          _EditableImage(alt: p.basenameWithoutExtension(file.name), uri: uri),
        );
      }
      if (!mounted) return;
      setState(() {
        _insertedImages.addAll(inserted);
      });
      _markStructuredDraftChanged();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已插入 ${inserted.length} 张图片')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('插入图片失败: $e')));
    }
  }

  Future<void> _insertAttachment() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.any,
      dialogTitle: '选择要附加的文件',
    );

    if (picked == null || picked.files.isEmpty) return;

    try {
      final file = picked.files.single;
      final uri = await _copyPickedFile(file);
      final prefix = _contentController.text.trimRight().isEmpty ? '' : '\n';
      _replaceSelection('$prefix[附件：${file.name}]($uri)\n');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('插入附件失败: $e')));
    }
  }

  void _moveInsertedImage(int from, int to) {
    if (from < 0 ||
        from >= _insertedImages.length ||
        to < 0 ||
        to >= _insertedImages.length) {
      return;
    }
    setState(() {
      final item = _insertedImages.removeAt(from);
      _insertedImages.insert(to, item);
    });
    _markStructuredDraftChanged();
  }

  void _removeInsertedImage(int index) {
    if (index < 0 || index >= _insertedImages.length) return;
    setState(() {
      _insertedImages.removeAt(index);
    });
    _markStructuredDraftChanged();
  }

  Future<void> _pasteClipboardIntoContent() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('剪贴板里没有可粘贴的文字')));
      return;
    }
    _replaceSelection(text);
  }

  void _clearContent() {
    if (_contentController.text.isEmpty) return;
    _contentController.clear();
  }

  Future<void> _openMarkdownLink(String? href) async {
    if (href == null || href.isEmpty) return;
    final uri = Uri.tryParse(href);
    if (uri == null) return;

    try {
      final success = await launchUrl(
        uri,
        mode: uri.scheme == 'file'
            ? LaunchMode.externalApplication
            : LaunchMode.platformDefault,
      );
      if (!success && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无法打开该链接或附件。')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('打开失败: $e')));
    }
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildEditorToolbar(ThemeData theme) {
    final chipColor = theme.colorScheme.primary.withValues(alpha: 0.07);

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.10),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildToolbarButton(
              icon: Icons.undo_rounded,
              tooltip: '撤销',
              onTap: _canUndo ? _undo : null,
            ),
            _buildToolbarButton(
              icon: Icons.redo_rounded,
              tooltip: '重做',
              onTap: _canRedo ? _redo : null,
            ),
            _buildToolbarButton(
              icon: Icons.format_list_numbered,
              tooltip: '有序列表',
              onTap: () => _insertListBlock('1.', placeholder: '步骤'),
            ),
            _buildToolbarButton(
              icon: Icons.format_list_bulleted,
              tooltip: '无序列表',
              onTap: () => _insertListBlock('-', placeholder: '列表项'),
            ),
            _buildToolbarButton(
              icon: Icons.checklist_rounded,
              tooltip: '任务列表',
              onTap: () => _insertListBlock('- [ ]', placeholder: '待办事项'),
            ),
            _buildToolbarButton(
              icon: Icons.photo_outlined,
              tooltip: '插入图片',
              onTap: _insertImage,
            ),
            _buildToolbarButton(
              icon: Icons.attach_file,
              tooltip: '插入附件',
              onTap: _insertAttachment,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsertedImagesSection(ThemeData theme) {
    if (_insertedImages.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '图片',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${_insertedImages.length} 张',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 164,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _insertedImages.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final image = _insertedImages[index];
                final uri = Uri.parse(image.uri);
                final isLocal = uri.scheme == 'file';
                return Container(
                  width: 148,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: isLocal
                              ? Image.file(
                                  File(uri.toFilePath()),
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _buildBrokenImage(),
                                )
                              : Image.network(
                                  uri.toString(),
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _buildBrokenImage(),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        image.alt,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          IconButton(
                            onPressed: index == 0
                                ? null
                                : () => _moveInsertedImage(index, index - 1),
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 16,
                            ),
                            visualDensity: VisualDensity.compact,
                            tooltip: '左移',
                          ),
                          IconButton(
                            onPressed: index == _insertedImages.length - 1
                                ? null
                                : () => _moveInsertedImage(index, index + 1),
                            icon: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 16,
                            ),
                            visualDensity: VisualDensity.compact,
                            tooltip: '右移',
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => _removeInsertedImage(index),
                            icon: const Icon(Icons.close_rounded, size: 18),
                            visualDensity: VisualDensity.compact,
                            tooltip: '移除',
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrokenImage() {
    return Container(
      color: Colors.black12,
      alignment: Alignment.center,
      child: const Icon(Icons.broken_image_outlined),
    );
  }

  Widget _buildPreviewBody(ThemeData theme) {
    final title = _titleController.text.trim();
    final content = _composeContentForSaving();
    final fallbackText = title.isEmpty ? '*空空如也*' : '*笔记内容为空*';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 18),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
              ),
            ),
            child: SelectableText(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
            ),
          ),
          child: MarkdownBody(
            data: content.isEmpty ? fallbackText : content,
            selectable: true,
            softLineBreak: true,
            onTapLink: (text, href, title) => _openMarkdownLink(href),
            sizedImageBuilder: (config) {
              final uri = config.uri;
              if (uri.scheme == 'file') {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.file(File(uri.toFilePath())),
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.network(uri.toString()),
                ),
              );
            },
            styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
              p: theme.textTheme.bodyMedium?.copyWith(
                fontSize: _contentFontSize,
                height: 1.7,
              ),
              h1: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              h2: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              h3: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              blockquote: theme.textTheme.bodyMedium?.copyWith(
                fontSize: _contentFontSize,
                height: 1.7,
                color: theme.textTheme.bodySmall?.color,
              ),
              code: theme.textTheme.bodyMedium?.copyWith(
                fontSize: _contentFontSize - 1,
                height: 1.5,
              ),
              listBullet: theme.textTheme.bodyMedium?.copyWith(
                fontSize: _contentFontSize,
              ),
              a: theme.textTheme.bodyMedium?.copyWith(
                fontSize: _contentFontSize,
                color: theme.colorScheme.primary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditBody() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            hintText: '标题',
            border: InputBorder.none,
            suffixIcon: _titleController.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: '清空标题',
                    onPressed: _titleController.clear,
                  ),
          ),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        _buildEditorToolbar(theme),
        _buildInsertedImagesSection(theme),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 34,
                  child: Row(
                    children: [
                      Text(
                        '正文',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _pasteClipboardIntoContent,
                        icon: const Icon(Icons.content_paste_rounded, size: 18),
                        visualDensity: VisualDensity.compact,
                        tooltip: '粘贴剪贴板',
                      ),
                      IconButton(
                        onPressed: _contentController.text.isEmpty
                            ? null
                            : _clearContent,
                        icon: const Icon(Icons.close_rounded, size: 19),
                        visualDensity: VisualDensity.compact,
                        tooltip: '清空正文',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _contentController,
                    decoration: const InputDecoration(
                      hintText: '开始记录您的想法...',
                      border: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.only(top: 4),
                    ),
                    style: TextStyle(fontSize: _contentFontSize, height: 1.7),
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isEditMode = _currentMode == NoteDetailMode.editRaw;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
            ),
            onPressed: _handleBack,
          ),
          title: Text(isEditMode ? '编辑笔记' : '阅读笔记'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: IconButton(
                onPressed: isEditMode
                    ? (_isSaving ? null : _saveNote)
                    : _switchToEditMode,
                tooltip: isEditMode ? '完成' : '编辑',
                padding: const EdgeInsets.only(left: 8, right: 6),
                constraints: const BoxConstraints.tightFor(
                  width: 52,
                  height: 52,
                ),
                icon: isEditMode
                    ? (_isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.check_rounded,
                            size: 28,
                            color: Colors.white,
                          ))
                    : const Icon(
                        Icons.edit_outlined,
                        size: 26,
                        color: Colors.white,
                      ),
              ),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
          child: _currentMode == NoteDetailMode.viewMarkdown
              ? SingleChildScrollView(child: _buildPreviewBody(theme))
              : _buildEditBody(),
        ),
      ),
    );
  }
}

class _ParsedContent {
  final String text;
  final List<_EditableImage> images;

  const _ParsedContent({required this.text, required this.images});
}

class _EditorSnapshot {
  final String title;
  final String content;
  final List<_EditableImage> images;

  const _EditorSnapshot({
    required this.title,
    required this.content,
    required this.images,
  });

  @override
  bool operator ==(Object other) {
    if (other is! _EditorSnapshot) return false;
    if (title != other.title || content != other.content) return false;
    if (images.length != other.images.length) return false;
    for (var i = 0; i < images.length; i++) {
      if (images[i] != other.images[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(title, content, Object.hashAll(images));
}

class _EditableImage {
  final String alt;
  final String uri;

  const _EditableImage({required this.alt, required this.uri});

  String get markdown => '![${alt.replaceAll(']', '')}](<${_safeUri(uri)}>)';

  String _safeUri(String value) {
    return value
        .replaceAll(' ', '%20')
        .replaceAll('(', '%28')
        .replaceAll(')', '%29')
        .replaceAll('<', '%3C')
        .replaceAll('>', '%3E');
  }

  @override
  bool operator ==(Object other) {
    return other is _EditableImage && other.alt == alt && other.uri == uri;
  }

  @override
  int get hashCode => Object.hash(alt, uri);
}
