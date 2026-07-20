// lib/core/services/import_service.dart
import 'dart:convert'; // 用于 jsonDecode
import 'dart:io'; // 用于 File 操作
import 'package:file_picker/file_picker.dart'; // 文件选择器
import 'package:intl/intl.dart'; // 用于日期格式化和解析

import '../models/note.dart'; // Note 模型
import '../database/database_helper.dart'; // 数据库帮助类

// 定义导入结果的数据结构
class ImportResult {
  final int importedCount;
  final int failedCount;
  final List<String> errorMessages; // (可选) 记录导入失败的具体原因

  ImportResult({
    required this.importedCount,
    required this.failedCount,
    this.errorMessages = const [],
  });
}

class DatabaseImportResult {
  final bool success;
  final String message;

  const DatabaseImportResult({
    required this.success,
    required this.message,
  });
}

class ImportService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // 挑选并导入笔记
  Future<ImportResult?> pickAndImportNotes() async {
    // 1. 使用 file_picker 选择文件
    FilePickerResult? pickerResult = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'], // 只允许选择 .json 文件
      dialogTitle: '请选择要导入的笔记文件 (JSON)',
    );

    if (pickerResult != null && pickerResult.files.single.path != null) {
      File file = File(pickerResult.files.single.path!);
      try {
        // 2. 读取文件内容
        String jsonString = await file.readAsString();
        print("ImportService: JSON file content read successfully.");

        // 3. 解析 JSON
        // 假设JSON的顶层是一个列表
        List<dynamic> jsonList;
        try {
          jsonList = jsonDecode(jsonString) as List<dynamic>;
          print(
              "ImportService: JSON parsed successfully. Found ${jsonList.length} items.");
        } catch (e) {
          print("ImportService: Error decoding JSON string: $e");
          return ImportResult(
              importedCount: 0,
              failedCount: 0,
              errorMessages: ['JSON文件格式无效或无法解析。']);
        }

        int importedCount = 0;
        int failedCount = 0;
        List<String> errors = [];

        // 4. 遍历JSON列表，转换并存入数据库
        for (var item in jsonList) {
          if (item is Map<String, dynamic>) {
            try {
              // 您提供的JSON结构:
              // {
              //   "filename": "分析招聘需求.md",
              //   "title": "分析招聘需求",
              //   "modification_time": "2025/06/04 10:27:09", // 需要解析
              //   "content": "分析招聘需求\n汇总哪些是重点\n"
              // }

              String? title = item['title'] as String?;
              String? content = item['content'] as String?;
              String? filename = item['filename'] as String?;
              String? modTimeString = item['modification_time'] as String?;
              DateTime modificationTime;

              if (title == null || title.trim().isEmpty) {
                // 如果原始标题为空，可以尝试从文件名生成一个标题，或者使用默认值
                if (filename != null && filename.isNotEmpty) {
                  title = filename.replaceAll('.md', ''); // 移除.md后缀
                } else {
                  title = "无标题笔记 (导入)"; // 默认标题
                }
              }

              if (content == null) {
                content = ""; // 内容可以为空
              }

              // 解析 "modification_time"
              if (modTimeString != null && modTimeString.isNotEmpty) {
                try {
                  // 尝试使用 intl 包解析 "yyyy/MM/dd HH:mm:ss" 格式
                  DateFormat inputFormat = DateFormat("yyyy/MM/dd HH:mm:ss");
                  modificationTime = inputFormat.parse(modTimeString);
                } catch (e) {
                  print(
                      "ImportService: Failed to parse modification_time '$modTimeString'. Using current time. Error: $e");
                  modificationTime = DateTime.now(); // 解析失败则使用当前时间
                  errors.add("笔记 '$title': 日期格式错误 '$modTimeString', 已使用当前时间。");
                }
              } else {
                modificationTime = DateTime.now(); // 如果没有提供时间，使用当前时间
                errors.add("笔记 '$title': 未提供修改时间, 已使用当前时间。");
              }

              final note = Note(
                title: title,
                content: content,
                sourceFilename: filename,
                createdAt: modificationTime, // 导入时，创建时间视为修改时间
                updatedAt: modificationTime,
                // 其他字段使用 Note 构造函数中的默认值 (isPinned, isStarred, etc.)
              );

              await _dbHelper.createNote(note);
              importedCount++;
              print("ImportService: Successfully imported note: ${note.title}");
            } catch (e, s) {
              // 捕获异常和堆栈跟踪
              failedCount++;
              String errorMsg =
                  "导入笔记 '${item['title'] ?? '未知标题'}' 失败: ${e.toString()}";
              print("ImportService: $errorMsg\nStackTrace: $s");
              errors.add(errorMsg);
            }
          } else {
            failedCount++;
            String errorMsg = "JSON中发现无效的笔记条目 (非Map类型): $item";
            print("ImportService: $errorMsg");
            errors.add(errorMsg);
          }
        }
        print(
            "ImportService: Import process completed. Imported: $importedCount, Failed: $failedCount");
        return ImportResult(
          importedCount: importedCount,
          failedCount: failedCount,
          errorMessages: errors,
        );
      } catch (e, s) {
        // 捕获文件读取或初始JSON解析的异常
        print(
            "ImportService: Error processing or reading file: ${e.toString()}\nStackTrace: $s");
        return ImportResult(
            importedCount: 0,
            failedCount: 0,
            errorMessages: ['读取或处理文件时出错: ${e.toString()}']);
      }
    } else {
      // 用户取消了文件选择器
      print("ImportService: User cancelled file picking.");
      return null; // 返回 null 表示用户取消
    }
  }

  Future<DatabaseImportResult?> pickAndImportDatabaseBackup() async {
    final pickerResult = await FilePicker.platform.pickFiles(
      type: FileType.any,
      dialogTitle: '请选择要导入的数据库备份文件',
    );

    if (pickerResult == null || pickerResult.files.single.path == null) {
      return null;
    }

    final filePath = pickerResult.files.single.path!;
    final file = File(filePath);
    final fileName = pickerResult.files.single.name.toLowerCase();

    if (!fileName.endsWith('.db')) {
      return const DatabaseImportResult(
        success: false,
        message: '请选择 .db 数据库备份文件。',
      );
    }

    if (!await file.exists()) {
      return const DatabaseImportResult(
        success: false,
        message: '所选数据库文件不存在。',
      );
    }

    try {
      await _dbHelper.replaceDatabaseFromFile(filePath);
      return const DatabaseImportResult(
        success: true,
        message: '数据库已成功导入。',
      );
    } catch (e) {
      return DatabaseImportResult(
        success: false,
        message: '导入数据库失败: $e',
      );
    }
  }
}
