// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'features/note_list/views/notes_list_screen.dart';
import 'core/services/settings_service.dart';
import 'core/theme/app_theme.dart';

const Color _initialAppBarColor = Color(0xFF315B66);
const Color _initialCardBackgroundColor = Color(0xFFFFFFFF);

GlobalKey<LunarixNotesAppState> lunarixAppKey = GlobalKey();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(LunarixNotesApp(key: lunarixAppKey));
}

class LunarixNotesApp extends StatefulWidget {
  const LunarixNotesApp({super.key});

  @override
  State<LunarixNotesApp> createState() => LunarixNotesAppState();
}

class LunarixNotesAppState extends State<LunarixNotesApp> {
  final SettingsService _settingsService = SettingsService();
  ThemeData _currentTheme =
      _buildThemeData(_initialAppBarColor, _initialCardBackgroundColor);

  @override
  void initState() {
    super.initState();
    _loadThemeColors();
  }

  Future<void> _loadThemeColors() async {
    Color appBarColor = await _settingsService.getAppBarColor();
    Color cardBackgroundColor = await _settingsService.getCardBackgroundColor();
    if (mounted) {
      setState(() {
        _currentTheme = _buildThemeData(appBarColor, cardBackgroundColor);
      });
    }
  }

  void refreshTheme() {
    _loadThemeColors();
  }

  static ThemeData _buildThemeData(Color accent, Color cardColor) =>
      AppTheme.build(accent: accent, cardColor: cardColor);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '翼亭笔记',
      theme: _currentTheme,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: [
        FlutterQuillLocalizations.delegate,
      ],
      home: const NotesListScreen(),
    );
  }
}
