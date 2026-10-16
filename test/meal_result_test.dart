import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optifit/models/recommendation_models.dart';
import 'package:optifit/widgets/meal_result.dart';

import 'helpers/localized_app.dart';

DietRecommendation _result({double calories = 2000, double protein = 120}) =>
    DietRecommendation.fromJson({
      'bmr': 1600,
      'tdee': 2400,
      'target_calories': 2000,
      'data': {
        'protein_target': 120,
        'total_calo': calories,
        'total_protein': protein,
        'total_carb': 220,
        'total_fat': 60,
        'meals': {
          'Breakfast': {
            'calo': calories,
            'protein': protein,
            'carb': 220,
            'fat': 60,
            'items': [
              {'name': 'Oats'}
            ]
          }
        }
      },
    });

void main() {
  test(
      'plan status checks both targets and includes exact tolerance boundaries',
      () {
    expect(
        _result(calories: 1900, protein: 108).plan.meetsTargets(2000), isTrue);
    expect(_result(calories: 1899).plan.meetsTargets(2000), isFalse);
    expect(_result(protein: 107).plan.meetsTargets(2000), isFalse);
    expect(_result(protein: 133).plan.meetsTargets(2000), isFalse);
    expect(_result(calories: 2101).plan.meetsTargets(2000), isFalse);
  });

  test(
      'an old saved response retains its original targets and signed deviations',
      () {
    final result = _result(calories: 1800, protein: 100);
    expect(result.plan.calorieDifference(result.targetCalories), -200);
    expect(result.plan.calorieDeviationPercent(result.targetCalories), -10);
    expect(result.plan.proteinDifference, -20);
  });

  testWidgets('below-target plan clearly shows actual values and its shortfall',
      (tester) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(localizedApp(
        home: Scaffold(
            body: ListView(children: [
      MealResult(recommendation: _result(calories: 1800, protein: 100)),
    ]))));
    expect(find.text('Chưa đạt khoảng mục tiêu'), findsOneWidget);
    expect(find.text('Calo: 1.800 / 2.000 kcal'), findsOneWidget);
    expect(find.text('Lệch -200 kcal (-10,0%)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
