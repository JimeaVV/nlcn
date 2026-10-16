import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Interface languages offered in Settings. Vietnamese is the default.
enum AppLanguage { vi, en }

extension AppLanguageLocale on AppLanguage {
  Locale get locale => Locale(name);

  /// Each language is named in itself, so it stays recognizable after a switch.
  String get nativeName => switch (this) {
        AppLanguage.vi => 'Tiếng Việt',
        AppLanguage.en => 'English',
      };
}

class LocaleController extends ChangeNotifier {
  static const _storageKey = 'selected_app_language';

  AppLanguage _language = AppLanguage.vi;
  AppLanguage get language => _language;
  Locale get locale => _language.locale;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_storageKey);
    _language = AppLanguage.values.firstWhere(
      (language) => language.name == saved,
      orElse: () => AppLanguage.vi,
    );
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage value) async {
    if (_language == value) return;
    _language = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, value.name);
  }
}
