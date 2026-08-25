// lib/core/services/settings_service.dart
import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _keyShowAppBarTitle = 'showAppBarTitle';
  static const String _keyShowImportButton = 'showImportButton';
  static const String _keyLastSortOrder = 'lastSortOrder';
  static const String _keyNoteContentFontSize = 'noteContentFontSize';
  static const String _keyShowNoteCardTitle = 'showNoteCardTitle';
  static const String _keyAppBarColor = 'appBarColor';
  static const String _keyCardBackgroundColor = 'cardBackgroundColor';
  static const String _keySelectedThemePreset = 'selectedThemePreset';

  static const Map<String, Map<String, Color>> themePresets = {
    'default': {
      // 你当前的默认颜色
      'appBarColor': Color(0xFF42519B),
      'cardBackgroundColor': Color(0xFFC8E374),
    },
    'preset1': {
      // 翼亭红与绿
      'appBarColor': Color(0xFFC60000),
      'cardBackgroundColor': Color(0xFF00A07B),
    },
    'preset2': {
      // 深蓝与青草绿
      'appBarColor': Color(0xFF0F1732),
      'cardBackgroundColor': Color(0xFF7CCE51),
    },
    'preset3': {
      // 宝石蓝与活力橙
      'appBarColor': Color(0xFF2F3491),
      'cardBackgroundColor': Color(0xFFFFB343),
    }
  };

  Future<SharedPreferences> _getPrefs() async {
    return SharedPreferences.getInstance();
  }

  // --- App Bar Title Visibility ---
  Future<bool> getShowAppBarTitle() async {
    final prefs = await _getPrefs();
    return prefs.getBool(_keyShowAppBarTitle) ?? true; // 默认为 true (显示)
  }

  Future<void> setShowAppBarTitle(bool value) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_keyShowAppBarTitle, value);
  }

  // --- Import Button Visibility ---
  Future<bool> getShowImportButton() async {
    final prefs = await _getPrefs();
    return prefs.getBool(_keyShowImportButton) ?? true; // 默认为 true (显示)
  }

  Future<void> setShowImportButton(bool value) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_keyShowImportButton, value);
  }

  // --- Last Sort Order ---
  Future<String> getLastSortOrder() async {
    final prefs = await _getPrefs();
    return prefs.getString(_keyLastSortOrder) ?? 'updated_at DESC'; // 默认排序
  }

  Future<void> setLastSortOrder(String value) async {
    final prefs = await _getPrefs();
    await prefs.setString(_keyLastSortOrder, value);
  }

  // --- Note Content Font Size ---
  Future<double> getNoteContentFontSize() async {
    final prefs = await _getPrefs();
    return prefs.getDouble(_keyNoteContentFontSize) ?? 16.0; // 默认字体大小
  }

  Future<void> setNoteContentFontSize(double value) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(_keyNoteContentFontSize, value);
  }

  Future<bool> getShowNoteCardTitle() async {
    // <--- 新增 Getter
    final prefs = await _getPrefs();
    return prefs.getBool(_keyShowNoteCardTitle) ?? true; // 默认为 true (显示卡片标题)
  }

  Future<void> setShowNoteCardTitle(bool value) async {
    // <--- 新增 Setter
    final prefs = await _getPrefs();
    await prefs.setBool(_keyShowNoteCardTitle, value);
  }

  // --- Selected Theme Preset ---
  Future<String> getSelectedThemePresetName() async {
    // <--- 新增
    final prefs = await _getPrefs();
    return prefs.getString(_keySelectedThemePreset) ??
        'default'; // 默认为 'default'
  }

  Future<void> setSelectedThemePresetName(String presetName) async {
    // <--- 新增
    final prefs = await _getPrefs();
    await prefs.setString(_keySelectedThemePreset, presetName);
    // 当选择预设时，也直接保存该预设对应的颜色值
    if (themePresets.containsKey(presetName)) {
      await setAppBarColorValue(
          themePresets[presetName]!['appBarColor']!.toARGB32());
      await setCardBackgroundColorValue(
          themePresets[presetName]!['cardBackgroundColor']!.toARGB32());
    }
  }

  // --- AppBar Color ---
  Future<Color> getAppBarColor() async {
    final prefs = await _getPrefs();
    final colorValue = prefs.getInt(_keyAppBarColor);
    // 如果没有存储颜色值，则从当前选择的预设中获取
    if (colorValue == null) {
      String presetName = await getSelectedThemePresetName();
      return themePresets[presetName]?['appBarColor'] ??
          themePresets['default']!['appBarColor']!;
    }
    return Color(colorValue);
  }

  Future<void> setAppBarColorValue(int colorValue) async {
    // 存储 int 值
    final prefs = await _getPrefs();
    await prefs.setInt(_keyAppBarColor, colorValue);
  }

  // --- Card Background Color ---
  Future<Color> getCardBackgroundColor() async {
    final prefs = await _getPrefs();
    final colorValue = prefs.getInt(_keyCardBackgroundColor);
    if (colorValue == null) {
      String presetName = await getSelectedThemePresetName();
      return themePresets[presetName]?['cardBackgroundColor'] ??
          themePresets['default']!['cardBackgroundColor']!;
    }
    return Color(colorValue);
  }

  Future<void> setCardBackgroundColorValue(int colorValue) async {
    // 存储 int 值
    final prefs = await _getPrefs();
    await prefs.setInt(_keyCardBackgroundColor, colorValue);
  }
}
