import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optifit/models/recommendation_models.dart';
import 'package:optifit/models/user_profile.dart';
import 'package:optifit/services/dataset_repository.dart';
import 'package:optifit/services/recommendation_service.dart';

class _Bundle extends CachingAssetBundle {
  _Bundle(this.source);

  final String source;
  int reads = 0;
  bool fail = false;

  @override
  Future<ByteData> load(String key) async {
    expect(key, DatasetRepository.assetPath);
    reads++;
    if (fail) throw StateError('Asset unavailable');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(source)));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('packaged data loads offline and is shared by concurrent callers',
      () async {
    final source = await rootBundle.loadString(DatasetRepository.assetPath);
    final bundle = _Bundle(source);
    final repository = DatasetRepository(bundle: bundle);
    final data = await Future.wait([repository.load(), repository.load()]);

    expect(identical(data[0], data[1]), isTrue);
    expect(bundle.reads, 1);
    expect(data[0].foods, hasLength(160));
    expect(data[0].exercises, hasLength(96));
    final service = RecommendationService(datasets: repository);
    expect(await service.health(), {
      'status': 'ok',
      'mode': 'offline',
      'food_rows': 160,
      'gym_rows': 96,
    });
    expect(bundle.reads, 1);
  });

  test('a failed dataset load can be retried', () async {
    final bundle = _Bundle(
      await rootBundle.loadString(DatasetRepository.assetPath),
    )..fail = true;
    final repository = DatasetRepository(bundle: bundle);
    await expectLater(repository.load(), throwsStateError);
    bundle.fail = false;
    expect((await repository.load()).foods, hasLength(160));
    expect(bundle.reads, 2);
  });

  test('corrupt or incompatible datasets produce a local error', () async {
    final service = RecommendationService(
      datasets: DatasetRepository(bundle: _Bundle('{"schema_version":9}')),
    );
    await expectLater(
        service.health(), throwsA(isA<RecommendationException>()));
  });

  test(
      'meal planning runs in the worker with packaged data and serializable output',
      () async {
    final service = RecommendationService();
    final result = await service.recommendDiet(
      age: 21,
      gender: 'male',
      weight: 70,
      height: 175,
      activityLevel: 1.55,
      seed: 42,
    );
    expect(result.bmr, 1694);
    expect(result.tdee, 2625);
    expect(result.targetCalories, 2625);
    // 2625 kcal is above the snack threshold of the Vietnamese planner.
    expect(result.plan.meals.keys,
        unorderedEquals(['Breakfast', 'Lunch', 'Dinner', 'Snack']));
    expect(result.plan.totalCalories, greaterThan(0));
    expect(result.plan.totalCalories, lessThanOrEqualTo(2625 * 1.12 + 0.1));
    final roundTrip = DietRecommendation.fromJson(
      jsonDecode(jsonEncode(result.rawResponse)) as Map<String, dynamic>,
    );
    expect(roundTrip.plan.totalCalories, result.plan.totalCalories);
  });

  test('workout planning runs in the worker without a server', () async {
    final result = await RecommendationService().recommendWorkout(
      split: 'Push',
      level: 'Beginner',
      minutes: 45,
    );
    expect(result.estimatedTime, lessThanOrEqualTo(45));
    expect(result.exercises.length, inInclusiveRange(1, 5));
    expect(result.exercises.map((item) => item.name).toSet().length,
        result.exercises.length);
    expect(result.requestedLevel, 'Beginner');
    // Push has machine, cable and bodyweight work tagged Beginner, so a
    // beginner no longer borrows Intermediate exercises.
    expect(result.levelFallbackUsed, isFalse);
    expect(result.usedLevels, ['Beginner']);
  });

  test('every level and muscle group in the bundled data is reachable',
      () async {
    final service = RecommendationService();
    final pro = await service.recommendWorkout(
        split: 'Legs', level: 'Pro', minutes: 120);
    expect(pro.usedLevels, contains('Pro'));
    final pull = await service.recommendWorkout(
        split: 'Pull', level: 'Intermediate', minutes: 120);
    expect(pull.exercises.map((e) => e.name), contains(contains('shrug')));
    final legs = await service.recommendWorkout(
        split: 'Legs', level: 'Beginner', minutes: 120);
    expect(legs.exercises.map((e) => e.name), anyElement(startsWith('Thigh')));
  });

  test('manual calories and protein survive the worker and saved response',
      () async {
    final result = await RecommendationService().recommendDiet(
      age: 21,
      gender: 'male',
      weight: 70,
      height: 175,
      activityLevel: 1.55,
      goal: NutritionGoal.gain,
      calorieOverride: 2200,
      proteinOverride: 140,
      seed: 7,
    );
    expect(result.targetCalories, 2200);
    expect(result.plan.proteinTarget, 140);
    expect(result.rawResponse['goal'], 'gain');
    expect(result.rawResponse['calorie_source'], 'manual');
    expect(result.rawResponse['protein_source'], 'manual');
    final restored = DietRecommendation.fromJson(
        jsonDecode(jsonEncode(result.rawResponse)) as Map<String, dynamic>);
    expect(restored.targetCalories, 2200);
    expect(restored.plan.proteinTarget, 140);
  });

  test('overload works even without access to dataset assets', () async {
    final bundle = _Bundle('')..fail = true;
    final service = RecommendationService(
      datasets: DatasetRepository(bundle: bundle),
    );
    final result = await service.recommendProgressiveOverload(
      exerciseName: 'Bench Press',
      currentWeight: 50,
      set1Reps: 12,
      set2Reps: 12,
      set3Reps: 12,
      difficulty: 'Moderate',
    );
    expect(result.action, 'increase_weight');
    expect(result.nextWeight, 52.5);
    expect(bundle.reads, 0);
  });

  test('invalid input from the worker surfaces as a readable local error',
      () async {
    await expectLater(
      RecommendationService().recommendWorkout(
        split: 'Unknown',
        level: 'Beginner',
        minutes: 45,
      ),
      throwsA(isA<RecommendationException>().having(
        (error) => error.message,
        'message',
        contains('split'),
      )),
    );
  });
}
