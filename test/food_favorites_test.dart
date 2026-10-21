import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:optifit/models/food_log_entry.dart';
import 'package:optifit/services/database_service.dart';

FoodLogEntry _food(String name, DateTime day,
        {double calories = 100, double? grams, MealSlot? meal}) =>
    FoodLogEntry(
      date: day,
      meal: meal ?? MealSlot.lunch,
      name: name,
      grams: grams,
      calories: calories,
      protein: 5,
      carbs: 10,
      fat: 2,
    );

void main() {
  sqfliteFfiInit();
  late DatabaseService storage;

  setUp(() => storage = DatabaseService.forTesting(
      factory: databaseFactoryFfi, path: inMemoryDatabasePath));
  tearDown(() => storage.close());

  final today = DateTime.now();
  final yesterday = DateTime(today.year, today.month, today.day - 1);

  test('recent foods keep the newest entry of each name, newest first',
      () async {
    await storage.addFoodLogEntries([
      _food('Cơm tấm', yesterday, calories: 600, grams: 350),
      _food('Phở bò', yesterday, calories: 450),
      _food('Cơm tấm', today, calories: 640, grams: 380),
    ]);
    final recent = await storage.getRecentFoods();
    expect([for (final food in recent) food.name], ['Cơm tấm', 'Phở bò']);
    expect(recent.first.calories, 640);
    expect(recent.first.grams, 380);
    expect(await storage.getRecentFoods(limit: 1), hasLength(1));
  });

  test('a favorite is stored once per name and can be removed', () async {
    await storage.addFavoriteFood(_food('Bánh mì', today, calories: 300));
    await storage.addFavoriteFood(_food('Bánh mì', today, calories: 350));
    await storage.addFavoriteFood(_food('Sữa chua', today, calories: 90));
    var favorites = await storage.getFavoriteFoods();
    expect([for (final food in favorites) food.name], ['Bánh mì', 'Sữa chua']);
    expect(favorites.first.calories, 350);
    expect(favorites.first.id, isNull);

    await storage.removeFavoriteFood('Bánh mì');
    favorites = await storage.getFavoriteFoods();
    expect([for (final food in favorites) food.name], ['Sữa chua']);
  });

  test('a copied entry keeps the food and portion on its new day', () {
    final source = _food('Cơm tấm', yesterday,
        calories: 600, grams: 350, meal: MealSlot.dinner);
    final copy = source.copyTo(today, MealSlot.breakfast);
    expect(diaryDateKey(copy.date), diaryDateKey(today));
    expect(copy.meal, MealSlot.breakfast);
    expect(copy.grams, 350);
    expect(copy.calories, 600);
    expect(copy.id, isNull);
    expect(copy.source, FoodLogSource.manual);
  });

  test('daily calories add up each day in the range', () async {
    final older = DateTime(today.year, today.month, today.day - 10);
    await storage.addFoodLogEntries([
      _food('A', yesterday, calories: 500),
      _food('B', yesterday, calories: 700),
      _food('C', today, calories: 300),
      _food('D', older, calories: 999),
    ]);
    final days = await storage.getDailyCalories(
        DateTime(today.year, today.month, today.day - 3), today);
    expect(days, {
      DateTime(yesterday.year, yesterday.month, yesterday.day): 1200,
      DateTime(today.year, today.month, today.day): 300,
    });
  });
}
