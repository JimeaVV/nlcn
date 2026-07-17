import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  DatabaseService._();
  static final instance = DatabaseService._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final path = join(await getDatabasesPath(), 'optifit.db');
    _db = await openDatabase(path, version: 1, onCreate: (db, _) async {
      await db.execute("""
        create table user_profile(
          id integer primary key,
          age integer not null,
          gender text not null,
          height real not null,
          weight real not null,
          activity_level real not null,
          updated_at text not null
        )
      """);
      await db.execute("""
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
      """);
      await db.execute("""
        create table workout_plan_history(
          id integer primary key autoincrement,
          split text not null,
          level text not null,
          target_time integer not null,
          estimated_time integer not null,
          exercises_json text not null,
          created_at text not null
        )
      """);
    });
    return _db!;
  }

  Future<void> saveProfile({
    required int age,
    required String gender,
    required double height,
    required double weight,
    required double activityLevel,
  }) async {
    final db = await database;
    await db.insert('user_profile', {
      'id': 1,
      'age': age,
      'gender': gender,
      'height': height,
      'weight': weight,
      'activity_level': activityLevel,
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getProfile() async {
    final db = await database;
    final rows = await db.query('user_profile', where: 'id=?', whereArgs: [1], limit: 1);
    return rows.isEmpty ? null : Map<String, dynamic>.from(rows.first);
  }

  double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
  int _i(dynamic v) => v is num ? v.round() : int.tryParse('$v') ?? 0;

  Future<int> saveMealPlan(Map<String, dynamic> response) async {
    final db = await database;
    final plan = response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : <String, dynamic>{};
    return db.insert('meal_plan_history', {
      'target_calories': _d(response['target_calories'] ?? plan['target_calo']),
      'protein_target': _d(plan['protein_target']),
      'total_calories': _d(plan['total_calo']),
      'total_protein': _d(plan['total_protein']),
      'total_carb': _d(plan['total_carb']),
      'total_fat': _d(plan['total_fat']),
      'plan_json': jsonEncode(response),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> saveWorkoutPlan({
    required String split,
    required String level,
    required Map<String, dynamic> response,
  }) async {
    final db = await database;
    return db.insert('workout_plan_history', {
      'split': split,
      'level': level,
      'target_time': _i(response['target_time']),
      'estimated_time': _i(response['estimated_time']),
      'exercises_json': jsonEncode(response),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getMealHistory() async {
    final db = await database;
    final rows = await db.query('meal_plan_history', orderBy: 'created_at desc');
    return rows.map(Map<String, dynamic>.from).toList();
  }

  Future<List<Map<String, dynamic>>> getWorkoutHistory() async {
    final db = await database;
    final rows = await db.query('workout_plan_history', orderBy: 'created_at desc');
    return rows.map(Map<String, dynamic>.from).toList();
  }

  Map<String, dynamic> decodeJson(String raw) =>
      Map<String, dynamic>.from(jsonDecode(raw) as Map);

  Future<void> deleteMealPlan(int id) async {
    final db = await database;
    await db.delete('meal_plan_history', where: 'id=?', whereArgs: [id]);
  }

  Future<void> deleteWorkoutPlan(int id) async {
    final db = await database;
    await db.delete('workout_plan_history', where: 'id=?', whereArgs: [id]);
  }

  Future<void> clearAllHistory() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('meal_plan_history');
      await txn.delete('workout_plan_history');
    });
  }
}
