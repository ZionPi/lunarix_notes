// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'features/note_list/views/notes_list_screen.dart';
import 'core/services/settings_service.dart';

const Color _initialAppBarColor = Color(0xFF42519B);
const Color _initialCardBackgroundColor = Color(0xFFC8E374);

GlobalKey<_LunarixNotesAppState> lunarixAppKey = GlobalKey();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(LunarixNotesApp(key: lunarixAppKey));
}

class LunarixNotesApp extends StatefulWidget {
  const LunarixNotesApp({super.key});

  @override
  State<LunarixNotesApp> createState() => _LunarixNotesAppState();
}

class _LunarixNotesAppState extends State<LunarixNotesApp> {
  final SettingsService _settingsService = SettingsService();
  ThemeData _currentTheme =
      _buildThemeData(_initialAppBarColor, _initialCardBackgroundColor);

  @override
  void initState() {
    super.initState();
    _loadThemeColors();
  }

  Future<void> _loadThemeColors() async {
    print("Main: Loading theme colors...");
    Color appBarColor = await _settingsService.getAppBarColor();
    Color cardBackgroundColor = await _settingsService.getCardBackgroundColor();
    print(
        "Main: Loaded AppBarColor: $appBarColor, CardBackgroundColor: $cardBackgroundColor");
    if (mounted) {
      setState(() {
        _currentTheme = _buildThemeData(appBarColor, cardBackgroundColor);
      });
    }
  }

  void refreshTheme() {
    _loadThemeColors();
  }

  static ThemeData _buildThemeData(
      Color appBarColor, Color cardBackgroundColor) {
    final Brightness appBarBrightness =
        ThemeData.estimateBrightnessForColor(appBarColor);
    final Color appBarForegroundColor =
        appBarBrightness == Brightness.dark ? Colors.white : Colors.black87;

    // 确定整体色彩方案的亮度，主要基于 AppBar 颜色，但确保背景是浅色的
    // 如果我们强制 scaffoldBackgroundColor 为白色，那么 ColorScheme 的 brightness 应该是 Brightness.light
    final Brightness overallBrightness = Brightness.light; // 因为背景是白色

    // 定义深色文本，用于浅色背景
    const Color darkTextColor = Colors.black87;
    const Color lightTextColor = Colors.white; // 用于深色背景

    return ThemeData(
      useMaterial3: true,
      brightness: overallBrightness, // <--- 设定整体主题亮度
      scaffoldBackgroundColor: const Color(0xFFF7F4EF),
      colorScheme: ColorScheme.fromSeed(
        seedColor: appBarColor,
        brightness: overallBrightness, // 确保 ColorScheme 与整体亮度一致
        // --- 明确定义 ColorScheme 中的前景颜色 ---
        // 如果背景是亮的 (我们这里是白色)，那么 onBackground, onSurface 应该是深色
        onBackground: darkTextColor,
        onSurface: darkTextColor,
        // primary 和 secondary 的 onColor 会由 fromSeed 根据 seedColor 亮度自动生成
        // 但如果appBarColor本身很浅，onPrimary 可能也是深色
      ).copyWith(
          // 如果需要，可以进一步覆盖 fromSeed 生成的颜色
          // primary: appBarColor, // seedColor 已经做了这个
          // surface: Colors.white, // 如果希望所有表面都是白色（卡片除外）
          // background: Colors.white, // 已由 scaffoldBackgroundColor 覆盖
          ),
      appBarTheme: AppBarTheme(
        backgroundColor: appBarColor,
        foregroundColor: appBarForegroundColor, // 已根据appBarColor亮度计算
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: appBarForegroundColor,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(
          color: appBarForegroundColor,
        ),
      ),
      cardTheme: CardTheme(
        color: cardBackgroundColor,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.04),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.9),
        hintStyle: TextStyle(color: Colors.black.withValues(alpha: 0.42)),
        prefixIconColor: Colors.black.withValues(alpha: 0.42),
        labelStyle: TextStyle(color: darkTextColor.withValues(alpha: 0.7)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: appBarForegroundColor.withValues(alpha: 0.22),
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 13.0, horizontal: 14.0),
      ),
      // --- 定义全局 TextTheme ---
      textTheme: TextTheme(
        // --- Body ---
        bodyLarge: TextStyle(color: darkTextColor, fontSize: 18), // 较大的正文
        bodyMedium: TextStyle(color: darkTextColor, fontSize: 16), // 默认正文
        bodySmall: TextStyle(
            color: darkTextColor.withValues(alpha: 0.75),
            fontSize: 14), // 较小的辅助文本

        // --- Headlines (如果笔记详情页的标题用这个) ---
        headlineSmall: TextStyle(
            color: darkTextColor, fontSize: 24, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(
            color: darkTextColor, fontSize: 28, fontWeight: FontWeight.bold),

        // --- Titles (例如 ListTile 的标题，或者自定义卡片中的标题) ---
        titleLarge: TextStyle(
            color: darkTextColor, fontSize: 22, fontWeight: FontWeight.w500),
        titleMedium: TextStyle(
            color: darkTextColor,
            fontSize: 18,
            fontWeight: FontWeight.w500), // NotesListScreen 空列表提示用的是这个
        titleSmall: TextStyle(
            color: darkTextColor, fontSize: 16, fontWeight: FontWeight.w400),

        // --- Labels (按钮文字等) ---
        labelLarge: TextStyle(
            color: appBarForegroundColor,
            fontSize: 16,
            fontWeight: FontWeight.w500), // 例如用在主要按钮上
        labelMedium: TextStyle(color: darkTextColor, fontSize: 14),
        labelSmall: TextStyle(
            color: darkTextColor.withValues(alpha: 0.7), fontSize: 12),
      ).apply(
        // 可以全局应用一些基本颜色，但上面更具体的 TextStyle 会覆盖它
        bodyColor: darkTextColor,
        displayColor: darkTextColor,
      ),
      // 你也可以为特定组件如 ElevatedButton, TextButton 设置样式
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
        foregroundColor: appBarBrightness == Brightness.dark
            ? lightTextColor
            : darkTextColor, // 按钮文字颜色
        backgroundColor: appBarColor, // 按钮背景颜色
      )),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
        foregroundColor: appBarColor, // TextButton 文字通常用主题强调色
      )),
      // 对于浮动操作按钮 (FAB)
      // floatingActionButtonTheme: FloatingActionButtonThemeData(
      //   backgroundColor: appBarColor,
      //   foregroundColor: appBarForegroundColor,
      // ),
      // 图标主题
      iconTheme: IconThemeData(
        color: darkTextColor.withValues(alpha: 0.8), // 默认图标颜色
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print(
        "Main: Building LunarixNotesApp with theme for AppBar: ${_currentTheme.appBarTheme.backgroundColor}, ScaffoldBG: ${_currentTheme.scaffoldBackgroundColor}");
    return MaterialApp(
      title: 'Lunarix Notes (翼亭笔记)',
      theme: _currentTheme,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: [
        FlutterQuillLocalizations.delegate,
      ],
      home: const NotesListScreen(),
    );
  }
}
