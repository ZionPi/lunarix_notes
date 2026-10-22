import 'package:flutter/material.dart';

import '../../../core/services/import_service.dart';
import '../../../core/services/app_info_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../main.dart';
import '../../../core/widgets/confirm_action_sheet.dart';

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
  String? _versionLabel;

  static const _sortFields = {
    'updated_at': ('更新时间', Icons.history_rounded),
    'created_at': ('创建时间', Icons.calendar_today_outlined),
    'title': ('笔记标题', Icons.sort_by_alpha_rounded),
  };

  String get _sortDescription {
    final parts = _currentSortOrderValue.split(' ');
    final field = _sortFields[parts.first]?.$1 ?? '更新时间';
    final ascending = parts.last == 'ASC';
    final direction = parts.first == 'title'
        ? (ascending ? 'A → Z' : 'Z → A')
        : (ascending ? '旧的在前' : '新的在前');
    return '$field · $direction';
  }

  Future<void> _chooseSortOrder() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) =>
          StatefulBuilder(builder: (context, updateSheet) {
        final parts = _currentSortOrderValue.split(' ');
        final field = parts.first;
        final ascending = parts.last == 'ASC';
        void change(String value) {
          setState(() => _currentSortOrderValue = value);
          updateSheet(() {});
          _settingsService.setLastSortOrder(value);
        }

        final theme = Theme.of(context);
        return SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Expanded(
                          child:
                              Text('浏览顺序', style: theme.textTheme.titleMedium)),
                      IconButton(
                          tooltip: '关闭排序设置',
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded, size: 20)),
                    ]),
                    const SizedBox(height: 8),
                    Text('排序依据', style: theme.textTheme.bodySmall),
                    const SizedBox(height: 8),
                    for (final entry in _sortFields.entries)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            tileColor: field == entry.key
                                ? theme.colorScheme.primary
                                    .withValues(alpha: 0.06)
                                : null,
                            leading: Icon(entry.value.$2,
                                size: 20,
                                color: field == entry.key
                                    ? theme.colorScheme.primary
                                    : null),
                            title: Text(entry.value.$1),
                            trailing: field == entry.key
                                ? Icon(Icons.check_rounded,
                                    color: theme.colorScheme.primary, size: 20)
                                : null,
                            onTap: () => change(
                                '${entry.key} ${entry.key == 'title' ? 'ASC' : 'DESC'}'),
                          )),
                    const SizedBox(height: 16),
                    Text('排列方向', style: theme.textTheme.bodySmall),
                    const SizedBox(height: 10),
                    SegmentedButton<bool>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                            value: false,
                            label: Text(field == 'title' ? 'Z → A' : '新的在前')),
                        ButtonSegment(
                            value: true,
                            label: Text(field == 'title' ? 'A → Z' : '旧的在前')),
                      ],
                      selected: {ascending},
                      onSelectionChanged: (value) =>
                          change('$field ${value.first ? 'ASC' : 'DESC'}'),
                    ),
                  ]),
            ));
      }),
    );
  }

  Widget _themeSwatches() => LayoutBuilder(builder: (context, constraints) {
        final width = (constraints.maxWidth - 24) / 4;
        return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final preset in SettingsService.themePresets.entries)
                SizedBox(
                    width: width,
                    child: Semantics(
                      button: true,
                      selected: _selectedThemePresetName == preset.key,
                      label: _themePresetDisplayNames[preset.key],
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _onThemePresetChanged(preset.key),
                        child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(children: [
                              Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: preset.value['appBarColor'],
                                      border: Border.all(
                                          color: Colors.white, width: 3),
                                      boxShadow: [
                                        BoxShadow(
                                            color: _selectedThemePresetName ==
                                                    preset.key
                                                ? preset.value['appBarColor']!
                                                    .withValues(alpha: 0.5)
                                                : const Color(0xFFE4E9E4),
                                            spreadRadius: 1)
                                      ]),
                                  child: _selectedThemePresetName == preset.key
                                      ? const Icon(Icons.check_rounded,
                                          color: Colors.white, size: 18)
                                      : null),
                              const SizedBox(height: 10),
                              Text(_themePresetDisplayNames[preset.key]!,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          color: _selectedThemePresetName ==
                                                  preset.key
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                              : null)),
                            ])),
                      ),
                    )),
            ]);
      });

  final Map<String, String> _themePresetDisplayNames = {
    'default': '松间绿',
    'preset1': '陶土玫瑰',
    'preset2': '雾海蓝',
    'preset3': '暖砂岩',
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
    _versionLabel = await AppInfoService().getVersion();

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
    final confirmed = await confirmActionSheet(context,
        title: '恢复数据库备份？',
        message: '这会替换当前全部笔记。请先保留可恢复的备份。',
        confirmLabel: '继续恢复',
        destructive: true);

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

  Widget _section(String title, String subtitle, List<Widget> children) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall),
                  ])),
          Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE9EDE7))),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children),
            ),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: Center(
          child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            children: [
              _section('外观', '主题色', [_themeSwatches()]),
              _section('阅读与编辑', '调整正文的阅读字号', [
                Row(children: [
                  const Text('正文字号'),
                  const Spacer(),
                  Text('${_noteContentFontSize.round()}',
                      style: theme.textTheme.titleMedium)
                ]),
                Slider(
                    value: _noteContentFontSize.clamp(12, 28),
                    min: 12,
                    max: 28,
                    onChanged: (value) => setState(
                        () => _noteContentFontSize = value.roundToDouble()),
                    onChangeEnd: (value) => _settingsService
                        .setNoteContentFontSize(value.roundToDouble())),
                Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(12)),
                    child: Text('把日常的灵感，慢慢写成自己的故事。',
                        style: TextStyle(
                            fontSize: _noteContentFontSize, height: 1.8))),
              ]),
              _section('浏览顺序', '置顶笔记始终在前', [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                      _sortFields[_currentSortOrderValue.split(' ').first]
                              ?.$2 ??
                          Icons.sort_rounded),
                  title: Text(_sortDescription),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                  onTap: _chooseSortOrder,
                ),
              ]),
              _section('数据与迁移', '导入与恢复', [
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.note_add_outlined),
                    title: const Text('导入 JSON 笔记'),
                    subtitle: const Text('添加到现有笔记中'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _importJsonNotes),
                const Divider(height: 24),
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.restore_rounded,
                        color: theme.colorScheme.error),
                    title: const Text('从数据库备份恢复'),
                    subtitle: const Text('会替换当前全部笔记，请谨慎操作'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _importDatabaseBackup),
              ]),
              Center(
                  child: Column(children: [
                Icon(Icons.auto_stories_outlined,
                    color: theme.colorScheme.primary, size: 28),
                const SizedBox(height: 8),
                Text('翼亭笔记', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(_versionLabel == null ? '让记录回归简单' : 'v$_versionLabel',
                    style: theme.textTheme.bodySmall),
              ])),
            ]),
      )),
    );
  }
}
