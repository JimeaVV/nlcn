import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppStyle { cyberpunk, minimalLight, forest, sunset }

/// Style names are proper names; descriptions are localized in Settings.
class AppStyleInfo {
  const AppStyleInfo({
    required this.style,
    required this.name,
    required this.icon,
  });

  final AppStyle style;
  final String name;
  final IconData icon;
}

const appStyleOptions = <AppStyleInfo>[
  AppStyleInfo(
    style: AppStyle.cyberpunk,
    name: 'Cyberpunk',
    icon: Icons.bolt_rounded,
  ),
  AppStyleInfo(
    style: AppStyle.minimalLight,
    name: 'Minimal Light',
    icon: Icons.light_mode_rounded,
  ),
  AppStyleInfo(
    style: AppStyle.forest,
    name: 'Forest',
    icon: Icons.forest_rounded,
  ),
  AppStyleInfo(
    style: AppStyle.sunset,
    name: 'Sunset',
    icon: Icons.wb_twilight_rounded,
  ),
];

class AppPalette {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.primary,
    required this.secondary,
    required this.highlight,
    required this.text,
    required this.muted,
    required this.danger,
    required this.border,
    required this.brightness,
  });

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color primary;
  final Color secondary;
  final Color highlight;
  final Color text;
  final Color muted;
  final Color danger;
  final Color border;
  final Brightness brightness;
}

class CyberColors {
  static AppPalette _palette = AppTheme.paletteFor(AppStyle.cyberpunk);

  static void apply(AppStyle style) {
    _palette = AppTheme.paletteFor(style);
  }

  static Color get background => _palette.background;
  static Color get surface => _palette.surface;
  static Color get surfaceAlt => _palette.surfaceAlt;
  static Color get cyan => _palette.primary;
  static Color get magenta => _palette.secondary;
  static Color get lime => _palette.highlight;
  static Color get text => _palette.text;
  static Color get muted => _palette.muted;
  static Color get danger => _palette.danger;
  static Color get border => _palette.border;
}

class AppTheme {
  static AppPalette paletteFor(AppStyle style) {
    return switch (style) {
      AppStyle.cyberpunk => const AppPalette(
          background: Color(0xFF070A12),
          surface: Color(0xFF101626),
          surfaceAlt: Color(0xFF151D30),
          primary: Color(0xFF00F5FF),
          secondary: Color(0xFFFF2BD6),
          highlight: Color(0xFFB7FF00),
          text: Color(0xFFF3F7FF),
          muted: Color(0xFFA8B3C7),
          danger: Color(0xFFFF5370),
          border: Color(0xFF273653),
          brightness: Brightness.dark,
        ),
      AppStyle.minimalLight => const AppPalette(
          background: Color(0xFFF5F7FA),
          surface: Color(0xFFFFFFFF),
          surfaceAlt: Color(0xFFF0F3F8),
          primary: Color(0xFF1769E0),
          secondary: Color(0xFF6C4DFF),
          highlight: Color(0xFF138A5B),
          text: Color(0xFF172033),
          muted: Color(0xFF667085),
          danger: Color(0xFFD92D20),
          border: Color(0xFFD5DCE8),
          brightness: Brightness.light,
        ),
      AppStyle.forest => const AppPalette(
          background: Color(0xFF07130F),
          surface: Color(0xFF10231C),
          surfaceAlt: Color(0xFF183229),
          primary: Color(0xFF4ADE80),
          secondary: Color(0xFF2DD4BF),
          highlight: Color(0xFFFACC15),
          text: Color(0xFFF0FFF7),
          muted: Color(0xFFA7C5B5),
          danger: Color(0xFFFB7185),
          border: Color(0xFF315748),
          brightness: Brightness.dark,
        ),
      AppStyle.sunset => const AppPalette(
          background: Color(0xFF160C18),
          surface: Color(0xFF28152E),
          surfaceAlt: Color(0xFF38203F),
          primary: Color(0xFFFF8A3D),
          secondary: Color(0xFFB46CFF),
          highlight: Color(0xFFFFD166),
          text: Color(0xFFFFF6F0),
          muted: Color(0xFFD4B7CF),
          danger: Color(0xFFFF5D73),
          border: Color(0xFF654366),
          brightness: Brightness.dark,
        ),
    };
  }

  static ThemeData build(AppStyle style) {
    final p = paletteFor(style);
    CyberColors.apply(style);

    final scheme = ColorScheme.fromSeed(
      seedColor: p.primary,
      brightness: p.brightness,
      surface: p.surface,
    ).copyWith(
      primary: p.primary,
      secondary: p.secondary,
      surface: p.surface,
      error: p.danger,
      onSurface: p.text,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      scaffoldBackgroundColor: p.background,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.text,
        surfaceTintColor: Colors.transparent,
      ),
      textTheme: TextTheme(
        headlineSmall: TextStyle(
          color: p.text,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
        titleLarge: TextStyle(color: p.text, fontWeight: FontWeight.w800),
        titleMedium: TextStyle(color: p.text, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(color: p.text),
        bodyMedium: TextStyle(color: p.muted),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceAlt,
        labelStyle: TextStyle(color: p.muted),
        hintStyle: TextStyle(color: p.muted.withValues(alpha: 0.7)),
        prefixIconColor: p.primary,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.danger, width: 1.4),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        indicatorColor: p.primary.withValues(alpha: 0.18),
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      cardTheme: CardThemeData(color: p.surface),
      dividerColor: p.border,
    );
  }
}

class ThemeController extends ChangeNotifier {
  static const _storageKey = 'selected_app_style';

  AppStyle _style = AppStyle.cyberpunk;
  AppStyle get style => _style;
  ThemeData get theme => AppTheme.build(_style);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_storageKey);
    _style = AppStyle.values.firstWhere(
      (style) => style.name == saved,
      orElse: () => AppStyle.cyberpunk,
    );
    CyberColors.apply(_style);
    notifyListeners();
  }

  Future<void> setStyle(AppStyle value) async {
    if (_style == value) return;
    _style = value;
    CyberColors.apply(value);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, value.name);
  }
}
