import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optifit/core/cyber_theme.dart';
import 'package:optifit/core/locale_controller.dart';
import 'package:optifit/l10n/app_localizations.dart';
import 'package:optifit/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(ThemeController theme, LocaleController locale) =>
    ListenableBuilder(
      listenable: locale,
      builder: (context, _) => MaterialApp(
        locale: locale.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: SettingsScreen(
            themeController: theme,
            localeController: locale,
          ),
        ),
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults to Vietnamese and restores the saved language', () async {
    final first = LocaleController();
    await first.load();
    expect(first.language, AppLanguage.vi);

    await first.setLanguage(AppLanguage.en);
    final restored = LocaleController();
    await restored.load();
    expect(restored.locale, const Locale('en'));
  });

  testWidgets('switching language in Settings translates the interface',
      (tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final theme = ThemeController();
    final locale = LocaleController();
    await locale.load();
    await tester.pumpWidget(_app(theme, locale));

    expect(find.text('CÀI ĐẶT'), findsOneWidget);
    expect(find.text('Ngôn ngữ'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('language-en')));
    await tester.pumpAndSettle();
    expect(find.text('SETTINGS'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(locale.language, AppLanguage.en);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('selected_app_language'), 'en');

    await tester.tap(find.byKey(const ValueKey('language-vi')));
    await tester.pumpAndSettle();
    expect(find.text('CÀI ĐẶT'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
