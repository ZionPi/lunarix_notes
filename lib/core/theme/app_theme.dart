import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  static ThemeData build({
    Color accent = const Color(0xFF32695D),
    Color cardColor = Colors.white,
  }) {
    const ink = Color(0xFF25332E);
    const paper = Color(0xFFF7F8F5);
    final scheme = ColorScheme.fromSeed(seedColor: accent).copyWith(
      surface: Colors.white,
      onSurface: ink,
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: paper,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 19,
          fontWeight: FontWeight.w600,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: paper,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      ),
      cardTheme: CardThemeData(
        color:
            Color.alphaBlend(cardColor.withValues(alpha: 0.05), Colors.white),
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE9EDE7)),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFEEF1EB),
        hintStyle: const TextStyle(color: Color(0xFF8A958D), fontSize: 15),
        prefixIconColor: const Color(0xFF7A887F),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: scheme.primary.withValues(alpha: 0.35)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: ink,
            letterSpacing: -1),
        headlineSmall: TextStyle(
            fontSize: 25, height: 1.4, fontWeight: FontWeight.w600, color: ink),
        titleLarge:
            TextStyle(fontSize: 21, fontWeight: FontWeight.w600, color: ink),
        titleMedium:
            TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ink),
        titleSmall:
            TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ink),
        bodyLarge: TextStyle(fontSize: 17, height: 1.65, color: ink),
        bodyMedium: TextStyle(fontSize: 15, height: 1.6, color: ink),
        bodySmall:
            TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF7B887F)),
      ),
      dividerTheme:
          const DividerThemeData(color: Color(0xFFE9EDE7), thickness: 1),
      iconTheme: const IconThemeData(color: Color(0xFF65776D), size: 22),
      listTileTheme: ListTileThemeData(
        iconColor: const Color(0xFF65776D),
        titleTextStyle: const TextStyle(
            color: ink, fontSize: 15, fontWeight: FontWeight.w400, height: 1.4),
        subtitleTextStyle: const TextStyle(
            color: Color(0xFF7B887F), fontSize: 12, height: 1.5),
        minLeadingWidth: 20,
        horizontalTitleGap: 12,
        minVerticalPadding: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        textStyle: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w400, color: ink),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFEDF0EB))),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 3,
        thumbShape:
            const RoundSliderThumbShape(enabledThumbRadius: 7, elevation: 1),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
        inactiveTrackColor: const Color(0xFFE3E8E2),
        activeTrackColor: scheme.primary,
        thumbColor: scheme.primary,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
          style: SegmentedButton.styleFrom(
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        selectedBackgroundColor: scheme.primary.withValues(alpha: 0.09),
        selectedForegroundColor: scheme.primary,
        side: const BorderSide(color: Color(0xFFE3E8E2)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      )),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
        minimumSize: const Size(72, 42),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        side: const BorderSide(color: Color(0xFFDAE2DA)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      )),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(72, 42),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        extendedTextStyle:
            const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.w600, color: ink),
        contentTextStyle: const TextStyle(
            fontSize: 14, height: 1.6, color: Color(0xFF65776D)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
