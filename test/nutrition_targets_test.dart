import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optifit/l10n/l10n.dart';
import 'package:optifit/engine/nutrition_targets.dart';
import 'package:optifit/models/user_profile.dart';

UserProfile profile({
  int age = 21,
  String gender = 'male',
  double height = 175,
  double weight = 70,
  double activityLevel = 1.55,
  NutritionGoal goal = NutritionGoal.maintain,
  double? calories,
  double? protein,
  DateTime? updatedAt,
}) =>
    UserProfile(
      age: age,
      gender: gender,
      height: height,
      weight: weight,
      activityLevel: activityLevel,
      goal: goal,
      calorieOverride: calories,
      proteinOverride: protein,
      updatedAt: updatedAt,
    );

void main() {
  group('nutrition targets', () {
    test('default maintain estimates keep BMR, TDEE and legacy protein factor',
        () {
      expect(profile().goal, NutritionGoal.maintain);
      expect(calculateNutritionTargets(profile()), {
        'bmr': 1694,
        'tdee': 2625,
        'target_calories': 2625.0,
        'protein_target': 126.0,
        'goal': 'maintain',
        'calorie_source': 'estimated',
        'protein_source': 'estimated',
        'estimated_calories': 2625,
        'estimated_protein': 126.0,
      });
    });

    test('goal factors order estimates using unrounded TDEE', () {
      final lose = calculateNutritionTargets(profile(goal: NutritionGoal.lose));
      final maintain = calculateNutritionTargets(profile());
      final gain = calculateNutritionTargets(profile(goal: NutritionGoal.gain));
      expect(lose['target_calories'], 2363.0);
      expect(maintain['target_calories'], 2625.0);
      expect(gain['target_calories'], 2888.0);
      expect(lose['target_calories'], lessThan(maintain['target_calories']));
      expect(gain['target_calories'], greaterThan(maintain['target_calories']));
      expect(lose['protein_target'], maintain['protein_target']);
      expect(gain['protein_target'], maintain['protein_target']);
    });

    test('preserves manual values and keeps original estimates visible', () {
      final result = calculateNutritionTargets(
          profile(goal: NutritionGoal.lose, calories: 2200.25, protein: 140.5));
      expect(result['target_calories'], 2200.25);
      expect(result['protein_target'], 140.5);
      expect(result['calorie_source'], 'manual');
      expect(result['protein_source'], 'manual');
      expect(result['estimated_calories'], 2363);
      expect(result['estimated_protein'], 126.0);
      expect(result['goal'], 'lose');
    });

    test('calorie and protein overrides work independently', () {
      final calories = calculateNutritionTargets(profile(calories: 2000));
      expect(calories['target_calories'], 2000.0);
      expect(calories['protein_target'], 126.0);
      expect(calories['calorie_source'], 'manual');
      expect(calories['protein_source'], 'estimated');
      final protein = calculateNutritionTargets(profile(protein: 150));
      expect(protein['target_calories'], 2625.0);
      expect(protein['protein_target'], 150.0);
      expect(protein['calorie_source'], 'estimated');
      expect(protein['protein_source'], 'manual');
    });

    test('rejects estimates outside the guardrails without clamping', () {
      expect(
          () => calculateNutritionTargets(
              profile(age: 100, weight: 30, height: 100, activityLevel: 1.2)),
          throwsArgumentError);
      expect(
          () => calculateNutritionTargets(
              profile(weight: 500, height: 300, activityLevel: 1.9)),
          throwsArgumentError);
      expect(() => calculateNutritionTargets(profile(weight: 300)),
          throwsArgumentError);
    });

    test(
        'manual targets can repair low or high estimates if BMR stays positive',
        () {
      final low = calculateNutritionTargets(profile(
          age: 100,
          weight: 30,
          height: 100,
          activityLevel: 1.2,
          calories: 1500));
      expect(low['estimated_calories'], 516);
      expect(low['target_calories'], 1500.0);
      final high = calculateNutritionTargets(profile(
          weight: 500,
          height: 300,
          activityLevel: 1.9,
          calories: 3000,
          protein: 160));
      expect(high['estimated_calories'], greaterThan(10000));
      expect(high['estimated_protein'], 900.0);
      expect(high['target_calories'], 3000.0);
      expect(high['protein_target'], 160.0);
    });

    test('manual calories cannot repair nonpositive BMR or TDEE', () {
      expect(
          () => calculateNutritionTargets(profile(
              age: 100,
              gender: 'female',
              weight: 1,
              height: 1,
              calories: 1500,
              protein: 100)),
          throwsArgumentError);
    });

    test('protein energy cannot exceed calories, including mixed sources', () {
      expect(
          () =>
              calculateNutritionTargets(profile(calories: 1000, protein: 251)),
          throwsArgumentError);
      expect(
          () => calculateNutritionTargets(profile(weight: 200, calories: 1000)),
          throwsArgumentError);
      expect(
          calculateNutritionTargets(
              profile(calories: 1000, protein: 250))['protein_target'],
          250.0);
    });

    test('allows exact manual boundaries', () {
      expect(
          calculateNutritionTargets(
              profile(calories: 1000, protein: 0.1))['target_calories'],
          1000.0);
      expect(
          calculateNutritionTargets(
              profile(calories: 10000, protein: 500))['protein_target'],
          500.0);
    });
  });

  group('user profile validation and storage', () {
    test('rejects minors, out of range adults and invalid enums', () {
      for (final invalid in [
        profile(age: 17),
        profile(age: 101),
        profile(gender: 'unknown'),
        profile(activityLevel: 1.3)
      ]) {
        expect(invalid.validate, throwsArgumentError);
      }
      expect(profile(age: 18).validate, returnsNormally);
      expect(profile(age: 100).validate, returnsNormally);
    });

    test('rejects nonfinite and out of range body inputs', () {
      for (final invalid in [
        profile(height: double.nan),
        profile(weight: double.infinity),
        profile(activityLevel: double.infinity),
        profile(height: 0),
        profile(height: 301),
        profile(weight: 0),
        profile(weight: 501)
      ]) {
        expect(invalid.validate, throwsArgumentError);
      }
    });

    test('rejects invalid overrides instead of falling back to estimates', () {
      for (final value in [0.0, 999.0, 10001.0, double.nan, double.infinity]) {
        expect(() => calculateNutritionTargets(profile(calories: value)),
            throwsArgumentError);
      }
      for (final value in [0.0, -1.0, 501.0, double.nan, double.infinity]) {
        expect(() => calculateNutritionTargets(profile(protein: value)),
            throwsArgumentError);
      }
    });

    test('loads legacy profiles as lose, with no manual overrides', () {
      final loaded = UserProfile.fromMap({
        'id': 1,
        'age': 21,
        'gender': 'male',
        'height': 175,
        'weight': 70,
        'activity_level': 1.55,
        'updated_at': '2026-10-15T09:00:00.000Z',
      });
      expect(loaded.goal, NutritionGoal.lose);
      expect(loaded.calorieOverride, isNull);
      expect(loaded.proteinOverride, isNull);
      expect(loaded.updatedAt, DateTime.utc(2026, 10, 15, 9));
      expect(loaded.validate, returnsNormally);
      expect(calculateNutritionTargets(loaded)['target_calories'], 2363.0);
    });

    test('roundtrips all goals, overrides and timestamp in DB snake case', () {
      for (final goal in NutritionGoal.values) {
        final original = profile(
            goal: goal,
            calories: 2100.5,
            protein: 130.5,
            updatedAt: DateTime.utc(2026, 10, 15));
        final stored = original.toMap();
        expect(stored['goal'], goal.name);
        expect(stored['activity_level'], 1.55);
        expect(stored['calorie_override'], 2100.5);
        expect(stored['protein_override'], 130.5);
        expect(UserProfile.fromMap(stored).toMap(), stored);
      }
    });

    test('parses numeric strings and leaves absent timestamps to the DB layer',
        () {
      final loaded = UserProfile.fromMap({
        'age': '21',
        'gender': 'male',
        'height': '175',
        'weight': '70.5',
        'activity_level': '1.55',
        'goal': 'maintain',
        'calorie_override': '2000',
        'protein_override': '130',
      });
      expect(loaded.weight, 70.5);
      expect(loaded.calorieOverride, 2000.0);
      expect(loaded.proteinOverride, 130.0);
      expect(loaded.updatedAt, isNull);
      expect(loaded.toMap().containsKey('updated_at'), isFalse);
    });

    test('rejects malformed stored ages, goals and dates', () {
      final stored = profile().toMap();
      for (final entry in {
        'age': 21.5,
        'goal': 'unknown',
        'updated_at': 'not a date',
        'height': 'not a number'
      }.entries) {
        expect(() => UserProfile.fromMap({...stored, entry.key: entry.value}),
            throwsArgumentError);
      }
    });

    test('labels goals in Vietnamese and English', () {
      final vi = lookupAppLocalizations(const Locale('vi'));
      final en = lookupAppLocalizations(const Locale('en'));
      expect(vi.goalLabel(NutritionGoal.lose), 'Giảm mỡ');
      expect(vi.goalLabel(NutritionGoal.maintain), 'Giữ cân');
      expect(vi.goalLabel(NutritionGoal.gain), 'Tăng cân');
      expect(en.goalLabel(NutritionGoal.lose), 'Lose fat');
      expect(en.goalLabel(NutritionGoal.gain), 'Gain weight');
    });

    test('reports which target rule failed', () {
      const profile = UserProfile(
        age: 30,
        gender: 'male',
        height: 175,
        weight: 70,
        activityLevel: 1.55,
        calorieOverride: 1000,
        proteinOverride: 300,
      );
      expect(
        () => calculateNutritionTargets(profile),
        throwsA(isA<NutritionTargetError>().having((error) => error.issue,
            'issue', NutritionTargetIssue.proteinExceedsCalories)),
      );
    });
  });
}
