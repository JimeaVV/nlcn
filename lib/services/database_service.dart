import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/food_log_entry.dart';
import '../models/history_models.dart';
import '../models/recommendation_models.dart';
import '../models/user_profile.dart';
import '../models/weight_entry.dart';

class DatabaseService {
  DatabaseService._()
      : _factory = null,
        _path = null;

  DatabaseService.forTesting({
    required DatabaseFactory factory,
    required String path,
  })  : _factory = factory,
        _path = path;

  static final instance = DatabaseService._();
  final DatabaseFactory? _factory;
  final String? _path;
  Database? _db;
  Future<Database>? _opening;

  Future<Database> get database {
    final current = _db;
    if (current != null) {
      if (current.isOpen) return Future.value(current);
      _db = null;
      _opening = null;
    }
    return _opening ??= _open().then(
      (db) => _db = db,
      onError: (Object error, StackTrace stack) {
        _opening = null;
        Error.throwWithStackTrace(error, stack);
      },
    );
  }

  Future<Database> _open() async {
    final factory = _factory ?? databaseFactory;
    final path = _path ?? join(await factory.getDatabasesPath(), 'optifit.db');
    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: (db, _) async {
          await _createBaseTables(db);
          await _createWorkoutLogTable(db);
          await _createWeightTable(db);
          await _createFoodLogTable(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) await _createWorkoutLogTable(db);
          if (oldVersion < 3) await _upgradeProfileAndWeights(db);
          if (oldVersion < 4) await _createFoodLogTable(db);
        },
      ),
    );
  }

  Future<void> close() async {
    final pending = _opening;
    final current = _db ?? (pending == null ? null : await pending);
    if (current != null) await current.close();
    _db = null;
    _opening = null;
  }

  Future<void> _createBaseTables(Database db) async {
    await db.execute('''
      create table user_profile(
        id integer primary key,
        age integer not null,
        gender text not null,
        height real not null,
        weight real not null,
        activity_level real not null,
        goal text not null default 'maintain',
        calorie_override real,
        protein_override real,
        updated_at text not null
      )
    ''');
    await db.execute('''
      create table meal_plan_history(
        id integer primary key autoincrement,
        target_calories real not null,
        protein_target real not null,
        total_calories real not null,
        total_protein real not null,
        total_carb real not null,
        total_fat real not null,
        plan_json text not null,
        created_at text not null
      )
    ''');
    await db.execute('''
      create table workout_plan_history(
        id integer primary key autoincrement,
        split text not null,
        level text not null,
        target_time integer not null,
        estimated_time integer not null,
        exercises_json text not null,
        created_at text not null
      )
    ''');
  }

  Future<void> _createWeightTable(DatabaseExecutor db) async {
    await db.execute('''
      create table if not exists weight_history(
        id integer primary key autoincrement,
        recorded_date text unique not null,
        weight_kg real not null,
        updated_at text not null
      )
    ''');
  }

  Future<void> _upgradeProfileAndWeights(Database db) async {
    await db.execute(
      "alter table user_profile add column goal text not null default 'lose'",
    );
    await db
        .execute('alter table user_profile add column calorie_override real');
    await db
        .execute('alter table user_profile add column protein_override real');
    await _createWeightTable(db);
    // The previous app only stored the current weight. Keep that historical
    // baseline on its original date, preserving an existing measurement there.
    await db.execute('''
      insert or ignore into weight_history(recorded_date, weight_kg, updated_at)
      select substr(updated_at, 1, 10), weight, updated_at
      from user_profile where id = 1
    ''');
  }

  /// Version 4: what the user actually ate, one row per food.
  Future<void> _createFoodLogTable(Database db) async {
    await db.execute('''
      create table if not exists food_log(
        id integer primary key autoincrement,
        logged_date text not null,
        meal text not null,
        food_name text not null,
        grams real,
        calories real not null,
        protein real not null,
        carbs real not null,
        fat real not null,
        source text not null,
        confidence real,
        created_at text not null
      )
    ''');
    await db.execute(
      'create index if not exists food_log_date on food_log(logged_date)',
    );
  }

  Future<void> _createWorkoutLogTable(Database db) async {
    await db.execute('''
      create table if not exists workout_logs(
        id integer primary key autoincrement,
        exercise_name text not null,
        weight_kg real not null,
        set_1_reps integer not null,
        set_2_reps integer not null,
        set_3_reps integer not null,
        difficulty text not null,
        suggested_weight real not null,
        suggested_reps integer not null,
        action text not null,
        suggestion_message text not null,
        performed_at text not null
      )
    ''');
  }

  Future<void> saveProfile({
    required int age,
    required String gender,
    required double height,
    required double weight,
    required double activityLevel,
    NutritionGoal? goal,
    double? calorieOverride,
    double? proteinOverride,
    DateTime? recordedAt,
  }) async {
    final date = _measurementDate(recordedAt);
    final db = await database;
    await db.transaction((txn) async {
      final rows =
          await txn.query('user_profile', where: 'id=?', whereArgs: [1]);
      final existing = rows.isEmpty ? null : UserProfile.fromMap(rows.first);
      // Legacy callers cannot accidentally erase the user's newer settings.
      // Use saveUserProfile with nullable overrides to clear them explicitly.
      final profile = UserProfile(
        age: age,
        gender: gender,
        height: height,
        weight: weight,
        activityLevel: activityLevel,
        goal: goal ?? existing?.goal ?? NutritionGoal.maintain,
        calorieOverride: calorieOverride ?? existing?.calorieOverride,
        proteinOverride: proteinOverride ?? existing?.proteinOverride,
      );
      profile.validate();
      await _saveProfileAndWeight(txn, profile, date);
    });
  }

  Future<void> saveUserProfile(
    UserProfile profile, {
    DateTime? recordedAt,
  }) async {
    profile.validate();
    final date = _measurementDate(recordedAt);
    final db = await database;
    await db.transaction((txn) => _saveProfileAndWeight(txn, profile, date));
  }

  Future<void> _saveProfileAndWeight(
    Transaction txn,
    UserProfile profile,
    String date,
  ) async {
    final updatedAt = DateTime.now().toIso8601String();
    await txn.insert(
      'user_profile',
      {...profile.toMap(), 'id': 1, 'updated_at': updatedAt},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    // Saving a new goal must not invent a weigh-in: only a weight that
    // differs from the latest recorded one counts as measured on [date].
    final latest = await txn.query(
      'weight_history',
      columns: ['weight_kg'],
      orderBy: 'recorded_date desc',
      limit: 1,
    );
    final unchanged = latest.isNotEmpty &&
        ((latest.first['weight_kg'] as num).toDouble() - profile.weight).abs() <
            0.005;
    if (!unchanged) await _upsertWeight(txn, profile.weight, date, updatedAt);
    await _synchronizeProfileWeight(txn, updatedAt);
  }

  Future<void> saveWeight({
    required double weight,
    DateTime? recordedAt,
  }) async {
    if (!weight.isFinite || weight <= 0 || weight > 500) {
      throw ArgumentError('Weight must be finite and between 0 and 500 kg.');
    }
    final date = _measurementDate(recordedAt);
    final db = await database;
    await db.transaction((txn) async {
      final updatedAt = DateTime.now().toIso8601String();
      await _upsertWeight(txn, weight, date, updatedAt);
      await _synchronizeProfileWeight(txn, updatedAt);
    });
  }

  String _measurementDate(DateTime? recordedAt) {
    final date = (recordedAt ?? DateTime.now()).toLocal();
    final today = DateTime.now();
    final day = DateTime(date.year, date.month, date.day);
    if (day.isAfter(DateTime(today.year, today.month, today.day))) {
      throw ArgumentError('Weight measurements cannot be dated in the future.');
    }
    if (date.year < 1 || date.year > 9999) {
      throw ArgumentError('Weight measurements require a valid calendar date.');
    }
    String pad(int value) => value.toString().padLeft(2, '0');
    return '${date.year.toString().padLeft(4, '0')}-${pad(date.month)}-${pad(date.day)}';
  }

  Future<void> _upsertWeight(
    Transaction txn,
    double weight,
    String date,
    String updatedAt,
  ) async {
    final changes = await txn.update(
      'weight_history',
      {'weight_kg': weight, 'updated_at': updatedAt},
      where: 'recorded_date=?',
      whereArgs: [date],
    );
    if (changes == 0) {
      await txn.insert('weight_history', {
        'recorded_date': date,
        'weight_kg': weight,
        'updated_at': updatedAt,
      });
    }
  }

  Future<void> _synchronizeProfileWeight(
    Transaction txn,
    String updatedAt,
  ) async {
    final latest = await txn.query(
      'weight_history',
      columns: ['weight_kg'],
      orderBy: 'recorded_date desc',
      limit: 1,
    );
    if (latest.isEmpty) return;
    await txn.update(
      'user_profile',
      {'weight': latest.first['weight_kg'], 'updated_at': updatedAt},
      where: 'id=?',
      whereArgs: [1],
    );
  }

  Future<List<WeightEntry>> getWeightHistory({int limit = 90}) async {
    if (limit <= 0) {
      throw ArgumentError('Weight history limit must be positive.');
    }
    final db = await database;
    final rows = await db.query(
      'weight_history',
      orderBy: 'recorded_date desc',
      limit: limit,
    );
    return rows.map(WeightEntry.fromMap).toList(growable: false);
  }

  Future<void> deleteWeightEntry(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      final deleted =
          await txn.delete('weight_history', where: 'id=?', whereArgs: [id]);
      if (deleted > 0) {
        await _synchronizeProfileWeight(txn, DateTime.now().toIso8601String());
      }
    });
  }

  Future<Map<String, dynamic>?> getProfile() async {
    final db = await database;
    final rows = await db.query(
      'user_profile',
      where: 'id=?',
      whereArgs: [1],
      limit: 1,
    );
    return rows.isEmpty ? null : Map<String, dynamic>.from(rows.first);
  }

  Map<String, dynamic>? _map(dynamic value) {
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  Future<int> saveMealPlan(DietRecommendation recommendation) async {
    final db = await database;
    final plan = recommendation.plan;
    return db.insert('meal_plan_history', {
      'target_calories': recommendation.targetCalories,
      'protein_target': plan.proteinTarget,
      'total_calories': plan.totalCalories,
      'total_protein': plan.totalProtein,
      'total_carb': plan.totalCarbohydrates,
      'total_fat': plan.totalFat,
      'plan_json': jsonEncode(recommendation.rawResponse),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> saveWorkoutPlan({
    required String split,
    required String level,
    required WorkoutRecommendation recommendation,
  }) async {
    final db = await database;
    return db.insert('workout_plan_history', {
      'split': split,
      'level': level,
      'target_time': recommendation.targetTime,
      'estimated_time': recommendation.estimatedTime,
      'exercises_json': jsonEncode(recommendation.rawResponse),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> saveWorkoutLog({
    required String exerciseName,
    required double currentWeight,
    required int set1Reps,
    required int set2Reps,
    required int set3Reps,
    required String difficulty,
    required ProgressiveOverloadRecommendation recommendation,
  }) async {
    final db = await database;
    return db.insert('workout_logs', {
      'exercise_name': exerciseName,
      'weight_kg': currentWeight,
      'set_1_reps': set1Reps,
      'set_2_reps': set2Reps,
      'set_3_reps': set3Reps,
      'difficulty': difficulty,
      'suggested_weight': recommendation.nextWeight,
      'suggested_reps': recommendation.nextRepTarget,
      'action': recommendation.action,
      'suggestion_message': recommendation.message,
      'performed_at': DateTime.now().toIso8601String(),
    });
  }

  /// Adds diary entries in one transaction, so a plan is logged whole or not
  /// at all. Entries dated in the future are rejected.
  Future<List<int>> addFoodLogEntries(List<FoodLogEntry> entries) async {
    final today = diaryDateKey(DateTime.now());
    for (final entry in entries) {
      entry.validate();
      // Compare calendar days: an entry stamped later today is still today.
      if (diaryDateKey(entry.date).compareTo(today) > 0) {
        throw ArgumentError('Diary entries cannot be dated in the future.');
      }
    }
    final db = await database;
    return db.transaction((txn) async {
      final ids = <int>[];
      for (final entry in entries) {
        final row = entry.toMap()..remove('id');
        ids.add(await txn.insert('food_log', row));
      }
      return ids;
    });
  }

  Future<List<FoodLogEntry>> getFoodLog(DateTime day) async {
    final db = await database;
    final rows = await db.query(
      'food_log',
      where: 'logged_date=?',
      whereArgs: [diaryDateKey(day)],
      orderBy: 'id',
    );
    return rows.map(FoodLogEntry.fromMap).toList(growable: false);
  }

  Future<void> deleteFoodLogEntry(int id) async {
    final db = await database;
    await db.delete('food_log', where: 'id=?', whereArgs: [id]);
  }

  Future<List<MealHistoryEntry>> getMealHistory() async {
    final db = await database;
    final rows = await db.query(
      'meal_plan_history',
      orderBy: 'created_at desc',
    );
    return rows.map(MealHistoryEntry.fromMap).toList(growable: false);
  }

  Future<List<WorkoutHistoryEntry>> getWorkoutHistory() async {
    final db = await database;
    final rows = await db.query(
      'workout_plan_history',
      orderBy: 'created_at desc',
    );
    return rows.map(WorkoutHistoryEntry.fromMap).toList(growable: false);
  }

  Future<List<WorkoutLogEntry>> getWorkoutLogs() async {
    final db = await database;
    final rows = await db.query('workout_logs', orderBy: 'performed_at desc');
    return rows.map(WorkoutLogEntry.fromMap).toList(growable: false);
  }

  Map<String, dynamic>? tryDecodeJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return _map(decoded);
    } on FormatException {
      return null;
    }
  }

  Future<void> deleteMealPlan(int id) async {
    final db = await database;
    await db.delete('meal_plan_history', where: 'id=?', whereArgs: [id]);
  }

  Future<void> deleteWorkoutPlan(int id) async {
    final db = await database;
    await db.delete('workout_plan_history', where: 'id=?', whereArgs: [id]);
  }

  Future<void> deleteWorkoutLog(int id) async {
    final db = await database;
    await db.delete('workout_logs', where: 'id=?', whereArgs: [id]);
  }

  Future<void> clearAllHistory() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('meal_plan_history');
      await txn.delete('workout_plan_history');
      await txn.delete('workout_logs');
    });
  }
}
