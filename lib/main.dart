import 'package:flutter/material.dart';

import 'core/cyber_theme.dart';
import 'core/locale_controller.dart';
import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeController = ThemeController();
  final localeController = LocaleController();
  await Future.wait([themeController.load(), localeController.load()]);
  runApp(OptiFitApp(
    themeController: themeController,
    localeController: localeController,
  ));
}

class OptiFitApp extends StatelessWidget {
  const OptiFitApp({
    super.key,
    required this.themeController,
    required this.localeController,
  });

  final ThemeController themeController;
  final LocaleController localeController;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([themeController, localeController]),
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'OptiFit',
          theme: themeController.theme,
          locale: localeController.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: HomeScreen(
            themeController: themeController,
            localeController: localeController,
          ),
        );
      },
    );
  }
}
