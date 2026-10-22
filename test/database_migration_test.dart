import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:optifit/models/food_log_entry.dart';
import 'package:optifit/models/user_profile.dart';
import 'package:optifit/services/database_service.dart';

const _legacyTimestamp = '2024-05-17T10:30:00.000';
const _legacyProfile = {
  'id': 1,
  'age': 25,
  'gender': 'male',
  'height': 175.0,
  'weight': 70.0,
  'activity_level': 1.55,
  'updated_at': _legacyTimestamp,
};

UserProfile _profile({
  double weight = 70,
  NutritionGoal goal = NutritionGoal.maintain,
  double? calories,
  double? protein,
  int age = 25,
}) =>
    UserProfile(
      age: age,
      gender: 'male',
      height: 175,
      weight: weight,
      activityLevel: 1.55,
      goal: goal,
      calorieOverride: calories,
      proteinOverride: protein,
    );

Future<Map<String, List<Map<String, Object?>>>> _legacyFixture(
  String databasePath, {
  int version = 2,
  bool existingWeights = false,
}) async {
  final db = await databaseFactoryFfi.openDatabase(
    databasePath,
    options: OpenDatabaseOptions(
      version: version,
      onCreate: (db, _) async {
        await db.execute('''
          create table user_profile(
            id integer primary key, age integer not null,
            gender text not null, height real not null, weight real not null,
            activity_level real not null, updated_at text not null
          )
        ''');
        await db.execute('''
          create table meal_plan_history(
            id integer primary key autoincrement,
            target_calories real not null, protein_target real not null,
            total_calories real not null, total_protein real not null,
            total_carb real not null, total_fat real not null,
            plan_json text not null, created_at text not null
          )
        ''');
        await db.execute('''
          create table workout_plan_history(
            id integer primary key autoincrement,
            split text not null, level text not null,
            target_time integer not null, estimated_time integer not null,
            exercises_json text not null, created_at text not null
          )
        ''');
        if (version >= 2) {
          await db.execute('''
            create table workout_logs(
              id integer primary key autoincrement,
              exercise_name text not null, weight_kg real not null,
              set_1_reps integer not null, set_2_reps integer not null,
              set_3_reps integer not null, difficulty text not null,
              suggested_weight real not null, suggested_reps integer not null,
              action text not null, suggestion_message text not null,
              performed_at text not null
            )
          ''');
        }
        if (existingWeights) {
          await db.execute('''
            create table weight_history(
              id integer primary key autoincrement,
              recorded_date text unique not null,
              weight_kg real not null, updated_at text not null
            )
          ''');
          await db.insert('weight_history', {
            'recorded_date': '2024-05-17',
            'weight_kg': 64.0,
            'updated_at': _legacyTimestamp,
          });
        }
        await db.insert('user_profile', _legacyProfile);
        await db.insert('meal_plan_history', {
          'target_calories': 2125.0,
          'protein_target': 126.0,
          'total_calories': 2100.0,
          'total_protein': 130.0,
          'total_carb': 220.0,
          'total_fat': 60.0,
          'plan_json': '{"legacy":"meal","data":{"kept":true}}',
          'created_at': _legacyTimestamp,
        });
        await db.insert('workout_plan_history', {
          'split': 'Push',
          'level': 'Beginner',
          'target_time': 45,
          'estimated_time': 40,
          'exercises_json': '{"legacy":"workout","data":[{"kept":true}]}',
          'created_at': _legacyTimestamp,
        });
        if (version >= 2) {
          await db.insert('workout_logs', {
            'exercise_name': 'Bench Press',
            'weight_kg': 50.0,
            'set_1_reps': 12,
            'set_2_reps': 12,
            'set_3_reps': 12,
            'difficulty': 'Moderate',
            'suggested_weight': 52.5,
            'suggested_reps': 8,
            'action': 'increase_weight',
            'suggestion_message': 'Keep original log.',
            'performed_at': _legacyTimestamp,
          });
        }
      },
    ),
  );
  final snapshot = <String, List<Map<String, Object?>>>{};
  for (final table in [
    'user_profile',
    'meal_plan_history',
    'workout_plan_history',
    if (version >= 2) 'workout_logs',
    if (existingWeights) 'weight_history',
  ]) {
    snapshot[table] = await db.query(table);
  }
  await db.close();
  return snapshot;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  late String databasePath;
  DatabaseService? service;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('optifit-db-test-');
    databasePath = path.join(directory.path, 'optifit.db');
  });

  tearDown(() async {
    await service?.close();
    service = null;
    await directory.delete(recursive: true);
  });

  DatabaseService openService([String? overridePath]) =>
      service = DatabaseService.forTesting(
        factory: databaseFactoryFfi,
        path: overridePath ?? databasePath,
      );

  test('fresh v4 works in memory and shares one concurrent open', () async {
    final storage = openService(inMemoryDatabasePath);
    final handles = await Future.wait([storage.database, storage.database]);
    expect(identical(handles[0], handles[1]), isTrue);
    final db = handles.first;
    expect(await db.getVersion(), 6);
    final columns = await db.rawQuery('pragma table_info(user_profile)');
    final goalColumn = columns.singleWhere((row) => row['name'] == 'goal');
    expect(goalColumn['dflt_value'], "'maintain'");
    await db.insert('user_profile', _legacyProfile);
    final profile = (await storage.getProfile())!;
    expect(profile['goal'], 'maintain');
    expect(profile['calorie_override'], isNull);
    expect(profile['protein_override'], isNull);
    expect(await storage.getWeightHistory(), isEmpty);
    expect(await storage.getWorkoutLogs(), isEmpty);
    expect(await storage.getFoodLog(DateTime.now()), isEmpty);
  });

  test('upgrading to v4 adds an empty diary next to existing data', () async {
    await _legacyFixture(databasePath);
    final storage = openService();
    expect(await storage.getFoodLog(DateTime(2024, 5, 17)), isEmpty);
    expect(await storage.getMealHistory(), hasLength(1));
  });

  test('diary entries are stored per day and keep their nutrition snapshot',
      () async {
    final storage = openService(inMemoryDatabasePath);
    final today = DateTime.now();
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final ids = await storage.addFoodLogEntries([
      FoodLogEntry.fromFood(
        const {
          'name': 'oats',
          'calories_per_100g': 389.0,
          'protein_g': 16.9,
          'carb_g': 66.3,
          'fat_g': 6.9,
        },
        grams: 50,
        date: today,
        meal: MealSlot.breakfast,
      ),
      FoodLogEntry(
        date: today,
        meal: MealSlot.snack,
        name: 'Bánh mì',
        calories: 350,
        protein: 12,
        source: FoodLogSource.camera,
        confidence: 0.82,
      ),
      FoodLogEntry(
        date: yesterday,
        meal: MealSlot.dinner,
        name: 'Phở bò',
        calories: 450,
        protein: 25,
      ),
    ]);
    expect(ids, hasLength(3));

    final todayEntries = await storage.getFoodLog(today);
    expect(todayEntries.map((entry) => entry.name), ['oats', 'Bánh mì']);
    expect(todayEntries.first.calories, closeTo(194.5, 1e-9));
    expect(todayEntries.first.grams, 50);
    expect(todayEntries.last.grams, isNull);
    expect(todayEntries.last.source, FoodLogSource.camera);
    expect(todayEntries.last.confidence, 0.82);
    expect((await storage.getFoodLog(yesterday)).single.name, 'Phở bò');

    await storage.deleteFoodLogEntry(todayEntries.first.id!);
    expect((await storage.getFoodLog(today)).single.name, 'Bánh mì');
  });

  test('diary rejects invalid and future entries without partial writes',
      () async {
    final storage = openService(inMemoryDatabasePath);
    final today = DateTime.now();
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    FoodLogEntry entry({DateTime? date, double calories = 100}) => FoodLogEntry(
          date: date ?? today,
          meal: MealSlot.lunch,
          name: 'Cơm',
          calories: calories,
          protein: 3,
        );
    await expectLater(
      storage.addFoodLogEntries([entry(), entry(date: tomorrow)]),
      throwsArgumentError,
    );
    await expectLater(
      storage.addFoodLogEntries([entry(), entry(calories: double.nan)]),
      throwsArgumentError,
    );
    expect(await storage.getFoodLog(today), isEmpty);
  });

  test(
      'v2 migration preserves profile and every archive and seeds one baseline',
      () async {
    final before = await _legacyFixture(databasePath);
    final storage = openService();
    final db = await storage.database;
    expect(await db.getVersion(), 6);
    expect(await storage.getProfile(), {
      ...before['user_profile']!.single,
      'goal': 'lose',
      'calorie_override': null,
      'protein_override': null,
    });
    for (final table in [
      'meal_plan_history',
      'workout_plan_history',
      'workout_logs',
    ]) {
      expect(await db.query(table), before[table]);
    }
    final baseline = (await storage.getWeightHistory()).single;
    expect(baseline.weight, 70);
    expect(baseline.recordedAt, DateTime(2024, 5, 17));
    final rawBaseline = (await db.query('weight_history')).single;
    expect(rawBaseline['updated_at'], _legacyTimestamp);
    await storage.close();
    expect((await storage.getWeightHistory()).single.id, baseline.id);
    expect(await storage.getMealHistory(), hasLength(1));
    expect(await storage.getWorkoutHistory(), hasLength(1));
    expect(await storage.getWorkoutLogs(), hasLength(1));
  });

  test('v1 upgrades through logs, v3 and v4 without losing its old records',
      () async {
    final before = await _legacyFixture(databasePath, version: 1);
    final storage = openService();
    final db = await storage.database;
    expect(await db.getVersion(), 6);
    expect(await db.query('meal_plan_history'), before['meal_plan_history']);
    expect(
        await db.query('workout_plan_history'), before['workout_plan_history']);
    expect(await storage.getWorkoutLogs(), isEmpty);
    expect((await storage.getProfile())!['goal'], 'lose');
    expect(await storage.getWeightHistory(), hasLength(1));
  });

  test('migration never overwrites an existing baseline measurement', () async {
    final before = await _legacyFixture(databasePath, existingWeights: true);
    final storage = openService();
    expect(await (await storage.database).query('weight_history'),
        before['weight_history']);
    expect((await storage.getWeightHistory()).single.weight, 64);
    expect((await storage.getProfile())!['weight'], 70);
  });

  test(
      'same-day upsert keeps its id and legacy saves preserve nutrition fields',
      () async {
    final storage = openService();
    final morning = DateTime(2024, 5, 17, 8);
    await storage.saveUserProfile(
      _profile(goal: NutritionGoal.gain, calories: 2500, protein: 150),
      recordedAt: morning,
    );
    final first = (await storage.getWeightHistory()).single;
    await storage.saveWeight(weight: 72, recordedAt: DateTime(2024, 5, 17, 20));
    final replacement = (await storage.getWeightHistory()).single;
    expect(replacement.id, first.id);
    expect(replacement.weight, 72);
    expect((await storage.getProfile())!['weight'], 72);
    await storage.saveProfile(
      age: 26,
      gender: 'male',
      height: 176,
      weight: 73,
      activityLevel: 1.55,
      recordedAt: morning,
    );
    final legacySaved = (await storage.getProfile())!;
    expect(legacySaved['goal'], 'gain');
    expect(legacySaved['calorie_override'], 2500);
    expect(legacySaved['protein_override'], 150);
    expect(legacySaved['weight'], 73);
    expect((await storage.getWeightHistory()).single.id, first.id);

    await storage.saveUserProfile(
      _profile(weight: 73),
      recordedAt: morning,
    );
    final cleared = (await storage.getProfile())!;
    expect(cleared['goal'], 'maintain');
    expect(cleared['calorie_override'], isNull);
    expect(cleared['protein_override'], isNull);
  });

  test(
      'backdated saves and deletions synchronize the latest chronological weight',
      () async {
    final storage = openService();
    await storage.saveUserProfile(_profile(),
        recordedAt: DateTime(2024, 5, 20));
    await storage.saveWeight(weight: 69, recordedAt: DateTime(2024, 5, 19));
    expect((await storage.getProfile())!['weight'], 70);
    await storage.saveUserProfile(
      _profile(
          weight: 68, goal: NutritionGoal.gain, calories: 2400, protein: 140),
      recordedAt: DateTime(2024, 5, 18),
    );
    final entries = await storage.getWeightHistory();
    expect(entries.map((row) => row.weight), [70, 69, 68]);
    expect((await storage.getWeightHistory(limit: 1)).single.id, entries[0].id);
    expect((await storage.getProfile())!['weight'], 70);
    await storage.deleteWeightEntry(entries[0].id);
    var profile = (await storage.getProfile())!;
    expect(profile['weight'], 69);
    expect(profile['goal'], 'gain');
    expect(profile['calorie_override'], 2400);
    expect(profile['protein_override'], 140);
    await storage.deleteWeightEntry(entries[1].id);
    expect((await storage.getProfile())!['weight'], 68);
    await storage.deleteWeightEntry(entries[2].id);
    expect(await storage.getWeightHistory(), isEmpty);
    profile = (await storage.getProfile())!;
    expect(profile['weight'], 68);
    expect(profile['goal'], 'gain');
  });

  test(
      'invalid weights, future dates and invalid profiles do not change storage',
      () async {
    final storage = openService();
    await storage.saveUserProfile(_profile(),
        recordedAt: DateTime(2024, 5, 17));
    final db = await storage.database;
    final profileBefore = await storage.getProfile();
    final weightsBefore = await db.query('weight_history');
    for (final value in [0.0, -1.0, 501.0, double.nan, double.infinity]) {
      await expectLater(storage.saveWeight(weight: value), throwsArgumentError);
    }
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    await expectLater(
      storage.saveWeight(weight: 71, recordedAt: tomorrow),
      throwsArgumentError,
    );
    await expectLater(
      storage.saveUserProfile(_profile(weight: 71), recordedAt: tomorrow),
      throwsArgumentError,
    );
    await expectLater(
      storage.saveUserProfile(_profile(age: 17)),
      throwsArgumentError,
    );
    await expectLater(
      storage.saveUserProfile(_profile(calories: double.infinity)),
      throwsArgumentError,
    );
    expect(await storage.getProfile(), profileBefore);
    expect(await db.query('weight_history'), weightsBefore);
  });

  test('a weight-write failure rolls back its accompanying profile update',
      () async {
    final storage = openService();
    await storage.saveUserProfile(_profile(),
        recordedAt: DateTime(2024, 5, 17));
    final db = await storage.database;
    final before = await storage.getProfile();
    await db.execute('''
      create trigger reject_new_weight before insert on weight_history
      begin select raise(abort, 'Simulated weight write failure'); end
    ''');
    await expectLater(
      storage.saveUserProfile(
        _profile(weight: 75, goal: NutritionGoal.gain, calories: 2600),
        recordedAt: DateTime(2024, 5, 18),
      ),
      throwsA(isA<DatabaseException>()),
    );
    expect(await storage.getProfile(), before);
    expect((await storage.getWeightHistory()).single.weight, 70);
  });

  test('clearing recommendation archives preserves profile and weight history',
      () async {
    await _legacyFixture(databasePath);
    final storage = openService();
    final db = await storage.database;
    final profileBefore = await storage.getProfile();
    final weightsBefore = await db.query('weight_history');
    await storage.clearAllHistory();
    expect(await storage.getMealHistory(), isEmpty);
    expect(await storage.getWorkoutHistory(), isEmpty);
    expect(await storage.getWorkoutLogs(), isEmpty);
    expect(await storage.getProfile(), profileBefore);
    expect(await db.query('weight_history'), weightsBefore);
  });

  test('clearing recommendation archives preserves the food diary', () async {
    final storage = openService(inMemoryDatabasePath);
    await storage.addFoodLogEntries([
      FoodLogEntry(
        date: DateTime.now(),
        meal: MealSlot.lunch,
        name: 'Cơm tấm',
        calories: 600,
        protein: 30,
      ),
    ]);
    await storage.clearAllHistory();
    expect(await storage.getFoodLog(DateTime.now()), hasLength(1));
  });

  test('saving a new goal does not log an extra weigh-in', () async {
    final storage = openService();
    await storage.saveUserProfile(_profile(weight: 70),
        recordedAt: DateTime(2024, 5, 1, 9));
    // Weeks later only the goal changes; the form still shows 70 kg.
    await storage.saveUserProfile(
        _profile(weight: 70, goal: NutritionGoal.lose),
        recordedAt: DateTime(2024, 5, 20, 9));
    final history = await storage.getWeightHistory();
    expect(history, hasLength(1));
    expect(history.single.recordedAt, DateTime(2024, 5, 1));
    expect((await storage.getProfile())!['goal'], 'lose');

    // A different weight in the form is a new measurement.
    await storage.saveUserProfile(
        _profile(weight: 69.5, goal: NutritionGoal.lose),
        recordedAt: DateTime(2024, 5, 21, 9));
    expect(await storage.getWeightHistory(), hasLength(2));
    expect((await storage.getProfile())!['weight'], 69.5);
  });
}
