import 'package:flutter/foundation.dart';

import '../engine/recommendation_engine.dart';
import '../models/recommendation_models.dart';
import '../models/user_profile.dart';
import 'dataset_repository.dart';

class RecommendationException implements Exception {
  const RecommendationException(this.message);

  final String message;

  @override
  String toString() => message;
}

typedef RecommendationRunner = Future<Map<String, dynamic>> Function(
    Map<String, dynamic> request);

/// All recommendations run locally. SQLite continues to own user history.
class RecommendationService {
  RecommendationService({
    DatasetRepository? datasets,
    RecommendationRunner? runner,
  })  : _datasets = datasets ?? DatasetRepository(),
        _runner = runner ?? _computeRecommendation;

  final DatasetRepository _datasets;
  final RecommendationRunner _runner;

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
  }) =>
      _recommend(
          'diet',
          {
            'age': age,
            'gender': gender,
            'weight': weight,
            'height': height,
            'activity_level': activityLevel,
            'goal': goal.name,
            'calorie_override': calorieOverride,
            'protein_override': proteinOverride,
            'seed': seed,
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
        request['foods'] = (await _datasets.load()).foods;
      } else if (operation == 'workout') {
        request['exercises'] = (await _datasets.load()).exercises;
      }
      return parse(await _runner(request));
    } on ArgumentError catch (error) {
      throw RecommendationException('${error.message}');
    } on StateError catch (error) {
      throw RecommendationException(error.message);
    } on FormatException {
      throw const RecommendationException(
        'Could not read the local recommendation data.',
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
