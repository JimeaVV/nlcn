// Renders the main screens to PNG with the app's real fonts, so the layout
// can be looked at without a phone (see .claude/skills/ui-screenshots).
//
//   flutter test tool/ui_screenshots --update-goldens
//
// Images land in tool/ui_screenshots/out/ (not committed). Not part of the
// normal test run: `flutter test` only reads test/. A layout overflow fails
// the screen it happens on and names the widget.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optifit/core/cyber_theme.dart';
import 'package:optifit/core/locale_controller.dart';
import 'package:optifit/l10n/app_localizations.dart';
import 'package:optifit/models/food_log_entry.dart';
import 'package:optifit/models/history_models.dart';
import 'package:optifit/models/user_profile.dart';
import 'package:optifit/models/weight_entry.dart';
import 'package:optifit/screens/diary_screen.dart';
import 'package:optifit/screens/profile_screen.dart';
import 'package:optifit/screens/settings_screen.dart';
import 'package:optifit/screens/today_screen.dart';
import 'package:optifit/services/database_service.dart';
import 'package:optifit/services/dataset_repository.dart';
import 'package:optifit/services/reminder_service.dart';
import 'package:optifit/services/water_reminder_service.dart';
import 'package:optifit/models/food_variant.dart';
import 'package:optifit/widgets/intake_summary.dart';
import 'package:optifit/widgets/variant_picker_sheet.dart';

/// A day of made-up but typical data: two meals, some water, three weigh-ins.
class _Database extends Fake implements DatabaseService {
  _Database() {
    final now = DateTime.now();
    food = [
      FoodLogEntry(
          id: 1,
          date: now,
          meal: MealSlot.breakfast,
          name: 'Cơm (Cơm tấm)',
          grams: 225,
          calories: 290,
          protein: 6,
          carbs: 63,
          fat: 0.6),
      FoodLogEntry(
          id: 2,
          date: now,
          meal: MealSlot.breakfast,
          name: 'Sườn nướng (Cơm tấm)',
          grams: 90,
          calories: 188,
          protein: 23,
          fat: 10),
      FoodLogEntry(
          id: 3,
          date: now,
          meal: MealSlot.lunch,
          name: 'Ức gà',
          grams: 150,
          calories: 248,
          protein: 46.5,
          fat: 5.4),
    ];
    weights = [
      WeightEntry(id: 3, weight: 69.6, recordedAt: now),
      WeightEntry(
          id: 2, weight: 70, recordedAt: now.subtract(const Duration(days: 4))),
      WeightEntry(
          id: 1,
          weight: 70.4,
          recordedAt: now.subtract(const Duration(days: 9))),
    ];
  }

  late List<FoodLogEntry> food;
  late List<WeightEntry> weights;

  @override
  Future<Map<String, dynamic>?> getProfile() async => const UserProfile(
        age: 25,
        gender: 'male',
        height: 175,
        weight: 69.6,
        activityLevel: 1.55,
      ).toMap();

  @override
  Future<List<FoodLogEntry>> getFoodLog(DateTime day) async => [
        for (final entry in food)
          if (diaryDateKey(entry.date) == diaryDateKey(day)) entry,
      ];

  @override
  Future<Map<DateTime, FoodLogTotals>> getDailyTotals(
          DateTime from, DateTime to) async =>
      {
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day):
            FoodLogTotals.of(food),
      };

  @override
  Future<Map<DateTime, double>> getDailyCalories(
          DateTime from, DateTime to) async =>
      const {};

  @override
  Future<List<FoodLogEntry>> getFavoriteFoods() async => [food.last];

  @override
  Future<List<FoodLogEntry>> getRecentFoods({int limit = 8}) async =>
      food.reversed.take(limit).toList();

  @override
  Future<int> getWater(DateTime day) async => 750;

  @override
  Future<List<WeightEntry>> getWeightHistory({int limit = 90}) async =>
      weights.take(limit).toList();

  @override
  Future<List<WorkoutLogEntry>> getWorkoutLogs() async => const [];

  @override
  Future<List<WorkoutHistoryEntry>> getWorkoutHistory() async => const [];

  @override
  Future<List<MealHistoryEntry>> getMealHistory() async => const [];
}

class _Datasets extends DatasetRepository {
  @override
  Future<RecommendationData> load() async =>
      const RecommendationData(foods: [], exercises: []);
}

/// Be Vietnam Pro from the app's assets and Material icons from the SDK:
/// without them the test font draws every glyph as a box.
Future<void> _loadFonts() async {
  final family = FontLoader('BeVietnamPro');
  for (final weight in [
    'Regular',
    'Medium',
    'SemiBold',
    'Bold',
    'ExtraBold',
    'Black'
  ]) {
    family.addFont(
        rootBundle.load('assets/fonts/BeVietnamPro/BeVietnamPro-$weight.ttf'));
  }
  await family.load();
  final sdk = Platform.environment['FLUTTER_ROOT'];
  final icons =
      File('$sdk/bin/cache/artifacts/material_fonts/materialicons-regular.otf');
  if (sdk != null && icons.existsSync()) {
    await (FontLoader('MaterialIcons')
          ..addFont(
              Future.value(ByteData.sublistView(icons.readAsBytesSync()))))
        .load();
  }
}

/// The screens, each with the view height it needs to show everything.
const _gaugeTargets = {'target_calories': 2559.0, 'protein_target': 120.6};

/// The gauge alone at the fills a short day never reaches: nearly full (the
/// end of the arc, past 360°) and over the target.
Widget _gauges() => ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        IntakeSummary(totals: FoodLogTotals(), targets: _gaugeTargets),
        SizedBox(height: 24),
        IntakeSummary(
            totals: FoodLogTotals(
                calories: 2400, carbs: 250, protein: 125, fat: 85),
            targets: _gaugeTargets),
        SizedBox(height: 24),
        IntakeSummary(
            totals: FoodLogTotals(
                calories: 2311, carbs: 220, protein: 141, fat: 92),
            targets: _gaugeTargets),
        SizedBox(height: 24),
        IntakeSummary(
            totals: FoodLogTotals(
                calories: 2900, carbs: 300, protein: 150, fat: 110),
            targets: _gaugeTargets),
      ],
    );

/// The part and cooking picker for chicken, as it opens from the diary.
Widget _picker() {
  final variants = parseFoodVariants(
      File('assets/data/vn_food/food_variants.csv').readAsStringSync());
  return VariantPickerSheet(
      options: variants.inGroup('ga'),
      initial: variants.find('ga', 'uc|bo_da|luoc')!);
}

final _screens = <String, (double, Widget Function())>{
  'gauge': (1900, _gauges),
  'picker': (700, _picker),
  'today': (1250, () => TodayScreen(database: _Database())),
  'diary': (
    1150,
    () => DiaryScreen(database: _Database(), datasets: _Datasets())
  ),
  'profile': (2900, () => ProfileScreen(database: _Database())),
  'settings': (
    2200,
    () => SettingsScreen(
          themeController: ThemeController(),
          localeController: LocaleController(),
          reminders: ReminderController(),
          waterReminders: WaterReminderController(),
          database: _Database(),
        )
  ),
};

Future<void> _render(WidgetTester tester, Widget screen,
    {required AppStyle style,
    required double width,
    required double height,
    double textScale = 1}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  CyberColors.apply(style);
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.build(style),
    locale: const Locale('vi'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(body: screen),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(_loadFonts);

  for (final MapEntry(key: name, value: (height, build)) in _screens.entries) {
    for (final style in AppStyle.values) {
      testWidgets('$name in ${style.name}', (tester) async {
        await _render(tester, build(),
            style: style, width: 412, height: height);
        await expectLater(find.byType(MaterialApp),
            matchesGoldenFile('out/${name}_${style.name}.png'));
      });
    }
    // A small phone with the system font enlarged: where overflows show.
    testWidgets('$name at 360 px, text ×1.3', (tester) async {
      await _render(tester, build(),
          style: AppStyle.cyberpunk,
          width: 360,
          height: height * 1.4,
          textScale: 1.3);
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('out/${name}_small_large_text.png'));
    });
  }
}
