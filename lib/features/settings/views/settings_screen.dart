import 'package:flutter/material.dart';

import '../../../core/services/import_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  final ImportService _importService = ImportService();

  double _noteContentFontSize = 16.0;
  String _currentSortOrderValue = 'updated_at DESC';
  String _selectedThemePresetName = 'default';

  final List<Map<String, String>> _sortOptions = [
    {'value': 'updated_at DESC', 'text': '按更新时间降序'},
    {'value': 'updated_at ASC', 'text': '按更新时间升序'},
    {'value': 'created_at DESC', 'text': '按创建时间降序'},
    {'value': 'created_at ASC', 'text': '按创建时间升序'},
    {'value': 'title ASC', 'text': '按标题升序 (A-Z)'},
    {'value': 'title DESC', 'text': '按标题降序 (Z-A)'},
  ];

  final Map<String, String> _themePresetDisplayNames = {
    'default': '默认主题 (蓝绿)',
    'preset1': '翼亭红与绿',
    'preset2': '深蓝青与草绿',
    'preset3': '宝石蓝与活力橙',
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _noteContentFontSize = await _settingsService.getNoteContentFontSize();
    _currentSortOrderValue = await _settingsService.getLastSortOrder();
    _selectedThemePresetName =
        await _settingsService.getSelectedThemePresetName();

    if (mounted) {
      setState(() {});
    }
  }

  void _onThemePresetChanged(String? presetName) {
    if (presetName == null || presetName == _selectedThemePresetName) {
      return;
    }

    setState(() {
      _selectedThemePresetName = presetName;
    });

    _settingsService.setSelectedThemePresetName(presetName).then((_) {
      lunarixAppKey.currentState?.refreshTheme();
    });
  }

  Future<void> _importDatabaseBackup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入数据库备份'),
        content: const Text('这会直接覆盖当前应用内的全部笔记数据，请确认已经做好备份。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('继续导入'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final result = await _importService.pickAndImportDatabaseBackup();
    if (!mounted) return;

    if (result == null) {
      messenger.showSnackBar(const SnackBar(content: Text('导入已取消。')));
      return;
    }

    messenger.showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _importJsonNotes() async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await _importService.pickAndImportNotes();
    if (!mounted) return;

    if (result == null) {
      messenger.showSnackBar(const SnackBar(content: Text('导入已取消。')));
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '导入完成：成功 ${result.importedCount} 条，失败 ${result.failedCount} 条',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: <Widget>[
          Text(
            '显示与浏览',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
            child: Text(
              '笔记列表排序方式',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          DropdownButtonFormField<String>(
            value: _currentSortOrderValue,
            isExpanded: true,
            decoration: const InputDecoration(
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            ),
            items: _sortOptions.map((option) {
              return DropdownMenuItem<String>(
                value: option['value'],
                child: Text(option['text']!),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue == null) return;
              setState(() {
                _currentSortOrderValue = newValue;
              });
              _settingsService.setLastSortOrder(newValue);
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
            child: Text(
              '应用主题预设',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          Column(
            children: SettingsService.themePresets.keys.map((presetName) {
              return RadioListTile<String>(
                title: Text(_themePresetDisplayNames[presetName] ?? presetName),
                value: presetName,
                groupValue: _selectedThemePresetName,
                onChanged: _onThemePresetChanged,
                secondary: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      color: SettingsService
                          .themePresets[presetName]!['appBarColor'],
                    ),
                    const SizedBox(width: 5),
                    Container(
                      width: 20,
                      height: 20,
                      color: SettingsService
                          .themePresets[presetName]!['cardBackgroundColor'],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text('笔记内容字体大小: ${_noteContentFontSize.toStringAsFixed(1)}'),
          ),
          Slider(
            value: _noteContentFontSize,
            min: 12.0,
            max: 28.0,
            divisions: 16,
            label: _noteContentFontSize.round().toString(),
            onChanged: (double value) {
              setState(() {
                _noteContentFontSize = value;
              });
            },
            onChangeEnd: (double value) {
              _settingsService.setNoteContentFontSize(value);
            },
          ),
          const SizedBox(height: 12),
          Text(
            '数据与迁移',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.storage_rounded),
            title: const Text('导入数据库备份'),
            subtitle: const Text('选择 .db 文件并覆盖恢复当前全部笔记'),
            onTap: _importDatabaseBackup,
          ),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('导入 JSON 笔记'),
            subtitle: const Text('兼容旧的 JSON 导入格式'),
            onTap: _importJsonNotes,
          ),
          const Divider(),
          ListTile(
            title: const Text('关于'),
            subtitle: const Text('翼亭笔记 v1.0.0'),
            leading: const Icon(Icons.info_outline),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: '翼亭笔记',
                applicationVersion: '1.0.0+1',
                applicationLegalese: '©2025-2026 zp/月翼亭创新荣誉出品',
                children: const <Widget>[
                  Padding(
                    padding: EdgeInsets.only(top: 15),
                    child: Text('一款简洁高效的笔记应用。'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
