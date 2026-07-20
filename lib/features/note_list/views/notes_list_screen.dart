import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/models/note.dart';
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
  bool _isLoading = true;
  String _searchTerm = '';
  String _currentSortOrder = 'updated_at DESC';
  final TextEditingController _searchController = TextEditingController();

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
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

      if (mounted) {
        setState(() {
          _notes = notes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载笔记失败: ${e.toString()}')),
        );
        setState(() {
          _notes = [];
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('这条笔记没有可复制的正文内容')),
      );
      return;
    }

    await Clipboard.setData(ClipboardData(text: content));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制卡片内容')),
    );
  }

  Future<void> _navigateToDetailScreen([Note? note]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteDetailScreen(note: note),
      ),
    );

    if (result == true && mounted) {
      await _refreshNotes(showLoading: false);
    }
  }

  Future<void> _handleDeleteNote(int noteId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: const Text('您确定要删除这条笔记吗？此操作会将笔记移至回收站。'),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('删除'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) return;

    final previousNotes = List<Note>.from(_notes);
    setState(() {
      _notes = _notes.where((note) => note.id != noteId).toList();
    });

    try {
      await _dbHelper.softDeleteNote(noteId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('笔记已移至回收站')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _notes = previousNotes;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除失败: $e')),
      );
    }
  }

  Future<void> _handleTogglePin(Note note) async {
    final newPinStatus = note.isPinned == 1 ? 0 : 1;
    final updatedNote = note.copyWith(
      isPinned: newPinStatus,
      updatedAt: DateTime.now(),
    );

    final previousNotes = List<Note>.from(_notes);
    setState(() {
      _notes = _notes
          .map((currentNote) =>
              currentNote.id == note.id ? updatedNote : currentNote)
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败: $e')),
      );
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
          .map((currentNote) =>
              currentNote.id == note.id ? updatedNote : currentNote)
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败: $e')),
      );
    }
  }

  int _sortNotesForDisplay(Note a, Note b) {
    if (a.isPinned != b.isPinned) {
      return b.isPinned.compareTo(a.isPinned);
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
                hintText: '搜索笔记',
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _notes.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .cardTheme
                              .color
                              ?.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Text(
                          _searchTerm.isEmpty
                              ? '还没有笔记。\n点击右上角的 + 新建一篇，或去设置页导入备份。'
                              : '未找到与 "$_searchTerm" 匹配的笔记。\n试试换一个关键词。',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.grey[700],
                                    height: 1.5,
                                  ),
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 16),
                    itemCount: _notes.length,
                    itemBuilder: (context, index) {
                      final note = _notes[index];
                      return NoteCard(
                        note: note,
                        onDelete: () => _handleDeleteNote(note.id!),
                        onTogglePin: () => _handleTogglePin(note),
                        onToggleStar: () => _handleToggleStar(note),
                        onCopyContent: () => _handleCopyNoteContent(note),
                        onNoteUpdated: _onNoteCardUpdated,
                      );
                    },
                  ),
      ),
    );
  }
}
