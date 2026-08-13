import 'package:flutter_test/flutter_test.dart';
import 'package:optifit/models/recommendation_models.dart';

void main() {
  test('DietRecommendation parses nested meal data', () {
    final recommendation = DietRecommendation.fromJson({
      'bmr': 1694,
      'tdee': 2625,
      'target_calories': 2125,
      'data': {
        'protein_target': 126,
        'total_calo': 2100,
        'total_protein': 130,
        'total_carb': 220,
        'total_fat': 60,
        'meals': {
          'Breakfast': {
            'calo': 630,
            'protein': 39,
            'carb': 80,
            'fat': 17,
            'items': [
              {'name': 'Oats', 'display_name': '100g oats'},
            ],
          },
        },
      },
    });

    expect(recommendation.targetCalories, 2125);
    expect(recommendation.plan.meals['Breakfast']?.items.first.displayName,
        '100g oats');
  });

  test('WorkoutRecommendation rejects an empty exercise list', () {
    expect(
      () => WorkoutRecommendation.fromJson({
        'target_time': 45,
        'estimated_time': 0,
        'total_exercises': 0,
        'data': <dynamic>[],
      }),
      throwsFormatException,
    );
  });
}
