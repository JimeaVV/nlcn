import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:optifit/engine/meal_planner.dart';
import 'package:optifit/models/recommendation_models.dart';

Map<String, dynamic> _food(
  String name,
  String group, {
  required double calories,
  double protein = 0,
  double carbs = 0,
  double fat = 0,
  int maximum = 250,
}) =>
    {
      'name': name,
      'category': group,
      'macro_group': group,
      'calories_per_100g': calories,
      'protein_g': protein,
      'carb_g': carbs,
      'fat_g': fat,
      'max_amount_g': maximum,
      'suggested_prep': 'Boil',
    };

List<Map<String, dynamic>> _foods() => [
      _food('rice', 'Starch', calories: 130, protein: 2.5, carbs: 28),
      _food('potato', 'Starch', calories: 80, protein: 2, carbs: 18),
      _food('chicken', 'Meat', calories: 120, protein: 24, fat: 2),
      _food('fish', 'Meat', calories: 100, protein: 20, fat: 1),
      _food('egg white', 'DairyEgg',
          calories: 50, protein: 10, carbs: 0.7, maximum: 200),
      _food('apple', 'Fruit',
          calories: 50, protein: 0.5, carbs: 12, maximum: 200),
      _food('broccoli', 'Veggie', calories: 25, protein: 2, carbs: 5),
      _food('olive oil', 'Fat', calories: 884, fat: 100, maximum: 20),
    ];

Map<String, dynamic> _meals(Map<String, dynamic> plan) =>
    plan['meals'] as Map<String, dynamic>;

List<Map<String, dynamic>> _items(dynamic meal) =>
    (meal as Map<String, dynamic>)['items'] as List<Map<String, dynamic>>;

void main() {
  test('complete plans keep their contract, totals and portion constraints',
      () {
    final plan = generateMealPlan(
      _foods(),
      dailyCalories: 1600,
      bodyWeightKg: 70,
      seed: 42,
    );
    final meals = _meals(plan);
    expect(meals.keys, ['Breakfast', 'Lunch', 'Dinner']);
    final expectedGroups = {
      'Breakfast': {'starch', 'dairyegg', 'fruit'},
      'Lunch': {'starch', 'meat', 'veggie'},
      'Dinner': {'starch', 'meat', 'veggie'},
    };
    for (final entry in meals.entries) {
      final meal = entry.value as Map<String, dynamic>;
      final items = _items(meal);
      expect(
        items.map((item) => item['food_group']).toSet(),
        containsAll(expectedGroups[entry.key]!),
      );
      expect(
        meal['calo'] as double,
        lessThanOrEqualTo((meal['target_calo'] as double) * 1.12 + 0.02),
      );
      for (final item in items) {
        expect(item['portion_g'], greaterThan(0));
        expect(item['portion_g'], lessThanOrEqualTo(item['max_amount_g']));
        expect(item['display_name'], '${item['portion_g']}g ${item['name']}');
        if (item['food_group'] == 'fat') {
          expect(item['portion_g'], lessThanOrEqualTo(15));
        }
      }
      for (final metric in {
        'calo': 'serving_calo',
        'protein': 'serving_protein',
        'carb': 'serving_carb',
        'fat': 'serving_fat',
      }.entries) {
        final sum = items.fold<double>(
          0,
          (value, item) => value + (item[metric.value] as double),
        );
        expect(meal[metric.key], closeTo(sum, 0.011));
      }
    }
    for (final metric in {
      'total_calo': 'calo',
      'total_protein': 'protein',
      'total_carb': 'carb',
      'total_fat': 'fat',
    }.entries) {
      final sum = meals.values.fold<double>(
        0,
        (value, meal) => value + (meal[metric.value] as double),
      );
      expect(plan[metric.key], closeTo(sum, 0.011));
    }
    expect(plan['protein_target'], 126);
    expect(
      plan['calorie_difference'],
      closeTo((plan['total_calo'] as double) - 1600, 0.011),
    );
    expect(
      plan['protein_difference'],
      closeTo((plan['total_protein'] as double) - 126, 0.011),
    );
    // The offline result must continue to parse through the UI/history model.
    final parsed = MealPlan.fromJson(jsonDecode(jsonEncode(plan)));
    expect(parsed.meals.length, 3);
    expect(parsed.totalCalories, plan['total_calo']);
  });

  test('lunch and dinner use different starches and proteins when available',
      () {
    final meals = _meals(generateMealPlan(
      _foods(),
      dailyCalories: 1600,
      bodyWeightKg: 70,
      seed: 42,
    ));
    for (final group in ['starch', 'meat']) {
      final lunch = _items(meals['Lunch'])
          .where((item) => item['food_group'] == group)
          .map((item) => item['name'])
          .toSet();
      final dinner = _items(meals['Dinner'])
          .where((item) => item['food_group'] == group)
          .map((item) => item['name'])
          .toSet();
      expect(lunch.intersection(dinner), isEmpty);
    }
  });

  test('a single available starch/protein is reused instead of failing', () {
    final foods = _foods()
      ..removeWhere((food) => ['potato', 'fish'].contains(food['name']));
    final meals = _meals(generateMealPlan(
      foods,
      dailyCalories: 1600,
      bodyWeightKg: 70,
      seed: 1,
    ));
    expect(meals.length, 3);
    expect(_items(meals['Dinner']).map((item) => item['name']),
        containsAll(['rice', 'chicken']));
  });

  test('concentrated foods retain a dataset maximum below the group minimum',
      () {
    final meal = branchAndBoundMeal(
      [
        MealCandidateGroup(
          group: 'meat',
          foods: [
            _food('Concentrated food', 'Meat',
                calories: 100, protein: 30, maximum: 30),
          ],
        ),
      ],
      targetCalories: 100,
      targetProtein: 9,
    );
    final item = _items(meal).single;
    expect(item['portion_g'], 30);
    expect(item['serving_calo'], 30);
    expect(item['serving_protein'], 9);
    expect(meal['score'], 80);
  });

  test('protein shortage and macro penalties match the Python objective', () {
    final meal = branchAndBoundMeal(
      [
        MealCandidateGroup(
          group: 'meat',
          foods: [
            _food('protein rich', 'Meat',
                calories: 200, protein: 30, fat: 9, maximum: 100),
            _food('low protein', 'Meat',
                calories: 100, protein: 10, carbs: 10, maximum: 100),
          ],
        ),
      ],
      targetCalories: 200,
      targetProtein: 30,
    );
    expect(_items(meal).single['name'], 'protein rich');
    // Carb penalty: 0.20 * 50; fat penalty: (81 / 200 - 0.40) * 50.
    expect(meal['score'], 10.25);
  });

  test('optional fat may be omitted and never makes a required group optional',
      () {
    final meal = branchAndBoundMeal(
      [
        MealCandidateGroup(
          group: 'meat',
          foods: [
            _food('lean meat', 'Meat',
                calories: 100, protein: 20, maximum: 100),
          ],
        ),
        MealCandidateGroup(
          group: 'fat',
          optional: true,
          foods: [
            _food('oil', 'Fat', calories: 900, fat: 100, maximum: 20),
          ],
        ),
      ],
      targetCalories: 100,
      targetProtein: 20,
    );
    expect(_items(meal).map((item) => item['food_group']), ['meat']);
    expect(meal['calo'], 100);
  });

  test('missing groups and calorie-infeasible meals fail explicitly', () {
    final missingFruit = _foods()
      ..removeWhere((food) => food['macro_group'] == 'Fruit');
    expect(
      () => generateMealPlan(
        missingFruit,
        dailyCalories: 1600,
        bodyWeightKg: 70,
      ),
      throwsArgumentError,
    );
    expect(
      () => generateMealPlan(
        _foods(),
        dailyCalories: 10,
        bodyWeightKg: 70,
      ),
      throwsArgumentError,
    );
  });

  test('rejects empty food lists and non-positive/non-finite targets', () {
    expect(
      () => generateMealPlan([], dailyCalories: 1600, bodyWeightKg: 70),
      throwsArgumentError,
    );
    for (final badValue in [0.0, -1.0, double.nan, double.infinity]) {
      expect(
        () => generateMealPlan(
          _foods(),
          dailyCalories: badValue,
          bodyWeightKg: 70,
        ),
        throwsArgumentError,
      );
      expect(
        () => generateMealPlan(
          _foods(),
          dailyCalories: 1600,
          bodyWeightKg: badValue,
        ),
        throwsArgumentError,
      );
      expect(
        () => generateMealPlan(
          _foods(),
          dailyCalories: 1600,
          bodyWeightKg: 70,
          proteinPerKg: badValue,
        ),
        throwsArgumentError,
      );
    }
  });

  test('seeded candidate sampling is repeatable and inputs are not mutated',
      () {
    final foods = _foods();
    for (var index = 0; index < 7; index++) {
      foods.add(_food(
        'extra fruit $index',
        'Fruit',
        calories: 45 + index.toDouble(),
        protein: 0.5,
        carbs: 10 + index.toDouble(),
        maximum: 200,
      ));
    }
    final original = jsonEncode(foods);
    final first = generateMealPlan(
      foods,
      dailyCalories: 1600,
      bodyWeightKg: 70,
      seed: 123,
    )..remove('time');
    final second = generateMealPlan(
      foods,
      dailyCalories: 1600,
      bodyWeightKg: 70,
      seed: 123,
    )..remove('time');
    expect(second, equals(first));
    expect(jsonEncode(foods), original);
  });
}
