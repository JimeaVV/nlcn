import 'package:flutter_test/flutter_test.dart';
import 'package:optifit/engine/meal_planner.dart';
import 'package:optifit/engine/number_utils.dart';

void main() {
  test('matches signed Python ties to even and binary floating-point cases',
      () {
    for (final entry in {
      7.125: 7.12,
      -7.125: -7.12,
      7.375: 7.38,
      -7.375: -7.38,
      2.675: 2.67,
      -2.675: -2.67,
      2.685: 2.69,
      -2.685: -2.69,
    }.entries) {
      expect(roundLikePython(entry.key), entry.value);
    }
  });

  test('supports meal scores, elapsed time and signed differences', () {
    expect(roundLikePython(1.0625, digits: 3), 1.062);
    expect(roundLikePython(-1.0625, digits: 3), -1.062);
    expect(roundLikePython(1.1875, digits: 3), 1.188);
    expect(roundLikePython(1.0078125, digits: 6), 1.007812);
    expect(roundLikePython(-1.0078125, digits: 6), -1.007812);
    expect(roundLikePython(1.0234375, digits: 6), 1.023438);
  });

  test('retains signed zero and handles large and subnormal finite values', () {
    expect(roundLikePython(-0.0).isNegative, isTrue);
    expect(roundLikePython(-0.001).isNegative, isTrue);
    expect(roundLikePython(250, digits: -2), 200);
    expect(roundLikePython(-350, digits: -2), -400);
    expect(roundLikePython(double.maxFinite), double.maxFinite);
    expect(roundLikePython(5e-324, digits: 323), 0);
    expect(roundLikePython(5e-324, digits: 324), 5e-324);
  });

  test('rejects non-finite inputs', () {
    for (final value in [
      double.nan,
      double.infinity,
      double.negativeInfinity
    ]) {
      expect(() => roundLikePython(value), throwsArgumentError);
    }
  });

  test('meal portions use the shared rounding in their response', () {
    final meal = branchAndBoundMeal(
      [
        const MealCandidateGroup(
          group: 'dairyegg',
          foods: [
            {
              'name': 'egg raw',
              'macro_group': 'DairyEgg',
              'calories_per_100g': 143,
              'protein_g': 12.6,
              'carb_g': 0.7,
              'fat_g': 9.5,
              'max_amount_g': 75,
            },
          ],
        ),
      ],
      targetCalories: 107.25,
      targetProtein: 9.45,
    );
    final item = (meal['items'] as List<Map<String, dynamic>>).single;
    expect(item['portion_g'], 75);
    expect(item['serving_fat'], 7.12);
  });
}
