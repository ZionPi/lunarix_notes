// // lib/features/note_detail/views/note_detail_screen.dart
// import 'dart:convert';
// import 'package:flutter/foundation.dart'; // For kIsWeb
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:flutter_quill/flutter_quill.dart' as quill;
// // Ensure this single import brings in everything needed from extensions
// import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
//
// // Placeholder imports for actual image picking logic (add these packages to pubspec.yaml)
// // import 'dart:io' as io;
// // import 'package:image_picker/image_picker.dart';
// // import 'package:path_provider/path_provider.dart';
// // import 'package:path/path.dart' as p;
// // import 'package:uuid/uuid.dart';
//
// import '../../../core/database/database_helper.dart';
// import '../../../core/models/note.dart';
// import '../../../core/services/settings_service.dart';
//
// enum NoteDetailMode { editQuill, viewQuill }
//
// class NoteDetailScreen extends StatefulWidget {
//   final Note? note;
//   const NoteDetailScreen({super.key, this.note});
//
//   @override
//   State<NoteDetailScreen> createState() => _NoteDetailScreenState();
// }
//
// class _NoteDetailScreenState extends State<NoteDetailScreen> {
//   final DatabaseHelper _dbHelper = DatabaseHelper.instance;
//   late Note _currentNote;
//   bool _isNewNote = false;
//
//   late quill.QuillController _quillController;
//   final TextEditingController _titleController = TextEditingController();
//   final FocusNode _editorFocusNode = FocusNode();
//   final ScrollController _editorScrollController = ScrollController();
//
//   NoteDetailMode _currentMode = NoteDetailMode.editQuill;
//   bool _defaultTitleUsed = false;
//
//   final SettingsService _settingsService = SettingsService();
//   double _contentFontSize = 16.0;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadSettings();
//
//     String initialTitle = '';
//     quill.Document initialQuillDocument;
//
//     if (widget.note == null) {
//       // ... (New note logic - same as before)
//       _isNewNote = true;
//       final now = DateTime.now();
//       initialTitle = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
//       _defaultTitleUsed = true;
//       initialQuillDocument = quill.Document();
//       _currentNote = Note(title: initialTitle, content: jsonEncode(initialQuillDocument.toDelta().toJson()), createdAt: now, updatedAt: now);
//       _currentMode = NoteDetailMode.editQuill;
//     } else {
//       // ... (Existing note logic - same as before)
//       _isNewNote = false;
//       _currentNote = widget.note!;
//       initialTitle = _currentNote.title;
//       bool looksLikeJson = false;
//       if (_currentNote.content.isNotEmpty) {
//         final trimmedContent = _currentNote.content.trim();
//         looksLikeJson = (trimmedContent.startsWith('[') && trimmedContent.endsWith(']')) || (trimmedContent.startsWith('{') && trimmedContent.endsWith('}'));
//       }
//       if (looksLikeJson) {
//         try {initialQuillDocument = quill.Document.fromJson(jsonDecode(_currentNote.content));}
//         catch (e) {initialQuillDocument = quill.Document()..insert(0, _currentNote.content);}
//       } else {
//         initialQuillDocument = quill.Document()..insert(0, _currentNote.content);
//       }
//       _currentMode = NoteDetailMode.viewQuill;
//     }
//
//     _titleController.text = initialTitle;
//     _quillController = quill.QuillController(
//       document: initialQuillDocument,
//       selection: const TextSelection.collapsed(offset: 0),
//       // config: quill.QuillControllerConfig( /* For onImagePaste from clipboard */ )
//     );
//
//     if (_isNewNote && _defaultTitleUsed) {
//       _titleController.addListener(_onTitleChangeForDefault);
//     }
//   }
//
//   Future<void> _loadSettings() async {
//     _contentFontSize = await _settingsService.getNoteContentFontSize();
//     if (mounted) setState(() {});
//   }
//
//   void _onTitleChangeForDefault() {
//     // ... (Same as before)
//     if (_isNewNote && _defaultTitleUsed) {
//       try {
//         final String defaultTimestampTitle = DateFormat('yyyy-MM-dd HH:mm:ss').format(_currentNote.createdAt);
//         if (_titleController.text != defaultTimestampTitle) {
//           setState(() { _defaultTitleUsed = false; });
//           _titleController.removeListener(this._onTitleChangeForDefault);
//         }
//       } catch (_) {}
//     }
//   }
//
//   @override
//   void dispose() {
//     // ... (Same as before)
//     _titleController.removeListener(_onTitleChangeForDefault);
//     _titleController.dispose();
//     _quillController.dispose();
//     _editorFocusNode.dispose();
//     _editorScrollController.dispose();
//     super.dispose();
//   }
//
//   Future<void> _saveNote() async {
//     // ... (Same as before, no clearHistory())
//     final String title = _titleController.text.trim();
//     final String contentJson = jsonEncode(_quillController.document.toDelta().toJson());
//     bool isQuillContentEffectivelyEmpty = _quillController.document.isEmpty();
//
//     if (_isNewNote && _defaultTitleUsed && isQuillContentEffectivelyEmpty) { /* ... */ return; }
//     if (title.isEmpty && isQuillContentEffectivelyEmpty) { /* ... */ return; }
//     final DateTime now = DateTime.now();
//     _currentNote = _currentNote.copyWith(title: title, content: contentJson, updatedAt: now, createdAt: _isNewNote ? _currentNote.createdAt : _currentNote.createdAt);
//     try {
//       if (_isNewNote) { /* ... */ } else { /* ... */ }
//       if (mounted) Navigator.pop(context, true);
//     } catch (e) { /* ... */ }
//   }
//
//   // --- TODO: Implement Image Picking Callbacks ---
//   // Future<String?> _onImagePickCallbackToolbar(io.File file) async { /* ... */ }
//   // Future<quill.MediaPickSetting?> _selectMediaPickSettingToolbar(BuildContext context) async { /* ... */ }
//
//   Widget _buildEditModeUI() {
//     final editorTextStyle = TextStyle(fontSize: _contentFontSize, height: 1.5, color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87);
//
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.stretch,
//       children: [
//         Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
//           child: TextFormField( /* ... Title TextFormField ... */ ),
//         ),
//         const Divider(height: 1, thickness: 1),
//         quill.QuillSimpleToolbar(
//           controller: _quillController,
//           config: quill.QuillSimpleToolbarConfig(
//             // sharedConfigurations: const quill.QuillSharedConfigurations(), // Assuming this class might not exist based on earlier feedback
//             embedButtons: FlutterQuillEmbeds.toolbarButtons(),
//             showBoldButton: true, showItalicButton: true, showUnderLineButton: true,
//             showStrikeThrough: true, showHeaderStyle: true,
//             showListBullets: true, showListNumbers: true, showListCheck: true,
//             // Add other desired buttons from QuillSimpleToolbarConfig
//           ),
//         ),
//         const Divider(height: 1, thickness: 1),
//         Expanded(
//           child: Padding(
//             padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
//             child: quill.QuillEditor(
//               controller: _quillController,
//               focusNode: _editorFocusNode,
//               scrollController: _editorScrollController,
//               config: quill.QuillEditorConfig(
//                 // sharedConfigurations: const quill.QuillSharedConfigurations(),
//                 customStyles: quill.DefaultStyles(
//                   paragraph: quill.DefaultTextBlockStyle(
//                     editorTextStyle,
//                     const quill.HorizontalSpacing(0, 0), // Corrected
//                     const quill.VerticalSpacing(6, 0),
//                     const quill.VerticalSpacing(0, 0),
//                     null,
//                   ),
//                 ),
//                 embedBuilders: [ // No isReadOnly here
//                   ...FlutterQuillEmbeds.editorBuilders(),
//                   // TimeStampEmbedBuilder(), // Your custom embed if any
//                 ],
//                 expands: true,
//                 padding: const EdgeInsets.all(16),
//                 placeholder: '开始记录您的想法...',
//                 autoFocus: _isNewNote,
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildViewModeUI() {
//     final String displayTitle = _titleController.text;
//     final viewTextStyle = TextStyle(fontSize: _contentFontSize, height: 1.5, color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87);
//
//     return SingleChildScrollView(
//       padding: const EdgeInsets.all(16.0),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           if (displayTitle.isNotEmpty)
//             Padding(
//               padding: const EdgeInsets.only(bottom: 12.0),
//               child: SelectableText(displayTitle, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
//             ),
//           quill.QuillEditor(
//             controller: _quillController,
//             focusNode: FocusNode(),
//             scrollController: ScrollController(),
//             config: quill.QuillEditorConfig(
//               customStyles: quill.DefaultStyles(
//                   paragraph: quill.DefaultTextBlockStyle(
//                       viewTextStyle,
//                       const quill.HorizontalSpacing(0, 0),
//                       const quill.VerticalSpacing(6,0),
//                       const quill.VerticalSpacing(0,0),
//                       null
//                   )
//               ),
//               embedBuilders: [ // No isReadOnly here. EmbedBuilders should handle readOnly context.
//                 ...FlutterQuillEmbeds.editorBuilders(),
//                 // TimeStampEmbedBuilder(),
//               ],
//               expands: false,
//               padding: const EdgeInsets.all(16),
//               autoFocus: false,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     // ... (appBarTitle logic same as before)
//     String appBarTitle = _isNewNote ? '新建笔记' : (_titleController.text.isNotEmpty ? (_titleController.text.length > 15 ? '${_titleController.text.substring(0,15)}...' : _titleController.text) : '编辑笔记');
//     if (_isNewNote && _defaultTitleUsed && _titleController.text.isNotEmpty) { try { DateFormat('yyyy-MM-dd HH:mm:ss').parseStrict(_titleController.text); appBarTitle = '新建笔记'; } catch (_) { } }
//
//     // Removed QuillProvider based on feedback that it's not defined.
//     // Controller and configs are passed directly.
//     return Scaffold(
//       appBar: AppBar( /* ... Same as before ... */ ),
//       body: FocusScope(
//         child: _currentMode == NoteDetailMode.editQuill
//             ? _buildEditModeUI()
//             : _buildViewModeUI(),
//       ),
//     );
//   }
// }


// lib/features/note_detail/views/note_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
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
  late Note _currentNote;
  bool _isNewNote = false;
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  NoteDetailMode _currentMode = NoteDetailMode.editRaw;
  final _formKey = GlobalKey<FormState>();
  bool _defaultTitleUsed = false;

  final SettingsService _settingsService = SettingsService();
  double _contentFontSize = 16.0;

  // --- 1. 撤销/重做相关状态 ---
  // 为标题和内容分别创建历史栈
  final List<String> _titleUndoStack = [];
  final List<String> _titleRedoStack = [];
  final List<String> _contentUndoStack = [];
  final List<String> _contentRedoStack = [];

  bool _isPerformingUndoRedo = false; // 标志位，防止撤销/重做操作本身触发监听

  // 用于存储监听器添加时的初始值，避免将初始加载的值存入undo栈
  String? _initialTitleForUndo;
  String? _initialContentForUndo;

  @override
  void initState() {
    super.initState();
    print("--- NoteDetailScreen initState CALLED ---");
    _loadSettings();

    String initialTitle = '';
    String initialContent = '';

    if (widget.note == null) {
      // ... (新笔记逻辑不变)
      _isNewNote = true;
      final now = DateTime.now();
      try {
        initialTitle = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
      } catch (e) { initialTitle = "新建笔记"; }
      _defaultTitleUsed = true;
      _currentNote = Note(title: initialTitle, content: '', createdAt: now, updatedAt: now);
      _currentMode = NoteDetailMode.editRaw;
    } else {
      // ... (编辑笔记逻辑不变)
      _isNewNote = false;
      _currentNote = widget.note!;
      initialTitle = _currentNote.title;
      initialContent = _currentNote.content;
      _currentMode = initialContent.isNotEmpty && initialTitle.isNotEmpty
          ? NoteDetailMode.viewMarkdown
          : NoteDetailMode.editRaw;
    }

    _titleController = TextEditingController(text: initialTitle);
    _contentController = TextEditingController(text: initialContent);

    // 存储初始值，以便监听器知道何时开始记录undo
    _initialTitleForUndo = initialTitle;
    _initialContentForUndo = initialContent;

    // --- 2. 添加文本变化监听器 ---
    _titleController.addListener(_onTitleChangedForUndoRedo);
    _contentController.addListener(_onContentChangedForUndoRedo);

    if (_isNewNote && _defaultTitleUsed) {
      _titleController.addListener(_onTitleChangeForDefault);
    }
    print("--- NoteDetailScreen initState COMPLETED ---");
  }

  Future<void> _loadSettings() async {
    double loadedSize = await _settingsService.getNoteContentFontSize();
    print("NoteDetailScreen: Loaded font size from settings: $loadedSize");
    if (mounted) {
      setState(() {
        _contentFontSize = loadedSize; // 更新状态变量
      });
    }
  }


  void _onTitleChangeForDefault() {
    if (_isNewNote && _defaultTitleUsed) {
      final String defaultTimestampTitle = DateFormat('yyyy-MM-dd HH:mm:ss').format(_currentNote.createdAt);
      if (_titleController.text != defaultTimestampTitle) {
        setState(() {
          _defaultTitleUsed = false;
        });
        _titleController.removeListener(_onTitleChangeForDefault);
      }
    }
  }

  // --- 3. 文本变化监听回调 ---
  void _onTitleChangedForUndoRedo() {
    if (_isPerformingUndoRedo) return; // 如果是撤销/重做操作触发的，则忽略

    // 只有当实际文本与上一个undo栈顶不同时才记录 (或者栈为空时)
    // 并且确保不是初始加载的值被错误地当作“改变前”的值
    final currentText = _titleController.text;
    if (_initialTitleForUndo != null && currentText == _initialTitleForUndo) {
      // 如果当前文本仍然是初始加载的文本，则不记录undo，并将初始标志置空
      _initialTitleForUndo = null; // 下次真正的用户编辑将开始记录
      return;
    }
    if (_initialTitleForUndo != null &&_titleUndoStack.isEmpty) {
      _titleUndoStack.add(_initialTitleForUndo!); // 将初始值作为第一个可撤销状态
      _initialTitleForUndo = null; // 防止重复添加
    }


    if (_titleUndoStack.isEmpty || _titleUndoStack.last != currentText) {
      // 这里应该记录的是改变前的状态，但TextEditingController的listener在改变后触发
      // 所以我们需要一个稍微不同的策略：当用户输入时，我们记录当前状态
      // 当undo时，我们恢复到undoStack的最后一个，并将当前状态（undo前的）放入redoStack
      // 这种方式下，_onTextChanged 应该在 用户真正输入导致文本变化时，将 *变化前* 的文本压入undo栈
      // 但由于 listener 在变化后触发，我们退而求其次，当文本变化时，
      // 如果这个变化不是来自undo/redo，我们就认为这是一个新的编辑点
      // _titleUndoStack.add(_titleController.text); // 这会导致撤销的是当前状态，不对
      // 正确做法：listener 应该在文本 *将要* 改变时记录旧值，或在改变后记录新值并调整逻辑
      // 简化处理：每次稳定下来（listener被调用）就认为是一个可撤销的点，记录的是当前文本。
      // 撤销时恢复到上一个点。

      // 更好的方式：在文本变化时，将"上一个稳定状态"存入undo栈
      // 为了简化，我们这里接受一个稍微不那么完美的undo:
      // 即，当用户输入 "abc"，undo栈可能是 ["a", "ab", "abc"]
      // 撤销时，如果当前是 "abc"，恢复到 "ab"。

      // 我们采用标准的undo栈逻辑：记录的是产生当前状态之前的状态
      // 但controller.addListener在改变后才触发，所以我们需要记录上一个状态。
      // 为了简化，我们先实现一个“记录编辑点”的undo：
      // 即undo栈记录的是一系列用户编辑后的快照。

      // ---- 采用一种更标准的Undo/Redo实现方式 ----
      // 当文本改变，并且不是由于undo/redo操作：
      // 1. 将 "改变前" 的文本（如果能获取到的话，或者上一次undo栈的栈顶）存入undo栈。
      //    由于controller的listener在改变后触发，这里我们记录一个 "快照"
      //    当用户输入时，我们认为这是一个新的编辑点，应该可以撤销到 "输入前"。
      //    所以，当文本变化，我们将 "变化后的当前文本" 的 "前一个版本" 存起来。
      //    这个实现起来比较复杂。

      // ---- 简化版：基于快照的撤销 ----
      // 当文本改变时，如果栈顶不是当前文本，则将当前文本压入undo栈
      // （这意味着撤销会回到上一个字符状态，而不是一个大的编辑步骤）
      // 这会导致undo栈非常大，性能可能不好。

      // ---- 经典做法：记录操作或状态 ----
      // 我们记录一个 "有意义的" 编辑操作发生后的状态。
      // 例如，用户输入一段文本，然后停顿了一下，这可以被视为一个编辑单元。
      // 通过 controller.addListener，我们无法轻易区分这种“单元”。

      // 我们采用一种务实的做法：
      // 当监听到变化，并且不是undo/redo操作时：
      // 1. 如果undo栈不为空，且栈顶与当前controller的值不同，说明有新的编辑
      // 2. 我们将controller的 *当前值* 作为一个新的可撤销状态记录下来
      //    (这意味着undo操作会恢复到 *上一个* 记录的状态)
      // 3. 同时清空redo栈

      // 为了避免在每个字符输入时都记录，我们可以引入一个小的延迟/防抖
      // 但为了保持简单，我们先不加防抖。

      // --- 修正后的逻辑：_onTitleChangedForUndoRedo ---
      // 当监听到变化（非undo/redo引发）
      // 将 *变化前* 的状态（即undo栈的栈顶，或初始值）作为可撤销项。
      // 实际上，controller.text 已经是变化后的值了。
      // 所以，当用户输入时，我们应该把 *变化前* 的值（即上一次的值）存入undo栈
      // 这需要我们在某处保存 "上一次的值"
      // 为了简化，我们接受一个这样的模型：
      // undo栈存储的是一系列的历史快照。当用户编辑，我们将当前文本加入undo栈。
      // 当用户撤销，我们将当前文本移到redo栈，并从undo栈恢复上一个。

      if (_titleUndoStack.isEmpty || _titleUndoStack.last != _titleController.text) {
        // 实际上，这里应该添加的是变化前的文本
        // 但由于listener的限制，我们只能添加变化后的
        // 所以，我们需要在执行undo/redo时调整压栈逻辑

        // 简单的实现：当文本变化时，如果和undo栈顶不同，则认为是新的编辑
        // 我们把“变化前”的值（即_lastKnownTitle）推入undo栈
        // _lastKnownTitle 需要在合适时机更新

        // 为了实现简单，我们先用一个稍微不同的模型：
        // 当用户编辑，将当前状态视为一个新的可撤销点。
        // 当撤销时，将当前状态放入redo，然后从undo栈取上一个状态。
        // 这要求在编辑时，undo栈需要有“编辑前”的状态。

        // 让我们重新思考：
        // 初始状态: title = "A"
        // 用户改成 "AB": undo=["A"], redo=[]
        // 用户改成 "ABC": undo=["A", "AB"], redo=[]
        // 撤销: title="AB", current="ABC"放入redo, undo=["A"], redo=["ABC"]
        // 撤销: title="A", current="AB"放入redo, undo=[], redo=["ABC", "AB"]
        // 重做: title="AB", current="A"放入undo, redo=["ABC"], undo=["A"]

        // 所以，在 onTextChanged 时，我们需要把 *改变前* 的状态放入 undoStack。
        // 这意味着我们需要一个变量来存储上一个状态。

        // 让我们用另一种方式，即undoStack存储的是可以恢复到的历史版本。
        // 当编辑时，把当前版本存入undoStack。
        // 为了防止undoStack无限增长或者记录每个字符，我们可以考虑“编辑会话”
        // 但这里先做基础的。

        if (_undoRedoBufferTitle != _titleController.text) { // 使用buffer避免连续相同的值
          _titleUndoStack.add(_undoRedoBufferTitle); // 将变化前的状态压入undo栈
          _titleRedoStack.clear(); // 新的编辑会使重做历史无效
          _undoRedoBufferTitle = _titleController.text; // 更新buffer为当前状态
          setState(() {}); // 更新按钮状态
        }
      }
    }
  }
  String _undoRedoBufferTitle = ""; // 用于存储上一次稳定的文本状态
  String _undoRedoBufferContent = "";


  void _onContentChangedForUndoRedo() {
    if (_isPerformingUndoRedo) return;

    final currentText = _contentController.text;
    if (_initialContentForUndo != null && currentText == _initialContentForUndo) {
      _initialContentForUndo = null;
      return;
    }
    if (_initialContentForUndo != null && _contentUndoStack.isEmpty) {
      _contentUndoStack.add(_initialContentForUndo!);
      _initialContentForUndo = null;
    }


    if (_undoRedoBufferContent != _contentController.text) {
      _contentUndoStack.add(_undoRedoBufferContent);
      _contentRedoStack.clear();
      _undoRedoBufferContent = _contentController.text;
      setState(() {});
    }
  }

  // --- 4. 撤销/重做执行方法 ---
  void _undoTitle() {
    if (_titleUndoStack.isNotEmpty) {
      _isPerformingUndoRedo = true;
      _titleRedoStack.add(_titleController.text); // 将当前状态存入重做栈
      _titleController.text = _titleUndoStack.removeLast(); // 恢复到上一个状态
      _undoRedoBufferTitle = _titleController.text; // 更新buffer
      _isPerformingUndoRedo = false;
      setState(() {}); // 更新按钮状态
    }
  }

  void _redoTitle() {
    if (_titleRedoStack.isNotEmpty) {
      _isPerformingUndoRedo = true;
      _titleUndoStack.add(_titleController.text); // 将当前状态存入撤销栈
      _titleController.text = _titleRedoStack.removeLast(); // 从重做栈恢复
      _undoRedoBufferTitle = _titleController.text; // 更新buffer
      _isPerformingUndoRedo = false;
      setState(() {});
    }
  }

  void _undoContent() {
    if (_contentUndoStack.isNotEmpty) {
      _isPerformingUndoRedo = true;
      _contentRedoStack.add(_contentController.text);
      _contentController.text = _contentUndoStack.removeLast();
      _undoRedoBufferContent = _contentController.text;
      _isPerformingUndoRedo = false;
      setState(() {});
    }
  }

  void _redoContent() {
    if (_contentRedoStack.isNotEmpty) {
      _isPerformingUndoRedo = true;
      _contentUndoStack.add(_contentController.text);
      _contentController.text = _contentRedoStack.removeLast();
      _undoRedoBufferContent = _contentController.text;
      _isPerformingUndoRedo = false;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTitleChangedForUndoRedo);
    _contentController.removeListener(_onContentChangedForUndoRedo);
    _titleController.removeListener(_onTitleChangeForDefault);
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() { // 在initState之后，但在build之前被调用，或者当依赖变化时
    super.didChangeDependencies();
    // 在这里初始化buffer，确保它们有初始值
    // 这也可能在从后台返回等情况下被调用，所以需要小心
    // 如果只希望在第一次加载时设置，可以结合一个标志位
    if (_undoRedoBufferTitle.isEmpty && _titleController.text.isNotEmpty && _titleUndoStack.isEmpty) {
      // 这个条件可能不完美，主要是为了在加载现有笔记时，能有一个初始的buffer值
      _undoRedoBufferTitle = _titleController.text;
    }
    if (_undoRedoBufferContent.isEmpty && _contentController.text.isNotEmpty && _contentUndoStack.isEmpty) {
      _undoRedoBufferContent = _contentController.text;
    }
    // 或者更简单，在initState加载完controller后直接设置buffer的初始值
    if (widget.note != null) { // 如果是编辑现有笔记
      _undoRedoBufferTitle = _titleController.text;
      _undoRedoBufferContent = _contentController.text;
    } else { // 新建笔记，初始为空或默认标题
      _undoRedoBufferTitle = _titleController.text; // 也可以是 ""
      _undoRedoBufferContent = "";
    }

  }


  Future<void> _saveNote() async {

    _titleUndoStack.clear();
    _titleRedoStack.clear();
    _contentUndoStack.clear();
    _contentRedoStack.clear();
    // 重置buffer为当前已保存状态
    _undoRedoBufferTitle = _titleController.text;
    _undoRedoBufferContent = _contentController.text;
    if(mounted) setState(() {}); // 更新按钮状态

    final String title = _titleController.text.trim();
    final String content = _contentController.text.trim();

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

    final DateTime now = DateTime.now();
    _currentNote = _currentNote.copyWith(
      title: title,
      content: content,
      updatedAt: now,
      createdAt: _isNewNote ? _currentNote.createdAt : _currentNote.createdAt,
    );

    try {
      if (_isNewNote) {
        final createdNote = await _dbHelper.createNote(_currentNote);
        _currentNote = createdNote;
        _isNewNote = false;
        if (_defaultTitleUsed) { // 如果是默认标题保存的，移除监听
          _titleController.removeListener(_onTitleChangeForDefault);
          _defaultTitleUsed = false;
        }
      } else {
        await _dbHelper.updateNote(_currentNote);
      }
      if(mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: ${e.toString()}')),
        );
      }
    }
  }



  Widget _buildEditModeUI() {
    print("NoteDetailScreen _buildEditModeUI: Using font size: $_contentFontSize");
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, // <--- 可选：让列内子项水平填充
          children: <Widget>[
            TextFormField(
              // ... (标题 TextFormField 不变)
              controller: _titleController,
              decoration: InputDecoration( /* ... */ ),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              // ...
            ),
            const Divider(height: 1, thickness: 1),
            const SizedBox(height: 8),
            Expanded(
              child: ConstrainedBox( // <--- 1. 包裹一层 ConstrainedBox
                constraints: const BoxConstraints(
                  minHeight: 200.0, // <--- 2. 设置一个最小高度，例如 200 dp
                  // 你可以根据屏幕高度的比例来设置，例如:
                  // minHeight: MediaQuery.of(context).size.height * 0.3,
                ),
                child: TextFormField(
                  controller: _contentController,
                  decoration: const InputDecoration(
                    hintText: '开始记录您的想法...',
                    border: InputBorder.none, // 保持无边框，使其融入背景
                    // contentPadding: EdgeInsets.zero, // 如果有默认内边距影响，可以设为zero
                  ),
                  style: TextStyle(fontSize: _contentFontSize),
                  maxLines: null, // 允许无限行输入
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  expands: true, // <--- 3. 配合 ConstrainedBox，让 TextFormField 尝试填满父级约束
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewModeUI() {
    print("NoteDetailScreen _buildViewModeUI: Using font size: $_contentFontSize"); // 调试打印
    final String markdownData = _contentController.text;
    final String displayTitle = _titleController.text;

    // 确保 Theme.of(context).textTheme.bodyMedium 不是 null
    final TextStyle defaultBodyStyle = Theme.of(context).textTheme.bodyMedium ?? const TextStyle(fontSize: 16.0); // 提供一个备用fontSize

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (displayTitle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: SelectableText(
                displayTitle,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
          if (markdownData.isEmpty && displayTitle.isNotEmpty)
            const Text("*笔记内容为空*", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),

          // --- 5. 应用字体大小到预览模式 (Markdown) ---
          MarkdownBody(
            data: markdownData.isEmpty && displayTitle.isEmpty ? "*空空如也*" : markdownData, // 如果标题内容都空，给个提示
            selectable: true,
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
              p: defaultBodyStyle.copyWith(fontSize: _contentFontSize),
              // 你也可以为其他Markdown元素（如h1, h2, li等）应用基于_contentFontSize的样式
              // 例如:
              // h1: (Theme.of(context).textTheme.headlineSmall ?? const TextStyle(fontSize: 24)).copyWith(fontSize: _contentFontSize + 8),
              // li: defaultBodyStyle.copyWith(fontSize: _contentFontSize),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ... (appBarTitle 计算不变) ...
    String appBarTitle = _isNewNote ? '新建笔记' : '编辑笔记';
    // ...

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new), // 之前是 arrow_back
          tooltip: '返回',
          onPressed: () {
            // TODO: 检查是否有未保存的更改，提示用户
            Navigator.pop(context, false); // 默认返回false
          },
        ),
        actions: <Widget>[
          // --- 5. 添加撤销/重做按钮 ---
          // 判断焦点来决定是对标题还是内容进行撤销/重做，或者提供两组按钮
          // 为了简单，我们假设主要对内容进行撤销/重做，或最后编辑的那个
          // 更好的方式是根据当前焦点决定。这里我们先只做内容的。
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: '撤销内容修改',
            onPressed: _contentUndoStack.isNotEmpty ? _undoContent : null, // 根据栈是否为空启用/禁用
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            tooltip: '重做内容修改',
            onPressed: _contentRedoStack.isNotEmpty ? _redoContent : null,
          ),
          // 你也可以为标题添加独立的撤销/重做按钮
          // IconButton(icon: Icon(Icons.undo, color: Colors.blue), onPressed: _titleUndoStack.isNotEmpty ? _undoTitle : null),
          // IconButton(icon: Icon(Icons.redo, color: Colors.blue), onPressed: _titleRedoStack.isNotEmpty ? _redoTitle : null),

          IconButton(
            icon: Icon(_currentMode == NoteDetailMode.editRaw
                ? Icons.visibility_outlined
                : Icons.edit_outlined),
            tooltip: _currentMode == NoteDetailMode.editRaw ? '预览Markdown' : '编辑Raw文本',
            onPressed: () {
              setState(() {
                _currentMode = _currentMode == NoteDetailMode.editRaw
                    ? NoteDetailMode.viewMarkdown
                    : NoteDetailMode.editRaw;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.save_outlined), // 保存图标
            tooltip: '保存笔记',
            onPressed: _saveNote,
          ),
        ],
      ),
      body: _currentMode == NoteDetailMode.editRaw
          ? _buildEditModeUI()
          : _buildViewModeUI(),
    );
  }
}


