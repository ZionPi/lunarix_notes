// lib/core/database/database_helper.dart
import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/note.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init(); // 单例模式
  static Database? _database;

  DatabaseHelper._init(); // 私有构造函数

  Future<Database> get database async {
    if (_database != null) return _database!; // 如果已初始化，直接返回
    _database = await _initDB(await databasePath); // 初始化数据库
    return _database!;
  }

  Future<String> get databasePath async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, 'lunarix_notes.db');
  }

  Future<Database> _initDB(String path) async {
    // 打开数据库，如果数据库不存在，则会调用 onCreate
    // version 用于数据库升级 (迁移)
    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  // 当数据库第一次被创建时调用
  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const nullableTextType = 'TEXT';
    const integerType = 'INTEGER NOT NULL';
    // const nullableIntegerType = 'INTEGER'; // 如果有可选的整型外键

    await db.execute('''
CREATE TABLE notes (
  id $idType,
  title $textType,
  content $textType,
  created_at $textType, 
  updated_at $textType, 
  source_filename $nullableTextType,
  folder_id INTEGER, -- 外键，后续会关联到 folders 表
  is_archived $integerType DEFAULT 0,
  is_deleted $integerType DEFAULT 0,
  deleted_at $nullableTextType,
  color $nullableTextType,
  is_pinned $integerType DEFAULT 0,
  pin_order INTEGER,
  is_starred $integerType DEFAULT 0
  -- 后续添加其他字段:
  -- ebbinghaus_last_reviewed_at TEXT,
  -- ebbinghaus_next_review_at TEXT,
  -- ebbinghaus_current_interval_days INTEGER DEFAULT 0,
  -- ebbinghaus_ease_factor REAL DEFAULT 2.5,
  -- ebbinghaus_repetitions INTEGER DEFAULT 0
)
''');

    // 未来可以在这里创建其他表，例如 folders, tags, attachments
    // await db.execute('''
    // CREATE TABLE folders (
    //   id $idType,
    //   name $textType,
    //   created_at $textType
    // )
    // ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE notes ADD COLUMN pin_order INTEGER');
      final pinnedRows = await db.query(
        'notes',
        columns: ['id'],
        where: 'is_pinned = 1 AND is_deleted = 0',
        orderBy: 'updated_at DESC',
      );
      for (var i = 0; i < pinnedRows.length; i++) {
        await db.update(
          'notes',
          {'pin_order': i},
          where: 'id = ?',
          whereArgs: [pinnedRows[i]['id']],
        );
      }
    }
  }

  String _safeSortOrder(String currentSortOrder) {
    switch (currentSortOrder) {
      case 'updated_at ASC':
      case 'created_at DESC':
      case 'created_at ASC':
      case 'title ASC':
      case 'title DESC':
      case 'updated_at DESC':
        return currentSortOrder;
      default:
        return 'updated_at DESC';
    }
  }

  String _notesOrderBy(String currentSortOrder) {
    final safeSortOrder = _safeSortOrder(currentSortOrder);
    return 'is_pinned DESC, CASE WHEN pin_order IS NULL THEN 1 ELSE 0 END, pin_order ASC, $safeSortOrder';
  }

  // --- CRUD (Create, Read, Update, Delete) 操作 ---

  // 创建笔记
  Future<Note> createNote(Note note) async {
    final db = await instance.database;
    // db.insert 返回新插入行的 id
    final id = await db.insert('notes', note.toMap());
    return note.copyWith(id: id); // 返回带有新 id 的 Note 对象
  }

  // 根据ID读取单个笔记
  Future<Note?> getNoteById(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      'notes',
      columns: null, // null 表示选择所有列
      where: 'id = ? AND is_deleted = 0', // 只获取未被软删除的
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Note.fromMap(maps.first);
    } else {
      return null; // 未找到
    }
  }

  // 读取所有笔记 (可带排序)
  Future<List<Note>> getAllNotes({
    String currentSortOrder = 'updated_at DESC',
  }) async {
    final db = await instance.database;
    final orderBy = _notesOrderBy(currentSortOrder);

    final result = await db.query(
      'notes',
      where: 'is_deleted = 0', // 只获取未被软删除的
      orderBy: orderBy,
    );

    return result.map((jsonMap) => Note.fromMap(jsonMap)).toList();
  }

  // 搜索笔记 (标题或内容匹配)
  Future<List<Note>> searchNotes(
    String query, {
    String currentSortOrder = 'updated_at DESC',
  }) async {
    final db = await instance.database;
    final orderBy = _notesOrderBy(currentSortOrder);

    final result = await db.query(
      'notes',
      where: '(title LIKE ? OR content LIKE ?) AND is_deleted = 0',
      whereArgs: ['%$query%', '%$query%'], // % 是SQL的通配符
      orderBy: orderBy,
    );
    return result.map((jsonMap) => Note.fromMap(jsonMap)).toList();
  }

  // 更新笔记
  Future<int> updateNote(Note note) async {
    final db = await instance.database;
    return db.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  Future<int> getNextPinOrder() async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT MAX(pin_order) AS max_order FROM notes WHERE is_pinned = 1 AND is_deleted = 0',
    );
    final maxOrder = result.first['max_order'] as int?;
    return (maxOrder ?? -1) + 1;
  }

  Future<void> updatePinnedOrder(List<Note> pinnedNotes) async {
    final db = await instance.database;
    final batch = db.batch();
    for (var i = 0; i < pinnedNotes.length; i++) {
      final id = pinnedNotes[i].id;
      if (id == null) continue;
      batch.update('notes', {'pin_order': i}, where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  // 软删除笔记 (标记为已删除)
  Future<int> softDeleteNote(int id) async {
    final db = await instance.database;
    return db.update(
      'notes',
      {
        'is_deleted': 1,
        'deleted_at': DateTime.now().toIso8601String(),
        'is_pinned': 0, // 取消置顶当软删除时
        'pin_order': null,
        'is_starred': 0, // 取消加星当软删除时 (可选逻辑)
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> restoreNote(int id) async {
    final db = await instance.database;
    return db.update(
      'notes',
      {
        'is_deleted': 0,
        'deleted_at': null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 永久删除笔记 (如果需要回收站清空功能)
  Future<int> permanentlyDeleteNote(int id) async {
    final db = await instance.database;
    return db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  // (可选) 获取所有已软删除的笔记 (用于回收站)
  Future<List<Note>> getDeletedNotes() async {
    final db = await instance.database;
    final result = await db.query(
      'notes',
      where: 'is_deleted = 1',
      orderBy: 'deleted_at DESC',
    );
    return result.map((jsonMap) => Note.fromMap(jsonMap)).toList();
  }

  // 关闭数据库连接
  Future close() async {
    final db = await instance.database;
    await db.close();
    _database = null; // 清除引用，以便下次可以重新初始化
  }

  Future<void> replaceDatabaseFromFile(String sourcePath) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw Exception('备份文件不存在。');
    }

    final tempDb = await openDatabase(sourcePath, readOnly: true);
    try {
      final result = await tempDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='notes' LIMIT 1",
      );
      if (result.isEmpty) {
        throw Exception('所选文件不是有效的翼亭笔记数据库。');
      }
    } finally {
      await tempDb.close();
    }

    final targetPath = await databasePath;
    final targetFile = File(targetPath);
    final journalFile = File('$targetPath-journal');
    final walFile = File('$targetPath-wal');
    final shmFile = File('$targetPath-shm');

    if (_database != null) {
      await close();
    }

    if (await targetFile.exists()) {
      await targetFile.delete();
    }
    if (await journalFile.exists()) {
      await journalFile.delete();
    }
    if (await walFile.exists()) {
      await walFile.delete();
    }
    if (await shmFile.exists()) {
      await shmFile.delete();
    }

    await sourceFile.copy(targetPath);
    _database = await _initDB(targetPath);
  }

  // (测试用) 清空所有笔记 - 小心使用！
  Future<void> dangerResetDatabase() async {
    final db = await instance.database;
    await db.delete('notes');
    // 如果有其他表，也需要在这里删除
    // 例如: await db.delete('folders');
  }
}
