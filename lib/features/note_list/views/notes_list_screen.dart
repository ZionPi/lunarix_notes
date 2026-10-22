import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/models/note.dart';
import '../../../core/services/draft_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/shared_text_service.dart';
import '../../../core/widgets/confirm_action_sheet.dart';
import '../../note_detail/views/note_detail_screen.dart';
import '../../settings/views/settings_screen.dart';
import '../widgets/note_card.dart';

class NotesListScreen extends StatefulWidget {
  const NotesListScreen({super.key});

  @override
  State<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends State<NotesListScreen> {
  List<Note> _notes = [];
  NoteDraft? _newNoteDraft;
  bool _isLoading = true;
  String _searchTerm = '';
  String _filter = 'all';
  String _currentSortOrder = 'updated_at DESC';
  final TextEditingController _searchController = TextEditingController();

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final DraftService _draftService = DraftService();
  final SettingsService _settingsService = SettingsService();
  final SharedTextService _sharedTextService = SharedTextService();
  bool _processingShares = false;

  @override
  void initState() {
    super.initState();
    _loadSettingsAndRefreshUI();
    _sharedTextService.listen(_receiveSharedNotes);
    WidgetsBinding.instance.addPostFrameCallback((_) => _receiveSharedNotes());
  }

  Future<void> _receiveSharedNotes() async {
    if (_processingShares || !mounted) return;
    _processingShares = true;
    try {
      while (mounted) {
        final shared = await _sharedTextService.peek();
        if (shared == null || !mounted) break;
        // Persist as a separate note before opening the editor. Existing drafts
        // keep their own keys and are never replaced by incoming shares.
        final note = await _dbHelper.createSharedNote(shared.toNote());
        await _sharedTextService.acknowledge();
        if (!mounted) break;
        await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => NoteDetailScreen(note: note, startEditing: true),
        ));
        await _refreshNotes(showLoading: false);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('接收分享失败，分享内容仍待接收：$error'),
          action: SnackBarAction(
            label: '重试',
            onPressed: _receiveSharedNotes,
          ),
        ));
      }
    } finally {
      _processingShares = false;
    }
  }

  Future<void> _loadSettingsAndRefreshUI() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    _currentSortOrder = await _settingsService.getLastSortOrder();
    await _refreshNotes(showLoading: false);
  }

  @override
  void dispose() {
    _sharedTextService.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshNotes({bool showLoading = true}) async {
    if (!mounted) return;
    if (showLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final notes = _searchTerm.isEmpty
          ? await _dbHelper.getAllNotes(currentSortOrder: _currentSortOrder)
          : await _dbHelper.searchNotes(
              _searchTerm,
              currentSortOrder: _currentSortOrder,
            );
      final newNoteDraft = await _draftService.getDraft(null);

      if (mounted) {
        setState(() {
          _notes = notes;
          _newNoteDraft = newNoteDraft;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('加载笔记失败: ${e.toString()}')));
        setState(() {
          _notes = [];
          _newNoteDraft = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    if (_searchTerm == query) return;
    setState(() {
      _searchTerm = query;
    });
    _refreshNotes(showLoading: false);
  }

  void _clearSearch() {
    if (_searchTerm.isEmpty) return;
    _searchController.clear();
    setState(() {
      _searchTerm = '';
    });
    _refreshNotes(showLoading: false);
  }

  Future<void> _handleCopyNoteContent(Note note) async {
    final content = note.content.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('这条笔记没有可复制的正文内容')));
      return;
    }

    await Clipboard.setData(ClipboardData(text: content));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已复制卡片内容')));
  }

  Future<void> _navigateToDetailScreen([Note? note]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NoteDetailScreen(note: note)),
    );

    if (result == true && mounted) {
      await _refreshNotes(showLoading: false);
    } else if (mounted) {
      _newNoteDraft = await _draftService.getDraft(null);
      setState(() {});
    }
  }

  Future<void> _discardNewNoteDraft() async {
    final confirmed = await confirmActionSheet(context,
        title: '删除这份草稿？',
        message: '删除后无法恢复，已保存的笔记不受影响。',
        confirmLabel: '删除草稿',
        destructive: true);
    if (confirmed != true) return;
    await _draftService.clearDraft(null);
    if (!mounted) return;
    setState(() {
      _newNoteDraft = null;
    });
  }

  Future<void> _handleDeleteNote(int noteId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('移至回收站？'),
          content: const Text(
            '这条笔记会从列表中移除，稍后仍可从回收站处理。',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) return;

    final previousNotes = List<Note>.from(_notes);
    Note? deletedNote;
    for (final note in _notes) {
      if (note.id == noteId) {
        deletedNote = note;
        break;
      }
    }
    setState(() {
      _notes = _notes.where((note) => note.id != noteId).toList();
    });

    try {
      await _dbHelper.softDeleteNote(noteId);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      final snackController = messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          content: const Text('笔记已移至回收站'),
          action: SnackBarAction(
            label: '撤回',
            onPressed: () async {
              messenger.hideCurrentSnackBar();
              final noteToRestore = deletedNote;
              if (noteToRestore == null) {
                await _dbHelper.restoreNote(noteId);
                if (!mounted) return;
                await _refreshNotes(showLoading: false);
                return;
              }
              final restoredNote = noteToRestore.copyWith(
                isDeleted: 0,
                clearDeletedAt: true,
                updatedAt: DateTime.now(),
              );
              await _dbHelper.updateNote(restoredNote);
              if (!mounted) return;
              setState(() {
                _notes = [..._notes, restoredNote]..sort(_sortNotesForDisplay);
              });
            },
          ),
        ),
      );
      Future<void>.delayed(const Duration(seconds: 4), () {
        snackController.close();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _notes = previousNotes;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('删除失败: $e')));
    }
  }

  Future<void> _handleTogglePin(Note note) async {
    final newPinStatus = note.isPinned == 1 ? 0 : 1;
    final newPinOrder =
        newPinStatus == 1 ? await _dbHelper.getNextPinOrder() : null;
    final updatedNote = note.copyWith(
      isPinned: newPinStatus,
      pinOrder: newPinOrder,
      clearPinOrder: newPinStatus == 0,
      updatedAt: DateTime.now(),
    );

    final previousNotes = List<Note>.from(_notes);
    setState(() {
      _notes = _notes
          .map(
            (currentNote) =>
                currentNote.id == note.id ? updatedNote : currentNote,
          )
          .toList();
      _notes.sort(_sortNotesForDisplay);
    });

    try {
      await _dbHelper.updateNote(updatedNote);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _notes = previousNotes;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('操作失败: $e')));
    }
  }

  Future<void> _handleToggleStar(Note note) async {
    final newStarStatus = note.isStarred == 1 ? 0 : 1;
    final updatedNote = note.copyWith(
      isStarred: newStarStatus,
      updatedAt: DateTime.now(),
    );

    final previousNotes = List<Note>.from(_notes);
    setState(() {
      _notes = _notes
          .map(
            (currentNote) =>
                currentNote.id == note.id ? updatedNote : currentNote,
          )
          .toList();
      _notes.sort(_sortNotesForDisplay);
    });

    try {
      await _dbHelper.updateNote(updatedNote);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _notes = previousNotes;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('操作失败: $e')));
    }
  }

  int _sortNotesForDisplay(Note a, Note b) {
    if (a.isPinned != b.isPinned) {
      return b.isPinned.compareTo(a.isPinned);
    }

    if (a.isPinned == 1 && b.isPinned == 1) {
      final aOrder = a.pinOrder ?? 1 << 30;
      final bOrder = b.pinOrder ?? 1 << 30;
      if (aOrder != bOrder) return aOrder.compareTo(bOrder);
    }

    switch (_currentSortOrder) {
      case 'updated_at ASC':
        return a.updatedAt.compareTo(b.updatedAt);
      case 'created_at DESC':
        return b.createdAt.compareTo(a.createdAt);
      case 'created_at ASC':
        return a.createdAt.compareTo(b.createdAt);
      case 'title ASC':
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      case 'title DESC':
        return b.title.toLowerCase().compareTo(a.title.toLowerCase());
      case 'updated_at DESC':
      default:
        return b.updatedAt.compareTo(a.updatedAt);
    }
  }

  void _onNoteCardUpdated(Note note) {
    _refreshNotes(showLoading: false);
  }

  Future<void> _navigateToSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
    if (mounted) {
      await _loadSettingsAndRefreshUI();
    }
  }

  Widget _buildDraftBanner(BuildContext context) {
    final draft = _newNoteDraft;
    if (draft == null) return const SizedBox.shrink();
    final preview = draft.content.trim().isEmpty
        ? '未填写正文'
        : draft.content.trim().replaceAll(RegExp(r'\s+'), ' ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Material(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _navigateToDetailScreen(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              children: [
                Icon(
                  Icons.drafts_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        draft.title.trim().isEmpty ? '未保存草稿' : draft.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: Colors.black.withValues(alpha: 0.56),
                                ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _discardNewNoteDraft,
                  icon: const Icon(Icons.close_rounded),
                  tooltip: '丢弃草稿',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color?.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          ),
          child: Text(
            _searchTerm.isEmpty
                ? (_filter == 'starred'
                    ? '收藏值得回看的内容\n在笔记菜单中点“收藏”即可收纳。'
                    : _filter == 'images'
                        ? '还没有带图片的笔记\n写笔记时，轻点图片按钮添加。'
                        : '留住此刻的想法\n轻点上方“新建”，开始第一篇记录。')
                : '未找到与 "$_searchTerm" 匹配的笔记。\n试试换一个关键词。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[700],
                  height: 1.5,
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotesList() {
    final visible = _notes
        .where((note) => switch (_filter) {
              'starred' => note.isStarred == 1,
              'images' => note.content.contains('!['),
              _ => true,
            })
        .toList();
    if (visible.isEmpty) return _buildEmptyState(context);
    return SlidableAutoCloseBehavior(
        child: ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final note = visible[index];
        final card = NoteCard(
          key: ValueKey(note.id),
          note: note,
          onDelete: () => _handleDeleteNote(note.id!),
          onTogglePin: () => _handleTogglePin(note),
          onToggleStar: () => _handleToggleStar(note),
          onCopyContent: () => _handleCopyNoteContent(note),
          onNoteUpdated: _onNoteCardUpdated,
        );
        return card;
      },
    ));
  }

  Widget _buildContent(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    final hasDraft = _newNoteDraft != null && _searchTerm.isEmpty;
    if (_notes.isEmpty && !hasDraft) return _buildEmptyState(context);
    return Column(
      children: [
        if (hasDraft) _buildDraftBanner(context),
        if (_notes.isEmpty)
          Expanded(child: _buildEmptyState(context))
        else
          Expanded(child: _buildNotesList()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('翼亭笔记', style: theme.textTheme.headlineSmall),
          Text(_isLoading ? '正在加载…' : '${_notes.length} 篇笔记',
              style: theme.textTheme.bodySmall),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '设置',
            onPressed: _navigateToSettings,
          ),
          const SizedBox(width: 12)
        ],
      ),
      body: SafeArea(
          child: Center(
              child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Column(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '搜索笔记',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchTerm.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          tooltip: '清除搜索',
                          onPressed: _clearSearch,
                        ),
                ),
                onChanged: _onSearchChanged,
              )),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Expanded(
                    child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          for (final entry in {
                            'all': '全部',
                            'starred': '收藏',
                            'images': '图片'
                          }.entries)
                            Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(entry.value),
                                  selected: _filter == entry.key,
                                  showCheckmark: false,
                                  side: BorderSide.none,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  onSelected: (_) =>
                                      setState(() => _filter = entry.key),
                                )),
                        ]))),
                const SizedBox(width: 8),
                ActionChip(
                  key: const ValueKey('create-note'),
                  onPressed: () => _navigateToDetailScreen(),
                  tooltip: '新建笔记',
                  avatar: Icon(Icons.add_rounded,
                      size: 18, color: theme.colorScheme.primary),
                  label: const Text('新建'),
                  labelStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.primary),
                  backgroundColor:
                      theme.colorScheme.primary.withValues(alpha: 0.06),
                  side: BorderSide(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  pressElevation: 0,
                ),
              ])),
          const SizedBox(height: 4),
          Expanded(child: _buildContent(context)),
        ]),
      ))),
    );
  }
}
