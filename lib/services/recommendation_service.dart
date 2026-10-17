import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../engine/meal_planner.dart';
import '../engine/nutrition_targets.dart';
import '../engine/recommendation_engine.dart';
import '../models/recommendation_models.dart';
import '../models/user_profile.dart';
import 'dataset_repository.dart';
import 'vn_food_repository.dart';

/// Why a recommendation failed; the interface turns this into localized text.
enum RecommendationErrorCode {
  dataUnavailable,
  calorieTargetOutOfRange,
  proteinTargetOutOfRange,
  proteinExceedsCalories,
  mealNotFound,
  workoutNotFound,
  invalidInput,
  unknown,
}

class RecommendationException implements Exception {
  const RecommendationException(
    this.message, {
    this.code = RecommendationErrorCode.unknown,
  });

  /// English diagnostic text; shown to users only through [code].
  final String message;
  final RecommendationErrorCode code;

  @override
  String toString() => message;
}

typedef RecommendationRunner = Future<Map<String, dynamic>> Function(
    Map<String, dynamic> request);

/// All recommendations run locally. SQLite continues to own user history.
class RecommendationService {
  RecommendationService({
    DatasetRepository? datasets,
    VnFoodRepository? vnFood,
    RecommendationRunner? runner,
  })  : _datasets = datasets ?? DatasetRepository(),
        _vnFood = vnFood ?? VnFoodRepository(),
        _runner = runner ?? _computeRecommendation;

  final DatasetRepository _datasets;
  final VnFoodRepository _vnFood;
  final RecommendationRunner _runner;
  final _seeds = math.Random();

  Future<Map<String, dynamic>> health() async {
    try {
      final data = await _datasets.load();
      return {
        'status': 'ok',
        'mode': 'offline',
        'food_rows': data.foods.length,
        'gym_rows': data.exercises.length,
      };
    } catch (_) {
      throw const RecommendationException(
        'Could not load the food and exercise data packaged with the app.',
        code: RecommendationErrorCode.dataUnavailable,
      );
    }
  }

  Future<DietRecommendation> recommendDiet({
    required int age,
    required String gender,
    required double weight,
    required double height,
    required double activityLevel,
    NutritionGoal goal = NutritionGoal.maintain,
    double? calorieOverride,
    double? proteinOverride,
    int? seed,
    String languageCode = 'vi',
  }) =>
      _recommend(
          'diet',
          {
            'language': languageCode,
            'age': age,
            'gender': gender,
            'weight': weight,
            'height': height,
            'activity_level': activityLevel,
            'goal': goal.name,
            'calorie_override': calorieOverride,
            'protein_override': proteinOverride,
            // A fresh seed gives a different day each time; it is returned
            // with the plan so the same plan can be reproduced.
            'seed': seed ?? _seeds.nextInt(1 << 31),
          },
          DietRecommendation.fromJson);

  Future<WorkoutRecommendation> recommendWorkout({
    required String split,
    required String level,
    required int minutes,
  }) =>
      _recommend(
          'workout',
          {
            'target_split': split,
            'target_level': level,
            'available_time_mins': minutes,
          },
          WorkoutRecommendation.fromJson);

  Future<ProgressiveOverloadRecommendation> recommendProgressiveOverload({
    required String exerciseName,
    required double currentWeight,
    required int set1Reps,
    required int set2Reps,
    required int set3Reps,
    required String difficulty,
  }) =>
      _recommend(
          'overload',
          {
            'exercise_name': exerciseName,
            'current_weight': currentWeight,
            'set_1_reps': set1Reps,
            'set_2_reps': set2Reps,
            'set_3_reps': set3Reps,
            'difficulty': difficulty,
          },
          ProgressiveOverloadRecommendation.fromJson);

  Future<T> _recommend<T>(String operation, Map<String, dynamic> input,
      T Function(Map<String, dynamic>) parse) async {
    try {
      final request = <String, dynamic>{'operation': operation, ...input};
      if (operation == 'diet') {
        request['vn_tables'] = await _vnFood.loadTables();
      } else if (operation == 'workout') {
        request['exercises'] = (await _datasets.load()).exercises;
      }
      return parse(await _runner(request));
    } on NutritionTargetError catch (error) {
      throw RecommendationException(
        '${error.message}',
        code: switch (error.issue) {
          NutritionTargetIssue.calorieRange =>
            RecommendationErrorCode.calorieTargetOutOfRange,
          NutritionTargetIssue.proteinRange =>
            RecommendationErrorCode.proteinTargetOutOfRange,
          NutritionTargetIssue.proteinExceedsCalories =>
            RecommendationErrorCode.proteinExceedsCalories,
        },
      );
    } on MealPlanUnavailableError catch (error) {
      throw RecommendationException(
        '${error.message}',
        code: RecommendationErrorCode.mealNotFound,
      );
    } on ArgumentError catch (error) {
      throw RecommendationException(
        '${error.message}',
        code: RecommendationErrorCode.invalidInput,
      );
    } on StateError catch (error) {
      throw RecommendationException(
        error.message,
        code: operation == 'workout'
            ? RecommendationErrorCode.workoutNotFound
            : RecommendationErrorCode.unknown,
      );
    } on FormatException {
      throw const RecommendationException(
        'Could not read the local recommendation data.',
        code: RecommendationErrorCode.dataUnavailable,
      );
    } on RecommendationException {
      rethrow;
    } catch (_) {
      throw const RecommendationException(
        'Could not generate a recommendation on this device. Please try again.',
      );
    }
  }
}

Future<Map<String, dynamic>> _computeRecommendation(
        Map<String, dynamic> request) =>
    compute(runRecommendation, request, debugLabel: 'OptiFit recommendation');
