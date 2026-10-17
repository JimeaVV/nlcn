import '../models/user_profile.dart';
import '../models/vn_food.dart';
import 'fitness_engine.dart';
import 'meal_planner.dart';
import 'nutrition_targets.dart';
import 'vn_meal_planner.dart';

/// Pure Dart entry point. Only sendable input/output crosses the worker isolate.
Map<String, dynamic> runRecommendation(Map<String, dynamic> request) {
  switch (request['operation']) {
    case 'diet':
      final profile = UserProfile.fromMap(request);
      final calories = calculateNutritionTargets(profile);
      final dailyCalories = (calories['target_calories'] as num).toDouble();
      final proteinTarget = (calories['protein_target'] as num).toDouble();
      final weight = (request['weight'] as num).toDouble();
      final tables = request['vn_tables'];
      // Vietnamese dishes when their tables are sent; the original
      // ingredient planner otherwise.
      final plan = tables is Map
          ? generateVnMealPlan(
              parseVnFoodData(
                componentsCsv: tables['components'] as String,
                dishesCsv: tables['dishes'] as String,
                dishNamesCsv: tables['dish_names'] as String,
              ),
              parseMealPlanTags(tables['meal_plan'] as String),
              dailyCalories: dailyCalories,
              proteinTarget: proteinTarget,
              bodyWeightKg: weight,
              goal: profile.goal,
              seed: request['seed'] as int? ?? 0,
              languageCode: request['language'] as String? ?? 'vi',
            )
          : generateMealPlan(
              _rows(request['foods']),
              dailyCalories: dailyCalories,
              bodyWeightKg: weight,
              proteinTarget: proteinTarget,
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
