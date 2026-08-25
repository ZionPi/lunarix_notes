import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/models/note.dart';
import '../../../core/services/draft_service.dart';
import '../../../core/services/settings_service.dart';
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
  String _currentSortOrder = 'updated_at DESC';
  final TextEditingController _searchController = TextEditingController();

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final DraftService _draftService = DraftService();
  final SettingsService _settingsService = SettingsService();

  @override
  void initState() {
    super.initState();
    _loadSettingsAndRefreshUI();
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

  Future<void> _handleReorderNotes(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _notes.length) return;
    final movedNote = _notes[oldIndex];
    if (movedNote.isPinned != 1) return;

    final pinnedCount = _notes.where((note) => note.isPinned == 1).length;
    var targetIndex = newIndex;
    if (targetIndex >= pinnedCount) targetIndex = pinnedCount - 1;
    if (targetIndex < 0) targetIndex = 0;
    if (targetIndex == oldIndex) return;

    final previousNotes = List<Note>.from(_notes);
    final pinnedNotes =
        _notes.where((note) => note.isPinned == 1).toList(growable: true);
    final unpinnedNotes = _notes.where((note) => note.isPinned != 1).toList();

    final item = pinnedNotes.removeAt(oldIndex);
    pinnedNotes.insert(targetIndex, item);
    final reorderedPinned = [
      for (var i = 0; i < pinnedNotes.length; i++)
        pinnedNotes[i].copyWith(pinOrder: i),
    ];

    setState(() {
      _notes = [...reorderedPinned, ...unpinnedNotes];
    });

    try {
      await _dbHelper.updatePinnedOrder(reorderedPinned);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _notes = previousNotes;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('置顶排序保存失败: $e')));
    }
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
                ? '还没有笔记。\n点击右上角的 + 新建一篇，或去设置页导入备份。'
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
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      onReorderItem: _handleReorderNotes,
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 16),
      itemCount: _notes.length,
      itemBuilder: (context, index) {
        final note = _notes[index];
        final card = NoteCard(
          key: ValueKey(note.id),
          note: note,
          onDelete: () => _handleDeleteNote(note.id!),
          onTogglePin: () => _handleTogglePin(note),
          onToggleStar: () => _handleToggleStar(note),
          onCopyContent: () => _handleCopyNoteContent(note),
          onNoteUpdated: _onNoteCardUpdated,
          showDragHandle: note.isPinned == 1,
          dragIndex: note.isPinned == 1 ? index : null,
        );
        return card;
      },
    );
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: '设置',
          onPressed: _navigateToSettings,
        ),
        title: const Text('翼亭笔记'),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索标题或正文',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchTerm.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        tooltip: '清除搜索',
                        onPressed: _clearSearch,
                      ),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: '新建笔记',
            onPressed: () => _navigateToDetailScreen(),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: _buildContent(context),
      ),
    );
  }
}
