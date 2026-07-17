import 'package:flutter/material.dart';

class CyberColors {
  static const background = Color(0xFF070A12);
  static const surface = Color(0xFF101626);
  static const surfaceAlt = Color(0xFF151D30);
  static const cyan = Color(0xFF00F5FF);
  static const magenta = Color(0xFFFF2BD6);
  static const lime = Color(0xFFB7FF00);
  static const text = Color(0xFFF3F7FF);
  static const muted = Color(0xFFA8B3C7);
  static const danger = Color(0xFFFF5370);
}

class CyberTheme {
  static ThemeData get darkTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: CyberColors.cyan,
      brightness: Brightness.dark,
      surface: CyberColors.surface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: CyberColors.background,
      colorScheme: scheme.copyWith(
        primary: CyberColors.cyan,
        secondary: CyberColors.magenta,
        surface: CyberColors.surface,
        error: CyberColors.danger,
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          color: CyberColors.text,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
        titleLarge: TextStyle(
          color: CyberColors.text,
          fontWeight: FontWeight.w800,
        ),
        titleMedium: TextStyle(
          color: CyberColors.text,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(color: CyberColors.text),
        bodyMedium: TextStyle(color: CyberColors.muted),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CyberColors.surfaceAlt,
        labelStyle: const TextStyle(color: CyberColors.muted),
        hintStyle: const TextStyle(color: Color(0xFF71809A)),
        prefixIconColor: CyberColors.cyan,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF273653)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: CyberColors.cyan, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: CyberColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: CyberColors.danger, width: 1.4),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: CyberColors.surface,
        indicatorColor: Color(0x3300F5FF),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
