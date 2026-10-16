class MealHistoryEntry {
  const MealHistoryEntry({
    required this.id,
    required this.totalCalories,
    required this.totalProtein,
    required this.planJson,
    required this.createdAt,
  });

  factory MealHistoryEntry.fromMap(Map<String, dynamic> row) {
    return MealHistoryEntry(
      id: _integer(row['id']),
      totalCalories: _number(row['total_calories']),
      totalProtein: _number(row['total_protein']),
      planJson: '${row['plan_json'] ?? ''}',
      createdAt: _date(row['created_at']),
    );
  }

  final int id;
  final double totalCalories;
  final double totalProtein;
  final String planJson;
  final DateTime createdAt;
}

class WorkoutHistoryEntry {
  const WorkoutHistoryEntry({
    required this.id,
    required this.split,
    required this.level,
    required this.estimatedTime,
    required this.exercisesJson,
    required this.createdAt,
  });

  factory WorkoutHistoryEntry.fromMap(Map<String, dynamic> row) {
    return WorkoutHistoryEntry(
      id: _integer(row['id']),
      split: '${row['split'] ?? ''}',
      level: '${row['level'] ?? ''}',
      estimatedTime: _integer(row['estimated_time']),
      exercisesJson: '${row['exercises_json'] ?? ''}',
      createdAt: _date(row['created_at']),
    );
  }

  final int id;
  final String split;
  final String level;
  final int estimatedTime;
  final String exercisesJson;
  final DateTime createdAt;
}

class WorkoutLogEntry {
  const WorkoutLogEntry({
    required this.id,
    required this.exerciseName,
    required this.weight,
    required this.set1Reps,
    required this.set2Reps,
    required this.set3Reps,
    required this.suggestedWeight,
    required this.suggestedReps,
    this.action = '',
    required this.message,
    required this.performedAt,
  });

  factory WorkoutLogEntry.fromMap(Map<String, dynamic> row) {
    return WorkoutLogEntry(
      id: _integer(row['id']),
      exerciseName: '${row['exercise_name'] ?? ''}',
      weight: _number(row['weight_kg']),
      set1Reps: _integer(row['set_1_reps']),
      set2Reps: _integer(row['set_2_reps']),
      set3Reps: _integer(row['set_3_reps']),
      suggestedWeight: _number(row['suggested_weight']),
      suggestedReps: _integer(row['suggested_reps']),
      action: '${row['action'] ?? ''}',
      message: '${row['suggestion_message'] ?? ''}',
      performedAt: _date(row['performed_at']),
    );
  }

  final int id;
  final String exerciseName;
  final double weight;
  final int set1Reps;
  final int set2Reps;
  final int set3Reps;
  final double suggestedWeight;
  final int suggestedReps;
  final String action;
  final String message;
  final DateTime performedAt;
}

double _number(dynamic value) {
  final number = value is num ? value.toDouble() : double.tryParse('$value');
  if (number == null) {
    throw const FormatException('Invalid numeric history value.');
  }
  return number;
}

int _integer(dynamic value) {
  final number = value is num ? value.round() : int.tryParse('$value');
  if (number == null) {
    throw const FormatException('Invalid integer history value.');
  }
  return number;
}

DateTime _date(dynamic value) {
  final date = DateTime.tryParse('$value');
  if (date == null) throw const FormatException('Invalid history timestamp.');
  return date;
}
