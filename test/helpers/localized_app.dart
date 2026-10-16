import 'package:flutter/material.dart';
import 'package:optifit/l10n/app_localizations.dart';

/// A MaterialApp with the app's localizations, Vietnamese unless [locale] says
/// otherwise, so screens can call `context.l10n`.
Widget localizedApp({
  required Widget home,
  ThemeData? theme,
  Locale locale = const Locale('vi'),
}) =>
    MaterialApp(
      theme: theme,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    );
