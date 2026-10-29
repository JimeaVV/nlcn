import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:optifit/engine/recommendation_engine.dart';
import 'package:optifit/engine/vn_meal_planner.dart';
import 'package:optifit/models/recommendation_models.dart';
import 'package:optifit/models/user_profile.dart';
import 'package:optifit/models/vn_food.dart';

String _read(String name) =>
    File('assets/data/vn_food/$name.csv').readAsStringSync();

void main() {
  final data = parseVnFoodData(
    componentsCsv: _read('components'),
    dishesCsv: _read('dishes'),
    dishNamesCsv: _read('dish_names'),
  );
  final tags = parseMealPlanTags(_read('meal_plan'));

  Map<String, dynamic> plan({
    NutritionGoal goal = NutritionGoal.maintain,
    double calories = 2000,
    double protein = 110,
    int seed = 1,
    String language = 'vi',
    int nodeBudget = defaultNodeBudget,
    bool calorieBound = true,
  }) =>
      generateVnMealPlan(
        data,
        tags,
        dailyCalories: calories,
        proteinTarget: protein,
        bodyWeightKg: 65,
        goal: goal,
        seed: seed,
        languageCode: language,
        nodeBudget: nodeBudget,
        calorieBound: calorieBound,
      );

  List<Map<String, dynamic>> items(Map<String, dynamic> day, String meal) => [
        for (final item in (day['meals'][meal]['items'] as List))
          item as Map<String, dynamic>
      ];

  test('the same seed reproduces a plan and other seeds vary it', () {
    Map<String, dynamic> withoutTime(Map<String, dynamic> day) =>
        Map.of(day)..remove('time');
    expect(withoutTime(plan(seed: 3)), withoutTime(plan(seed: 3)));
    final breakfasts = {
      for (var seed = 0; seed < 8; seed++)
        items(plan(seed: seed), 'Breakfast').first['code'],
    };
    expect(breakfasts.length, greaterThan(1));
  });

  test('a maintenance day mostly lands within the app targets', () {
    var within = 0;
    for (var seed = 0; seed < 10; seed++) {
      final day = plan(seed: seed);
      final recommendation = MealPlan.fromJson(day);
      if (recommendation.meetsTargets(2000)) within++;
    }
    expect(within, greaterThanOrEqualTo(8));
  });

  test('cutting skips heavy breakfasts and keeps rice to 200 g', () {
    const heavy = {
      'pho_bo',
      'pho_ga',
      'banh_mi',
      'xoi',
      'banh_cuon',
      'bun_bo_hue'
    };
    for (var seed = 0; seed < 10; seed++) {
      final day = plan(
          goal: NutritionGoal.lose, calories: 1500, protein: 120, seed: seed);
      for (final item in items(day, 'Breakfast')) {
        expect(heavy, isNot(contains(item['code'])));
      }
      for (final meal in ['Lunch', 'Dinner']) {
        for (final item in items(day, meal)) {
          if (item['code'] == 'com') {
            expect(item['portion_g'], lessThanOrEqualTo(200));
          }
          // Only lean mains are tagged for cutting.
          expect(['thit_kho', 'ga_chien', 'suon_nuong'],
              isNot(contains(item['code'])));
        }
      }
    }
  });

  test('a high target adds a snack and lunch and dinner differ', () {
    expect((plan(calories: 2500)['meals'] as Map).keys,
        ['Breakfast', 'Lunch', 'Dinner']);
    final day = plan(goal: NutritionGoal.gain, calories: 3000, protein: 140);
    expect((day['meals'] as Map).keys, contains('Snack'));
    Set<String> mains(String meal) => {
          for (final item in items(day, meal))
            if (item['food_group'] == 'main') item['code'] as String,
        };
    expect(mains('Lunch').intersection(mains('Dinner')), isEmpty);
  });

  test('the calorie bound prunes nodes without changing the plan', () {
    for (var seed = 0; seed < 5; seed++) {
      final without = plan(seed: seed, calorieBound: false);
      final withBound = plan(seed: seed);
      int nodes(Map<String, dynamic> day) => [
            for (final meal in (day['meals'] as Map).values)
              (meal['search'] as Map)['nodes'] as int,
          ].reduce((a, b) => a + b);
      double score(Map<String, dynamic> day) => [
            for (final meal in (day['meals'] as Map).values)
              (meal['score'] as num).toDouble(),
          ].reduce((a, b) => a + b);
      expect(score(withBound), score(without));
      expect(nodes(withBound), lessThan(nodes(without)));
    }
  });

  test('a tiny node budget still returns a plan and says so', () {
    final day = plan(nodeBudget: 40);
    final lunch = day['meals']['Lunch'] as Map;
    expect((lunch['search'] as Map)['budget_exhausted'], isTrue);
    expect(items(day, 'Lunch'), isNotEmpty);
  });

  test('names follow the language and portions read naturally', () {
    final vi = plan(goal: NutritionGoal.lose, calories: 1500, protein: 120);
    final rice = items(vi, 'Lunch').firstWhere((item) => item['code'] == 'com');
    // People cutting weigh rice; other goals count bowls.
    expect(rice['display_name'], matches(RegExp('^\\d+\u00A0g Cơm\$')));
    final bowls = items(plan(), 'Lunch').firstWhere((i) => i['code'] == 'com');
    expect(bowls['display_name'], matches(RegExp(r'^[\d,]+ chén Cơm$')));
    final en = plan(language: 'en');
    for (final item in items(en, 'Breakfast')) {
      expect(item['name'], data.dish(item['code'] as String)!.nameEn);
    }
  });

  test('the engine returns a plan the app can show and log', () {
    final response = runRecommendation({
      'operation': 'diet',
      ...const UserProfile(
        age: 25,
        gender: 'male',
        height: 172,
        weight: 68,
        activityLevel: 1.55,
      ).toMap(),
      'seed': 5,
      'language': 'vi',
      'vn_tables': {
        for (final name in ['components', 'dishes', 'dish_names', 'meal_plan'])
          name: _read(name),
      },
    });
    final recommendation = DietRecommendation.fromJson(response);
    expect(response['data']['planner'], 'vn');
    final all = [
      for (final meal in recommendation.plan.meals.values) ...meal.items,
    ];
    expect(all, isNotEmpty);
    expect(all.every((item) => item.hasNutrition && item.grams! > 0), isTrue);
  });

  test('the tag table rejects unknown kinds, meals and goals', () {
    expect(
        () =>
            parseMealPlanTags('code,kind,slots,goals\npho_bo,meal,lunch,gain'),
        throwsFormatException);
    expect(
        () =>
            parseMealPlanTags('code,kind,slots,goals\npho_bo,dish,brunch,gain'),
        throwsFormatException);
    expect(
        () =>
            parseMealPlanTags('code,kind,slots,goals\npho_bo,dish,lunch,bulk'),
        throwsFormatException);
  });
}
