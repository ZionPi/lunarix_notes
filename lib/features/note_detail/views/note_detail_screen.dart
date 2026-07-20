import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/models/note.dart';
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
  final SettingsService _settingsService = SettingsService();

  late Note _currentNote;
  late TextEditingController _titleController;
  late TextEditingController _contentController;

  bool _isNewNote = false;
  bool _defaultTitleUsed = false;
  bool _isSaving = false;
  bool _isInitialized = false;
  bool _didPersistChanges = false;
  double _contentFontSize = 16.0;
  NoteDetailMode _currentMode = NoteDetailMode.editRaw;
  final List<_StagedImage> _stagedImages = [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final contentFontSize = await _settingsService.getNoteContentFontSize();
    final now = DateTime.now();

    if (widget.note == null) {
      final title = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
      _isNewNote = true;
      _defaultTitleUsed = true;
      _currentNote = Note(
        title: title,
        content: '',
        createdAt: now,
        updatedAt: now,
      );
      _currentMode = NoteDetailMode.editRaw;
      _titleController = TextEditingController(text: title);
      _contentController = TextEditingController();
    } else {
      _currentNote = widget.note!;
      _titleController = TextEditingController(text: _currentNote.title);
      _contentController = TextEditingController(text: _currentNote.content);
      _currentMode = NoteDetailMode.viewMarkdown;
    }

    if (mounted) {
      setState(() {
        _contentFontSize = contentFontSize;
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  List<_RenderedImage> _extractImagesFromContent() {
    final matches = RegExp(r'!\[([^\]]*)\]\(([^)]+)\)').allMatches(
      _contentController.text,
    );

    return matches
        .map((match) {
          final alt = (match.group(1) ?? '').trim();
          final href = (match.group(2) ?? '').trim();
          final uri = Uri.tryParse(href);
          return _RenderedImage(
            alt: alt.isEmpty ? '图片' : alt,
            href: href,
            uri: uri,
          );
        })
        .where((item) => item.uri != null)
        .toList();
  }

  Future<void> _saveNote() async {
    if (_isSaving) return;

    final title = _titleController.text.trim();
    final content = _contentController.text.trimRight();

    if (_isNewNote && _defaultTitleUsed && content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入笔记内容或修改标题后保存。')),
      );
      return;
    }

    if (title.isEmpty && content.isEmpty) {
      Navigator.pop(context, false);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final now = DateTime.now();
    final noteToSave = _currentNote.copyWith(
      title: title,
      content: content,
      updatedAt: now,
    );

    try {
      if (_isNewNote) {
        _currentNote = await _dbHelper.createNote(noteToSave);
        _isNewNote = false;
        _defaultTitleUsed = false;
      } else {
        await _dbHelper.updateNote(noteToSave);
        _currentNote = noteToSave;
      }

      _titleController.text = _currentNote.title;
      _contentController.text = _currentNote.content;

      if (!mounted) return;
      setState(() {
        _didPersistChanges = true;
        _isSaving = false;
        _currentMode = NoteDetailMode.viewMarkdown;
        _stagedImages.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败: $e')),
      );
      setState(() {
        _isSaving = false;
      });
    }
  }

  String get _draftTitle => _titleController.text.trim();
  String get _draftContent => _contentController.text.trimRight();

  bool get _hasUnsavedChanges {
    if (_stagedImages.isNotEmpty) return true;
    return _draftTitle != _currentNote.title ||
        _draftContent != _currentNote.content.trimRight();
  }

  Future<bool> _confirmDiscardChanges() async {
    if (!_hasUnsavedChanges) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('放弃修改？'),
        content: const Text('当前修改还没有保存，离开后会丢失。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('继续编辑'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('放弃'),
          ),
        ],
      ),
    );
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
      final staged = <_StagedImage>[];
      for (final file in picked.files) {
        final uri = await _copyPickedFile(file);
        staged.add(
          _StagedImage(
            fileName: file.name,
            alt: p.basenameWithoutExtension(file.name),
            uri: uri,
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _stagedImages.addAll(staged);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('插入图片失败: $e')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('插入附件失败: $e')),
      );
    }
  }

  void _moveStagedImage(int from, int to) {
    if (from < 0 ||
        from >= _stagedImages.length ||
        to < 0 ||
        to >= _stagedImages.length) {
      return;
    }
    setState(() {
      final item = _stagedImages.removeAt(from);
      _stagedImages.insert(to, item);
    });
  }

  void _removeStagedImage(int index) {
    if (index < 0 || index >= _stagedImages.length) return;
    setState(() {
      _stagedImages.removeAt(index);
    });
  }

  void _insertStagedImages() {
    if (_stagedImages.isEmpty) return;
    final prefix = _contentController.text.trimRight().isEmpty ? '' : '\n';
    final blocks = _stagedImages
        .map((image) => '![${image.alt}](${image.uri})')
        .join('\n\n');
    _replaceSelection('$prefix$blocks\n');
    setState(() {
      _stagedImages.clear();
    });
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法打开该链接或附件。')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('打开失败: $e')),
      );
    }
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
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
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.10),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
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

  Widget _buildStagedImagesSection(ThemeData theme) {
    if (_stagedImages.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
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
                '待插入图片',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _insertStagedImages,
                icon:
                    const Icon(Icons.subdirectory_arrow_left_rounded, size: 18),
                label: Text('插入 ${_stagedImages.length} 张'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 164,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _stagedImages.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final image = _stagedImages[index];
                final file = File(Uri.parse(image.uri).toFilePath());
                return Container(
                  width: 148,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            file,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.black12,
                              alignment: Alignment.center,
                              child: const Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        image.fileName,
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
                                : () => _moveStagedImage(index, index - 1),
                            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                                size: 16),
                            visualDensity: VisualDensity.compact,
                            tooltip: '左移',
                          ),
                          IconButton(
                            onPressed: index == _stagedImages.length - 1
                                ? null
                                : () => _moveStagedImage(index, index + 1),
                            icon: const Icon(Icons.arrow_forward_ios_rounded,
                                size: 16),
                            visualDensity: VisualDensity.compact,
                            tooltip: '右移',
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => _removeStagedImage(index),
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

  Widget _buildInsertedImagesPreview(ThemeData theme) {
    final images = _extractImagesFromContent();
    if (images.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.07),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '正文图片预览',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final image = images[index];
                final uri = image.uri!;
                final isLocal = uri.scheme == 'file';
                return Container(
                  width: 112,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.black12,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: isLocal
                        ? Image.file(
                            File(uri.toFilePath()),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.broken_image_outlined,
                            ),
                          )
                        : Image.network(
                            uri.toString(),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.broken_image_outlined,
                            ),
                          ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewBody(ThemeData theme) {
    final title = _titleController.text.trim();
    final content = _contentController.text.trimRight();
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
              borderRadius: BorderRadius.circular(18),
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
            borderRadius: BorderRadius.circular(18),
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
              h1: theme.textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
              h2: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
              h3: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
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
          decoration: const InputDecoration(
            hintText: '标题',
            border: InputBorder.none,
          ),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        _buildEditorToolbar(theme),
        _buildStagedImagesSection(theme),
        _buildInsertedImagesPreview(theme),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
              ),
            ),
            child: TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                hintText: '开始记录您的想法...',
                border: InputBorder.none,
              ),
              style: TextStyle(
                fontSize: _contentFontSize,
                height: 1.7,
              ),
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
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
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white),
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
                constraints:
                    const BoxConstraints.tightFor(width: 52, height: 52),
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

class _StagedImage {
  final String fileName;
  final String alt;
  final String uri;

  const _StagedImage({
    required this.fileName,
    required this.alt,
    required this.uri,
  });
}

class _RenderedImage {
  final String alt;
  final String href;
  final Uri? uri;

  const _RenderedImage({
    required this.alt,
    required this.href,
    required this.uri,
  });
}
