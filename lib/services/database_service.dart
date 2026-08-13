import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/history_models.dart';
import '../models/recommendation_models.dart';

class DatabaseService {
  DatabaseService._();
  static final instance = DatabaseService._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final path = join(await getDatabasesPath(), 'optifit.db');
    _db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, _) async {
        await _createBaseTables(db);
        await _createWorkoutLogTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createWorkoutLogTable(db);
        }
      },
    );
    return _db!;
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
  }) async {
    final db = await database;
    await db.insert(
        'user_profile',
        {
          'id': 1,
          'age': age,
          'gender': gender,
          'height': height,
          'weight': weight,
          'activity_level': activityLevel,
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
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
