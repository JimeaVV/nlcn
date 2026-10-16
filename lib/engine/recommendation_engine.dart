import 'fitness_engine.dart';
import 'meal_planner.dart';
import 'nutrition_targets.dart';
import '../models/user_profile.dart';

/// Pure Dart entry point. Only sendable input/output crosses the worker isolate.
Map<String, dynamic> runRecommendation(Map<String, dynamic> request) {
  switch (request['operation']) {
    case 'diet':
      final calories = calculateNutritionTargets(UserProfile.fromMap(request));
      final plan = generateMealPlan(
        _rows(request['foods']),
        dailyCalories: (calories['target_calories'] as num).toDouble(),
        bodyWeightKg: (request['weight'] as num).toDouble(),
        proteinTarget: (calories['protein_target'] as num).toDouble(),
        seed: request['seed'] as int?,
      );
      return {
        'status': 'success',
        'message': 'Diet plan generated on this device.',
        ...calories,
        'data': plan,
      };
    case 'workout':
      return recommendWorkoutRoutine(
        _rows(request['exercises']),
        targetSplit: request['target_split'] as String,
        targetLevel: request['target_level'] as String,
        availableTimeMins: request['available_time_mins'] as int,
      );
    case 'overload':
      return suggestProgressiveOverload(
        exerciseName: request['exercise_name'] as String,
        currentWeight: (request['current_weight'] as num).toDouble(),
        repsPerSet: [
          request['set_1_reps'] as int,
          request['set_2_reps'] as int,
          request['set_3_reps'] as int,
        ],
        difficulty: request['difficulty'] as String,
      );
    default:
      throw ArgumentError('Unknown recommendation operation.');
  }
}

List<Map<String, dynamic>> _rows(dynamic value) => (value as List)
    .map((row) => Map<String, dynamic>.from(row as Map))
    .toList();
