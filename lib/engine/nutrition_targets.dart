import '../models/user_profile.dart';

/// Calculates starting estimates for this app, rather than clinical prescriptions.
///
/// The goal factors (0.90/1.00/1.10) are product assumptions. The 1000 kcal lower
/// bound is an input guardrail, not a claim that this intake suits every adult.
/// Explicit manual targets replace their corresponding estimate independently.
Map<String, dynamic> calculateNutritionTargets(UserProfile profile) {
  profile.validate();
  final bmr = 10 * profile.weight +
      6.25 * profile.height -
      5 * profile.age +
      (profile.gender == 'male' ? 5 : -161);
  final tdee = bmr * profile.activityLevel;
  if (!bmr.isFinite || !tdee.isFinite || bmr <= 0 || tdee <= 0) {
    throw ArgumentError('Calculated BMR and TDEE must be greater than 0.');
  }
  final multiplier = switch (profile.goal) {
    NutritionGoal.lose => 0.90,
    NutritionGoal.maintain => 1.0,
    NutritionGoal.gain => 1.10,
  };
  int roundHalfUp(double value) => (value + 0.5).floor();
  final estimatedCalories = roundHalfUp(tdee * multiplier);
  final estimatedProtein = profile.weight * 1.8;
  final calories = profile.calorieOverride ?? estimatedCalories.toDouble();
  final protein = profile.proteinOverride ?? estimatedProtein;
  if (!calories.isFinite || calories < 1000 || calories > 10000) {
    throw ArgumentError('Calorie target must be between 1000 and 10000 kcal. '
        'Review your profile or enter a manual target.');
  }
  if (!protein.isFinite || protein <= 0 || protein > 500) {
    throw ArgumentError(
        'Protein target must be greater than 0 and at most 500 g. '
        'Review your profile or enter a manual target.');
  }
  if (protein * 4 > calories) {
    throw ArgumentError('Protein energy cannot exceed the calorie target.');
  }
  return {
    'bmr': roundHalfUp(bmr),
    'tdee': roundHalfUp(tdee),
    'target_calories': calories,
    'protein_target': protein,
    'goal': profile.goal.name,
    'calorie_source': profile.calorieOverride == null ? 'estimated' : 'manual',
    'protein_source': profile.proteinOverride == null ? 'estimated' : 'manual',
    'estimated_calories': estimatedCalories,
    'estimated_protein': estimatedProtein,
  };
}
