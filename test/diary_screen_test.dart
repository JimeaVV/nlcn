import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optifit/models/food_log_entry.dart';
import 'package:optifit/models/user_profile.dart';
import 'package:optifit/screens/diary_screen.dart';
import 'package:optifit/services/database_service.dart';
import 'package:optifit/services/dataset_repository.dart';
import 'package:optifit/widgets/food_log_sheet.dart';

import 'helpers/localized_app.dart';

const _oats = {
  'name': 'oats',
  'category': 'Grain',
  'macro_group': 'Starch',
  'calories_per_100g': 389.0,
  'protein_g': 16.9,
  'carb_g': 66.3,
  'fat_g': 6.9,
  'max_amount_g': 200.0,
  'suggested_prep': 'Boil',
};

class _Datasets extends DatasetRepository {
  @override
  Future<RecommendationData> load() async =>
      const RecommendationData(foods: [_oats], exercises: []);
}

class _Database extends Fake implements DatabaseService {
  Map<String, dynamic>? profile;
  final entries = <FoodLogEntry>[];
  var _nextId = 1;

  @override
  Future<Map<String, dynamic>?> getProfile() async => profile;

  @override
  Future<List<FoodLogEntry>> getFoodLog(DateTime day) async => [
        for (final entry in entries)
          if (diaryDateKey(entry.date) == diaryDateKey(day)) entry,
      ];

  @override
  Future<List<int>> addFoodLogEntries(List<FoodLogEntry> added) async {
    final ids = <int>[];
    for (final entry in added) {
      entry.validate();
      final id = _nextId++;
      ids.add(id);
      entries.add(FoodLogEntry.fromMap({...entry.toMap(), 'id': id}));
    }
    return ids;
  }

  @override
  Future<void> deleteFoodLogEntry(int id) async =>
      entries.removeWhere((entry) => entry.id == id);
}

Future<void> _mount(WidgetTester tester, _Database database) async {
  tester.view.physicalSize = const Size(400, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(localizedApp(
    home:
        Scaffold(body: DiaryScreen(database: database, datasets: _Datasets())),
  ));
  await tester.pumpAndSettle();
}

Future<void> _chooseMeal(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const ValueKey('diary-meal')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  test('dataset foods scale per 100 g and totals add every macro', () {
    final today = DateTime.now();
    final entry = FoodLogEntry.fromFood(_oats,
        grams: 50, date: today, meal: MealSlot.breakfast);
    expect(entry.calories, closeTo(194.5, 1e-9));
    expect(entry.protein, closeTo(8.45, 1e-9));
    final roundTrip = FoodLogEntry.fromMap({...entry.toMap(), 'id': 7});
    expect(roundTrip.id, 7);
    expect(roundTrip.grams, 50);
    expect(diaryDateKey(roundTrip.date), diaryDateKey(today));

    final totals = FoodLogTotals.of([
      entry,
      FoodLogEntry(
          date: today,
          meal: MealSlot.lunch,
          name: 'Cơm',
          calories: 200,
          protein: 4,
          carbs: 45,
          fat: 0.5),
    ]);
    expect(totals.calories, closeTo(394.5, 1e-9));
    expect(totals.carbs, closeTo(78.15, 1e-9));
  });

  test('validation rejects impossible portions, nutrition and confidence', () {
    FoodLogEntry entry({double? grams, double calories = 100, double? score}) =>
        FoodLogEntry(
          date: DateTime.now(),
          meal: MealSlot.snack,
          name: 'Test',
          grams: grams,
          calories: calories,
          protein: 1,
          confidence: score,
        );
    expect(entry(grams: 0).validate, throwsArgumentError);
    expect(entry(calories: -1).validate, throwsArgumentError);
    expect(entry(score: 1.5).validate, throwsArgumentError);
    entry(grams: 120, score: 0.9).validate();
  });

  test('meal slot defaults follow the time of day', () {
    expect(mealSlotFor(DateTime(2026, 1, 1, 7)), MealSlot.breakfast);
    expect(mealSlotFor(DateTime(2026, 1, 1, 12)), MealSlot.lunch);
    expect(mealSlotFor(DateTime(2026, 1, 1, 15)), MealSlot.snack);
    expect(mealSlotFor(DateTime(2026, 1, 1, 19)), MealSlot.dinner);
  });

  testWidgets('without a profile the diary still totals what was eaten',
      (tester) async {
    final database = _Database();
    await _mount(tester, database);
    expect(find.text('Hôm nay'), findsOneWidget);
    expect(find.text('0 kcal'), findsOneWidget);
    expect(find.text('Lưu hồ sơ để so với mục tiêu calo và protein.'),
        findsOneWidget);
    expect(find.text('Chưa ghi món nào.'), findsNWidgets(4));
  });

  testWidgets('a dataset food is added by weight and compared with targets',
      (tester) async {
    final database = _Database()
      ..profile = const UserProfile(
        age: 25,
        gender: 'male',
        height: 175,
        weight: 70,
        activityLevel: 1.55,
        calorieOverride: 2000,
        proteinOverride: 120,
      ).toMap();
    await _mount(tester, database);
    expect(find.text('0 / 2.000 kcal'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('diary-add')));
    await tester.pumpAndSettle();
    await _chooseMeal(tester, 'Bữa sáng');
    await tester.tap(find.byKey(const ValueKey('diary-save')));
    await tester.pumpAndSettle();
    expect(find.text('Chọn một thực phẩm trong danh sách.'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('diary-food')), 'oa');
    await tester.pumpAndSettle();
    await tester.tap(find.text('oats').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('diary-grams')), '40');
    await tester.pumpAndSettle();
    expect(find.text('Ước tính: 156 kcal • 6,8 g protein'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('diary-save')));
    await tester.pumpAndSettle();

    final saved = database.entries.single;
    expect(saved.meal, MealSlot.breakfast);
    expect(saved.source, FoodLogSource.manual);
    expect(find.text('156 / 2.000 kcal'), findsOneWidget);
    expect(find.text('Còn 1.844 kcal so với mục tiêu'), findsOneWidget);
    expect(find.text('40 g • 156 kcal • 6,8 g protein'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a custom dish is logged by calories and removal can be undone',
      (tester) async {
    final database = _Database();
    await _mount(tester, database);
    await tester.tap(find.byKey(const ValueKey('diary-add')));
    await tester.pumpAndSettle();
    await _chooseMeal(tester, 'Bữa trưa');
    await tester.tap(find.text('Tự nhập'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('diary-custom-name')), 'Phở bò');
    await tester.enterText(
        find.byKey(const ValueKey('diary-custom-calories')), '450');
    await tester.enterText(
        find.byKey(const ValueKey('diary-custom-protein')), '25');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('diary-save')));
    await tester.pumpAndSettle();

    expect(database.entries.single.name, 'Phở bò');
    expect(database.entries.single.grams, isNull);
    expect(find.text('450 kcal • 25,0 g protein'), findsOneWidget);

    await tester.tap(find.byTooltip('Xóa món'));
    await tester.pumpAndSettle();
    expect(database.entries, isEmpty);
    await tester.tap(find.text('Hoàn tác'));
    await tester.pumpAndSettle();
    expect(database.entries.single.name, 'Phở bò');
    expect(database.entries.single.meal, MealSlot.lunch);
    expect(tester.takeException(), isNull);
  });

  testWidgets('earlier days can be opened but not future ones', (tester) async {
    final database = _Database();
    final now = DateTime.now();
    await database.addFoodLogEntries([
      FoodLogEntry(
        date: DateTime(now.year, now.month, now.day - 1),
        meal: MealSlot.dinner,
        name: 'Bún chả',
        calories: 500,
        protein: 28,
      ),
    ]);
    await _mount(tester, database);
    expect(find.text('Bún chả'), findsNothing);
    final next = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_right_rounded));
    expect(next.onPressed, isNull);

    await tester.tap(find.byTooltip('Ngày trước'));
    await tester.pumpAndSettle();
    expect(find.text('Bún chả'), findsOneWidget);
    expect(find.text('Hôm nay'), findsNothing);
  });
}
