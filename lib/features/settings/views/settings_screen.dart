// lib/features/settings/views/settings_screen.dart
import 'package:flutter/material.dart';
import '../../../core/services/settings_service.dart'; // 导入服务
import '../../../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = SettingsService();

  bool _showImportButton = true;
  double _noteContentFontSize = 16.0;
  // 当前排序规则不在这个页面直接修改，它是在 NotesListScreen 中选择，这里只是为了演示可以读取
  bool _showNoteCardTitleConfig = true; // <--- 新增状态变量

  String _currentSortOrderValue = 'updated_at DESC'; // <--- 1. 新增状态变量存储当前选择的排序

  String _selectedThemePresetName = 'default'; // <--- 2. 状态变量存储当前选择的预设名称

  // 定义排序选项的显示文本和对应的值
  final List<Map<String, String>> _sortOptions = [ // <--- 2. 定义排序选项
    {'value': 'updated_at DESC', 'text': '按更新时间降序'},
    {'value': 'updated_at ASC', 'text': '按更新时间升序'},
    {'value': 'created_at DESC', 'text': '按创建时间降序'},
    {'value': 'created_at ASC', 'text': '按创建时间升序'},
    {'value': 'title ASC', 'text': '按标题升序 (A-Z)'},
    {'value': 'title DESC', 'text': '按标题降序 (Z-A)'},
  ];


  // 用于主题预设显示的名称
  final Map<String, String> _themePresetDisplayNames = { // <--- 3. 预设显示名称
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
    _showImportButton = await _settingsService.getShowImportButton();
    _showNoteCardTitleConfig = await _settingsService.getShowNoteCardTitle();
    _noteContentFontSize = await _settingsService.getNoteContentFontSize();
    _currentSortOrderValue = await _settingsService.getLastSortOrder();
    _selectedThemePresetName = await _settingsService.getSelectedThemePresetName();

    if (mounted) {
      setState(() {});
    }
  }


  void _onThemePresetChanged(String? presetName) {
    if (presetName != null && presetName != _selectedThemePresetName) {
      setState(() {
        _selectedThemePresetName = presetName;
      });
      _settingsService.setSelectedThemePresetName(presetName).then((_) {
        // 主题颜色已在 SettingsService 内部保存到 SharedPreferences
        // 现在通知 MaterialApp 重建以应用新主题
        // 我们通过 GlobalKey 调用 main.dart 中 _LunarixNotesAppState 的 refreshTheme 方法
        lunarixAppKey.currentState?.refreshTheme(); // <--- 6. 触发主题刷新
        print("SettingsScreen: Theme preset changed to $presetName and refresh triggered.");
      });
    }
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
          const Divider(),
          SwitchListTile(
            title: const Text('显示导入笔记按钮'),
            value: _showImportButton,
            onChanged: (bool value) {
              setState(() {
                _showImportButton = value;
              });
              _settingsService.setShowImportButton(value);
            },
          ),
          const Divider(),

          SwitchListTile( // <--- 新增 SwitchListTile
            title: const Text('在笔记卡片上显示标题'),
            value: _showNoteCardTitleConfig,
            onChanged: (bool value) {
              setState(() {
                _showNoteCardTitleConfig = value;
              });
              _settingsService.setShowNoteCardTitle(value);
            },
          ),


          const Divider(),
          Padding(
            padding: const EdgeInsets.only(top: 16.0, bottom: 0.0, left: 16.0, right: 16.0),
            child: Text(
              '笔记列表排序方式:',
              style: TextStyle(
                fontSize: 16, //Theme.of(context).textTheme.titleMedium?.fontSize,
                color: Theme.of(context).textTheme.bodySmall?.color, // 更柔和的颜色
              ),
            ),
          ),
          // <--- 4. 添加排序方式选择的 DropdownButtonFormField ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: DropdownButtonFormField<String>(
              value: _currentSortOrderValue,
              isExpanded: true, // 让下拉菜单和按钮一样宽
              decoration: InputDecoration(
                // border: OutlineInputBorder(), // 可选：添加边框
                contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              ),
              items: _sortOptions.map((option) {
                return DropdownMenuItem<String>(
                  value: option['value'],
                  child: Text(option['text']!),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _currentSortOrderValue = newValue;
                  });
                  _settingsService.setLastSortOrder(newValue); // 保存新的排序规则
                }
              },
            ),
          ),
          const Divider(),

          Padding(
            padding: const EdgeInsets.only(top: 16.0, bottom: 8.0, left: 16.0, right: 16.0),
            child: Text(
              '应用主题预设:',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ),
          // 使用 Column 和 RadioListTile 来展示预设选项
          Column(
            children: SettingsService.themePresets.keys.map((presetName) {
              return RadioListTile<String>(
                title: Text(_themePresetDisplayNames[presetName] ?? presetName), // 显示友好名称
                value: presetName,
                groupValue: _selectedThemePresetName,
                onChanged: _onThemePresetChanged, // 调用我们上面定义的方法
                secondary: Row( // 显示颜色预览
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 20, height: 20, color: SettingsService.themePresets[presetName]!['appBarColor']),
                    const SizedBox(width: 5),
                    Container(width: 20, height: 20, color: SettingsService.themePresets[presetName]!['cardBackgroundColor']),
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
            divisions: 16, // (28-12)
            label: _noteContentFontSize.round().toString(),
            onChanged: (double value) {
              setState(() {
                _noteContentFontSize = value;
              });
            },
            onChangeEnd: (double value) { // 在滑动结束后保存，避免频繁写入
              _settingsService.setNoteContentFontSize(value);
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('关于'),
            subtitle: const Text('翼亭笔记 v1.0.0'), // 示例版本号
            leading: const Icon(Icons.info_outline),
            onTap: () {
              // 可以显示一个 AboutDialog
              showAboutDialog(
                context: context,
                applicationName: '翼亭笔记',
                applicationVersion: '1.0.0+1', // 从 pubspec.yaml 获取
                applicationLegalese: '©2025-2026 zp/月翼亭创新荣誉出品',
                children: <Widget>[
                  const Padding(
                      padding: EdgeInsets.only(top: 15),
                      child: Text('一款简洁高效的笔记应用。')
                  )
                ],
              );
            },
          )
        ],
      ),
    );
  }
}