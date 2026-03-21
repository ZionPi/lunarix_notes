// lib/core/models/note.dart

class Note {
  int? id; // 数据库自增ID，可以为null（例如在新笔记保存前）
  String title;
  String content;
  DateTime createdAt;
  DateTime updatedAt;
  String? sourceFilename; // 导入时的原始文件名 (可选)
  int? folderId;          // 所属文件夹ID (可选，后续功能)
  int isArchived;        // 是否已归档 (0 for false, 1 for true)
  int isDeleted;         // 是否已软删除 (0 for false, 1 for true)
  DateTime? deletedAt;     // 软删除时间 (可选)
  String? color;           // 卡片颜色 (可选，后续功能)
  int isPinned;          // 是否置顶 (0 for false, 1 for true)
  int isStarred;         // 是否加星 (0 for false, 1 for true)

  // --- 后续会添加的字段 ---
  //艾宾浩斯相关
  // DateTime? ebbinghausLastReviewedAt;
  // DateTime? ebbinghausNextReviewAt;
  // int ebbinghausCurrentIntervalDays;
  // double ebbinghausEaseFactor;
  // int ebbinghausRepetitions;

  //费曼学习法相关
  // String? feynmanStage;
  // int feynmanIsTeachingExplanation;
  // List<int>? feynmanRelatedNotesIds; // 存储关联笔记的ID

  //AI相关
  // String? aiSummary;
  // List<String>? aiKeywords;

  //附件信息 (未来可能是一个独立的 Attachment 类或 List<Attachment>)
  // List<String>? attachmentPaths;


  Note({
    this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.sourceFilename,
    this.folderId,
    this.isArchived = 0, // 默认值
    this.isDeleted = 0,  // 默认值
    this.deletedAt,
    this.color,
    this.isPinned = 0,   // 默认值
    this.isStarred = 0,  // 默认值

    //后续字段的初始化
    // this.ebbinghausLastReviewedAt,
    // this.ebbinghausNextReviewAt,
    // this.ebbinghausCurrentIntervalDays = 0,
    // this.ebbinghausEaseFactor = 2.5,
    // this.ebbinghausRepetitions = 0,
    // this.feynmanStage,
    // this.feynmanIsTeachingExplanation = 0,
    // this.feynmanRelatedNotesIds,
    // this.aiSummary,
    // this.aiKeywords,
    // this.attachmentPaths,
  });

  // 方法：将Note对象转换为Map对象 (用于写入数据库)
  Map<String, dynamic> toMap() {
    return {
      'id': id, // id 在插入时通常由数据库生成，所以可以是null
      'title': title,
      'content': content,
      'created_at': createdAt.toIso8601String(), // 存储为ISO8601字符串
      'updated_at': updatedAt.toIso8601String(), // 存储为ISO8601字符串
      'source_filename': sourceFilename,
      'folder_id': folderId,
      'is_archived': isArchived,
      'is_deleted': isDeleted,
      'deleted_at': deletedAt?.toIso8601String(), // 可选字段
      'color': color,
      'is_pinned': isPinned,
      'is_starred': isStarred,
      // 后续字段的映射
    };
  }

  // 方法：从Map对象创建Note对象 (用于从数据库读取)
  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as int?,
      title: map['title'] as String,
      content: map['content'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      sourceFilename: map['source_filename'] as String?,
      folderId: map['folder_id'] as int?,
      isArchived: map['is_archived'] as int? ?? 0, // 提供默认值以防数据库中为null (虽然表结构定义为NOT NULL)
      isDeleted: map['is_deleted'] as int? ?? 0,
      deletedAt: map['deleted_at'] != null ? DateTime.parse(map['deleted_at'] as String) : null,
      color: map['color'] as String?,
      isPinned: map['is_pinned'] as int? ?? 0,
      isStarred: map['is_starred'] as int? ?? 0,
      // 后续字段的映射
    );
  }

  // copyWith 方法，方便创建对象的副本并修改部分属性
  Note copyWith({
    int? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? sourceFilename,
    int? folderId,
    int? isArchived,
    int? isDeleted,
    DateTime? deletedAt, // 注意：允许null以清除deletedAt
    bool clearDeletedAt = false, // 特殊标志用于显式清除
    String? color,
    int? isPinned,
    int? isStarred,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sourceFilename: sourceFilename ?? this.sourceFilename,
      folderId: folderId ?? this.folderId,
      isArchived: isArchived ?? this.isArchived,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      color: color ?? this.color,
      isPinned: isPinned ?? this.isPinned,
      isStarred: isStarred ?? this.isStarred,
    );
  }

  @override
  String toString() { // 方便调试时打印Note对象
    return 'Note{id: $id, title: "$title", updatedAt: $updatedAt, isPinned: $isPinned, isStarred: $isStarred}';
  }
}