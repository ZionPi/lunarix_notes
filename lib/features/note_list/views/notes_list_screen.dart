// lib/features/note_list/views/notes_list_screen.dart
import 'package:flutter/material.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/models/note.dart';
import '../../note_detail/views/note_detail_screen.dart'; // 确保路径正确
import '../widgets/note_card.dart';
import '../../../core/services/import_service.dart';
import '../../../core/services/settings_service.dart';
import '../../settings/views/settings_screen.dart'; // <--- 1. 导入 SettingsScreen

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

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final ImportService _importService = ImportService();
  final SettingsService _settingsService = SettingsService();

  // --- 2. 添加状态变量用于存储从设置加载的值 ---
  // bool _showAppBarTitleConfig = true;
  bool _showImportButtonConfig = true;
  bool _showNoteCardTitleFromSettings = true; // <--- 1. 新增状态变量


  @override
  void initState() {
    super.initState();
    _loadSettingsAndRefreshUI(); // <--- 3. 重命名并修改方法调用
  }

  // <--- 4. 修改此方法以加载所有相关设置 ---
  Future<void> _loadSettingsAndRefreshUI() async {
    if (!mounted) return;
    setState(() { _isLoading = true; });

    _currentSortOrder = await _settingsService.getLastSortOrder();
    _showImportButtonConfig = await _settingsService.getShowImportButton();
    _showNoteCardTitleFromSettings = await _settingsService.getShowNoteCardTitle(); // <--- 2. 加载配置
    // 确保在设置加载后再刷新笔记列表
    await _refreshNotes();
    // _refreshNotes 内部会处理 setState(() { _isLoading = false; });
  }

  Future<void> _refreshNotes() async {
    if (!mounted) return;
    if (!_isLoading) { // 如果不是在加载流程中被调用，则主动设为加载状态
      setState(() { _isLoading = true; });
    }

    try {
      if (_searchTerm.isEmpty) {
        _notes = await _dbHelper.getAllNotes(currentSortOrder: _currentSortOrder);
      } else {
        _notes = await _dbHelper.searchNotes(_searchTerm, currentSortOrder: _currentSortOrder);
      }


    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载笔记失败: ${e.toString()}')),
        );
      }
      _notes = [];
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
    if (!mounted) return;
    setState(() {
      _searchTerm = query;
    });
    _refreshNotes();
  }

  Future<void> _navigateToDetailScreen([Note? note]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteDetailScreen(
          note: note,
        ),
      ),
    );

    if (result == true && mounted) {
      _refreshNotes();
    }
  }

  // void _onSortOrderChanged(String value) {
  //   if (_currentSortOrder != value) {
  //     if (!mounted) return;
  //     setState(() {
  //       _currentSortOrder = value;
  //     });
  //     _settingsService.setLastSortOrder(value);
  //     _refreshNotes();
  //   }
  // }

  Future<void> _handleDeleteNote(int noteId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
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

    if (confirm == true && mounted) {
      try {
        await _dbHelper.softDeleteNote(noteId);
        _refreshNotes();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('笔记已移至回收站')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e')),
          );
        }
      }
    }
  }

  Future<void> _handleTogglePin(Note note) async {
    // ... (置顶逻辑不变) ...
    final newPinStatus = note.isPinned == 1 ? 0 : 1;
    final updatedNote = note.copyWith(isPinned: newPinStatus, updatedAt: DateTime.now());
    try {
      await _dbHelper.updateNote(updatedNote);
      _refreshNotes();
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(newPinStatus == 1 ? '笔记已置顶' : '笔记已取消置顶')));
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失败: $e')));
    }
  }

  Future<void> _handleToggleStar(Note note) async {
    // ... (加星逻辑不变) ...
    final newStarStatus = note.isStarred == 1 ? 0 : 1;
    final updatedNote = note.copyWith(isStarred: newStarStatus, updatedAt: DateTime.now());
    try {
      await _dbHelper.updateNote(updatedNote);
      _refreshNotes();
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(newStarStatus == 1 ? '笔记已加星' : '笔记已取消加星')));
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失败: $e')));
    }
  }

  void _onNoteCardUpdated(Note possiblyStaleNote) {
    _refreshNotes();
  }

  Future<void> _handleImportNotes() async {
    // ... (导入逻辑不变, 但它的显示将受配置控制) ...
    if (!mounted) return;
    setState(() { _isLoading = true; });
    try {
      final ImportResult? importResult = await _importService.pickAndImportNotes();
      if (mounted) {
        if (importResult != null) {
          // ... (处理导入结果)
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('导入已取消。')));
        }
      }
    } catch (e) { /* ... */ }
    finally { if(mounted) setState(() { _isLoading = false; });}
  }

  // <--- 5. 添加导航到设置页面的方法 ---
  Future<void> _navigateToSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
    // 从设置页返回后，重新加载所有设置并刷新UI，因为设置可能已更改
    if (mounted) {
      _loadSettingsAndRefreshUI();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // --- 1. 设置按钮作为 leading ---
        leading: IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: '设置',
          onPressed: _navigateToSettings,
        ),
        title: const Text('翼亭笔记'),
        centerTitle: true, // 可以尝试让标题居中，因为 leading 有图标了
        actions: <Widget>[ // --- 2. 调整 actions 顺序 ---
          // 导入按钮（如果显示）
          if (_showImportButtonConfig)
            IconButton(
              icon: const Icon(Icons.file_download_outlined),
              tooltip: '导入笔记',
              onPressed: _handleImportNotes,
            ),
          // 新建笔记按钮放在最右边
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: '新建笔记',
            onPressed: () => _navigateToDetailScreen(),
          ),
          // PopupMenuButton for sorting is REMOVED from here
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight + 8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 12.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: '快速搜索关键字...',
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _searchTerm.isEmpty
                ? '还没有笔记。\n点击右上角的 + 新建一篇，或导入已有笔记。'
                : '未找到与 "$_searchTerm" 匹配的笔记。\n尝试更换搜索词。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
          ),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
        itemCount: _notes.length,
        itemBuilder: (context, index) {
          final note = _notes[index];
          return NoteCard(
            note: note,
            onDelete: () => _handleDeleteNote(note.id!),
            onTogglePin: () => _handleTogglePin(note),
            onToggleStar: () => _handleToggleStar(note),
            onNoteUpdated: _onNoteCardUpdated,
            showTitle: _showNoteCardTitleFromSettings,
          );
        },
      ),
    );
  }
}

