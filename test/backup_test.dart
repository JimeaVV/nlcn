import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:optifit/models/food_log_entry.dart';
import 'package:optifit/models/user_profile.dart';
import 'package:optifit/services/backup_service.dart';
import 'package:optifit/services/database_service.dart';

const _profile = UserProfile(
  age: 25,
  gender: 'female',
  height: 160,
  weight: 55,
  activityLevel: 1.375,
  goal: NutritionGoal.lose,
);

FoodLogEntry _food(String name, DateTime day, double calories) => FoodLogEntry(
    date: day,
    meal: MealSlot.lunch,
    name: name,
    calories: calories,
    protein: 10);

void main() {
  sqfliteFfiInit();
  final today = DateTime.now();
  final storages = <DatabaseService>[];

  DatabaseService open() {
    final storage = DatabaseService.forTesting(
        factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    storages.add(storage);
    return storage;
  }

  tearDown(() async {
    for (final storage in storages) {
      await storage.close();
    }
    storages.clear();
  });

  test('water is kept per day and clamped to 0–10 litres', () async {
    final storage = open();
    expect(await storage.getWater(today), 0);
    await storage.setWater(today, 750);
    await storage.setWater(today, 1250);
    expect(await storage.getWater(today), 1250);
    await storage.setWater(today, -5);
    expect(await storage.getWater(today), 0);
    await storage.setWater(today, 99999);
    expect(await storage.getWater(today), 10000);
  });

  test('daily totals add every macro per day', () async {
    final storage = open();
    await storage.addFoodLogEntries([
      _food('A', today, 500),
      _food('B', today, 300),
    ]);
    final days = await storage.getDailyTotals(today, today);
    final totals = days[DateTime(today.year, today.month, today.day)]!;
    expect(totals.calories, 800);
    expect(totals.protein, 20);
  });

  test('a backup restores every table into an empty database', () async {
    final source = open();
    await source.saveUserProfile(_profile);
    await source.addFoodLogEntries([_food('Cơm tấm', today, 600)]);
    await source.addFavoriteFood(_food('Cơm tấm', today, 600));
    await source.setWater(today, 1500);
    // Through bytes, as the file the user keeps.
    final file = utf8.encode(jsonEncode(await source.exportBackup()));
    final backup = BackupService.parse(file);
    expect(backup['schema'], DatabaseService.schemaVersion);

    final target = open();
    await target.addFoodLogEntries([_food('Will be replaced', today, 100)]);
    await target.restoreBackup(backup);
    expect(UserProfile.fromMap((await target.getProfile())!).goal,
        NutritionGoal.lose);
    expect([for (final food in await target.getFoodLog(today)) food.name],
        ['Cơm tấm']);
    expect((await target.getFavoriteFoods()).single.name, 'Cơm tấm');
    expect(await target.getWater(today), 1500);
    expect((await target.getWeightHistory()).single.weight, 55);
  });

  test('a file that is not a backup changes nothing', () async {
    final storage = open();
    await storage.addFoodLogEntries([_food('Kept', today, 100)]);
    for (final bad in <Map<String, dynamic>>[
      {'app': 'other', 'schema': 1, 'tables': {}},
      {'app': 'optifit', 'schema': 99, 'tables': {}},
      {
        'app': 'optifit',
        'schema': 6,
        'tables': {'secrets': []},
      },
      {
        'app': 'optifit',
        'schema': 6,
        'tables': {
          'food_log': [
            {'no_such_column': 1},
          ],
        },
      },
    ]) {
      await expectLater(storage.restoreBackup(bad), throwsA(anything));
    }
    expect([for (final food in await storage.getFoodLog(today)) food.name],
        ['Kept']);
    expect(() => BackupService.parse(utf8.encode('[1, 2]')),
        throwsFormatException);
  });

  test('a backup from before water and favorites still restores', () async {
    final storage = open();
    await storage.restoreBackup({
      'app': 'optifit',
      'schema': 4,
      'tables': {
        'food_log': [
          {
            'logged_date': diaryDateKey(today),
            'meal': 'lunch',
            'food_name': 'Bún chả',
            'calories': 550.0,
            'protein': 25.0,
            'carbs': 60.0,
            'fat': 20.0,
            'source': 'manual',
            'created_at': today.toIso8601String(),
          },
        ],
      },
    });
    expect((await storage.getFoodLog(today)).single.name, 'Bún chả');
    expect(await storage.getFavoriteFoods(), isEmpty);
  });

  test('backup files are named by date', () {
    expect(BackupService.fileName(DateTime(2026, 10, 21)),
        'optifit_backup_2026-10-21.json');
  });
}
