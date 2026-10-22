import 'package:flutter/material.dart';

import 'core/cyber_theme.dart';
import 'core/locale_controller.dart';
import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';
import 'services/photo_collector.dart';
import 'services/reminder_service.dart';
import 'services/water_reminder_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeController = ThemeController();
  final localeController = LocaleController();
  final reminders = ReminderController();
  final waterReminders = WaterReminderController();
  await Future.wait([
    themeController.load(),
    localeController.load(),
    reminders.load(),
    waterReminders.load(),
    PhotoCollector.instance.load(),
  ]);
  runApp(OptiFitApp(
    themeController: themeController,
    localeController: localeController,
    reminders: reminders,
    waterReminders: waterReminders,
  ));
}

class OptiFitApp extends StatelessWidget {
  const OptiFitApp({
    super.key,
    required this.themeController,
    required this.localeController,
    this.reminders,
    this.waterReminders,
  });

  final ThemeController themeController;
  final LocaleController localeController;
  final ReminderController? reminders;
  final WaterReminderController? waterReminders;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([themeController, localeController]),
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'MacroRunner',
          theme: themeController.theme,
          locale: localeController.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: HomeScreen(
            themeController: themeController,
            localeController: localeController,
            reminders: reminders,
            waterReminders: waterReminders,
          ),
        );
      },
    );
  }
}
