// Measures the Vietnamese meal planner for the report.
//
// Run from the project root:
//   dart run tool/bench_meal_planner.dart
//
// For a spread of realistic profiles (two genders, five body weights, three
// activity levels, five seeds each) it reports, per goal:
// - how many daily plans land within the app's targets (calories ±5%,
//   protein -10% to +20%);
// - the Branch & Bound nodes searched with and without the calorie lower
//   bound, and whether both found plans of the same quality.
import 'dart:io';

import 'package:optifit/engine/nutrition_targets.dart';
import 'package:optifit/engine/vn_meal_planner.dart';
import 'package:optifit/models/user_profile.dart';
import 'package:optifit/models/vn_food.dart';

void main() {
  String read(String name) =>
      File('assets/data/vn_food/$name.csv').readAsStringSync();
  final data = parseVnFoodData(
    componentsCsv: read('components'),
    dishesCsv: read('dishes'),
    dishNamesCsv: read('dish_names'),
  );
  final tags = parseMealPlanTags(read('meal_plan'));

  stdout.writeln('| Goal | Plans within target | Nodes, protein bound only | '
      'Nodes, + calorie bound | Fewer nodes | Same plan quality |');
  stdout.writeln('|---|---|---|---|---|---|');
  for (final goal in NutritionGoal.values) {
    var plans = 0, within = 0, sameQuality = 0;
    var nodesWithout = 0, nodesWith = 0;
    final watch = Stopwatch();
    for (final gender in ['male', 'female']) {
      for (final weight in [50.0, 60.0, 70.0, 80.0, 95.0]) {
        for (final activity in [1.2, 1.55, 1.9]) {
          final targets = calculateNutritionTargets(UserProfile(
            age: 22,
            gender: gender,
            height: gender == 'male' ? 172 : 160,
            weight: weight,
            activityLevel: activity,
            goal: goal,
          ));
          final calories = (targets['target_calories'] as num).toDouble();
          final protein = (targets['protein_target'] as num).toDouble();
          for (var seed = 0; seed < 5; seed++) {
            Map<String, dynamic> plan(bool bound) => generateVnMealPlan(
                  data,
                  tags,
                  dailyCalories: calories,
                  proteinTarget: protein,
                  bodyWeightKg: weight,
                  goal: goal,
                  seed: seed,
                  calorieBound: bound,
                );
            final without = plan(false);
            watch.start();
            final withBound = plan(true);
            watch.stop();
            plans++;
            nodesWithout += _nodes(without);
            nodesWith += _nodes(withBound);
            if (_score(without) == _score(withBound)) sameQuality++;
            final kcal = ((withBound['total_calo'] as double) - calories) /
                calories *
                100;
            final pro = ((withBound['total_protein'] as double) - protein) /
                protein *
                100;
            if (kcal.abs() <= 5 && pro >= -10 && pro <= 20) within++;
          }
        }
      }
    }
    final ratio = nodesWithout / nodesWith;
    stdout.writeln('| ${goal.name} | $within/$plans | '
        '${nodesWithout ~/ plans} | ${nodesWith ~/ plans} | '
        '${ratio.toStringAsFixed(1)}× | $sameQuality/$plans |');
    stderr.writeln('${goal.name}: '
        '${(watch.elapsedMicroseconds / plans / 1000).toStringAsFixed(1)} ms '
        'per daily plan with both bounds');
  }
}

int _nodes(Map<String, dynamic> plan) => [
      for (final meal in (plan['meals'] as Map).values)
        ((meal as Map)['search'] as Map)['nodes'] as int,
    ].fold(0, (sum, nodes) => sum + nodes);

double _score(Map<String, dynamic> plan) => [
      for (final meal in (plan['meals'] as Map).values)
        ((meal as Map)['score'] as num).toDouble(),
    ].fold(0.0, (sum, score) => sum + score);
