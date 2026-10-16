Map<String, dynamic> _requiredMap(dynamic value, String field) {
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('$field must be a JSON object.');
}

List<dynamic> _requiredList(dynamic value, String field) {
  if (value is List) return value;
  throw FormatException('$field must be a JSON list.');
}

double _requiredDouble(dynamic value, String field) {
  final number = value is num ? value.toDouble() : double.tryParse('$value');
  if (number == null || !number.isFinite) {
    throw FormatException('$field must be finite and numeric.');
  }
  return number;
}

int _requiredInt(dynamic value, String field) {
  final number = value is num ? value.round() : int.tryParse('$value');
  if (number == null) throw FormatException('$field must be an integer.');
  return number;
}

class DietRecommendation {
  DietRecommendation._({
    required this.rawResponse,
    required this.bmr,
    required this.tdee,
    required this.targetCalories,
    required this.plan,
  });

  factory DietRecommendation.fromJson(Map<String, dynamic> json) {
    return DietRecommendation._(
      rawResponse: Map<String, dynamic>.unmodifiable(json),
      bmr: _requiredDouble(json['bmr'], 'bmr'),
      tdee: _requiredDouble(json['tdee'], 'tdee'),
      targetCalories: _requiredDouble(
        json['target_calories'],
        'target_calories',
      ),
      plan: MealPlan.fromJson(_requiredMap(json['data'], 'data')),
    );
  }

  final Map<String, dynamic> rawResponse;
  final double bmr;
  final double tdee;
  final double targetCalories;
  final MealPlan plan;
}

class MealPlan {
  MealPlan._({
    required this.proteinTarget,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbohydrates,
    required this.totalFat,
    required this.meals,
  });

  factory MealPlan.fromJson(Map<String, dynamic> json) {
    final rawMeals = _requiredMap(json['meals'], 'data.meals');
    final meals = <String, MealRecommendation>{};
    for (final entry in rawMeals.entries) {
      meals[entry.key] = MealRecommendation.fromJson(
        entry.key,
        _requiredMap(entry.value, 'meal ${entry.key}'),
      );
    }
    if (meals.isEmpty) {
      throw const FormatException('The meal plan contains no meals.');
    }

    return MealPlan._(
      proteinTarget: _requiredDouble(
        json['protein_target'],
        'protein_target',
      ),
      totalCalories: _requiredDouble(json['total_calo'], 'total_calo'),
      totalProtein: _requiredDouble(json['total_protein'], 'total_protein'),
      totalCarbohydrates: _requiredDouble(json['total_carb'], 'total_carb'),
      totalFat: _requiredDouble(json['total_fat'], 'total_fat'),
      meals: Map<String, MealRecommendation>.unmodifiable(meals),
    );
  }

  final double proteinTarget;
  final double totalCalories;
  final double totalProtein;
  final double totalCarbohydrates;
  final double totalFat;
  final Map<String, MealRecommendation> meals;

  double calorieDifference(double targetCalories) =>
      totalCalories - targetCalories;
  double calorieDeviationPercent(double targetCalories) => targetCalories > 0
      ? calorieDifference(targetCalories) / targetCalories * 100
      : 0;
  double get proteinDifference => totalProtein - proteinTarget;
  double get proteinDeviationPercent =>
      proteinTarget > 0 ? proteinDifference / proteinTarget * 100 : 0;

  // A product quality check for the generated plan, not a nutritional safety score.
  bool meetsTargets(double targetCalories) =>
      calorieDeviationPercent(targetCalories).abs() <= 5 &&
      proteinDeviationPercent.abs() <= 10;
}

class MealRecommendation {
  MealRecommendation._({
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fat,
    required this.items,
  });

  factory MealRecommendation.fromJson(
    String name,
    Map<String, dynamic> json,
  ) {
    final items = _requiredList(json['items'], '$name.items')
        .map(
          (item) => FoodItem.fromJson(
            _requiredMap(item, '$name food item'),
          ),
        )
        .toList(growable: false);

    return MealRecommendation._(
      name: name,
      calories: _requiredDouble(json['calo'], '$name.calo'),
      protein: _requiredDouble(json['protein'], '$name.protein'),
      carbohydrates: _requiredDouble(json['carb'], '$name.carb'),
      fat: _requiredDouble(json['fat'], '$name.fat'),
      items: items,
    );
  }

  final String name;
  final double calories;
  final double protein;
  final double carbohydrates;
  final double fat;
  final List<FoodItem> items;
}

class FoodItem {
  const FoodItem({
    required this.displayName,
    required this.suggestedPrep,
    this.name = '',
    this.grams,
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    final name = '${json['display_name'] ?? json['name'] ?? ''}'.trim();
    if (name.isEmpty) throw const FormatException('Food name is missing.');
    double? optional(String key) {
      final value = json[key];
      return value is num && value.isFinite ? value.toDouble() : null;
    }

    return FoodItem(
      displayName: name,
      suggestedPrep: '${json['suggested_prep'] ?? ''}'.trim(),
      name: '${json['name'] ?? name}'.trim(),
      grams: optional('portion_g'),
      calories: optional('serving_calo'),
      protein: optional('serving_protein'),
      carbs: optional('serving_carb'),
      fat: optional('serving_fat'),
    );
  }

  final String displayName;
  final String suggestedPrep;

  /// Food name without the portion prefix of [displayName].
  final String name;

  /// Portion nutrition; absent in plans saved before the diary existed.
  final double? grams;
  final double? calories;
  final double? protein;
  final double? carbs;
  final double? fat;

  bool get hasNutrition => calories != null && protein != null;
}

class WorkoutRecommendation {
  WorkoutRecommendation._({
    required this.rawResponse,
    required this.targetTime,
    required this.estimatedTime,
    required this.totalExercises,
    required this.note,
    required this.requestedLevel,
    required this.usedLevels,
    required this.levelFallbackUsed,
    required this.exercises,
  });

  factory WorkoutRecommendation.fromJson(Map<String, dynamic> json) {
    final exercises = _requiredList(json['data'], 'data')
        .map(
          (item) => ExerciseRecommendation.fromJson(
            _requiredMap(item, 'exercise'),
          ),
        )
        .toList(growable: false);
    if (exercises.isEmpty) {
      throw const FormatException('The workout contains no exercises.');
    }

    return WorkoutRecommendation._(
      rawResponse: Map<String, dynamic>.unmodifiable(json),
      targetTime: _requiredInt(json['target_time'], 'target_time'),
      estimatedTime: _requiredInt(json['estimated_time'], 'estimated_time'),
      totalExercises: _requiredInt(
        json['total_exercises'],
        'total_exercises',
      ),
      note: '${json['note'] ?? ''}'.trim(),
      requestedLevel: '${json['requested_level'] ?? ''}',
      usedLevels: List<String>.unmodifiable(
        (json['used_levels'] as List? ?? []).map((level) => '$level'),
      ),
      levelFallbackUsed: json['level_fallback_used'] == true,
      exercises: exercises,
    );
  }

  final Map<String, dynamic> rawResponse;
  final int targetTime;
  final int estimatedTime;
  final int totalExercises;
  final String note;
  final String requestedLevel;
  final List<String> usedLevels;
  final bool levelFallbackUsed;
  final List<ExerciseRecommendation> exercises;
}

class ExerciseRecommendation {
  const ExerciseRecommendation({
    required this.name,
    required this.muscleGroup,
    required this.equipment,
    required this.level,
    required this.estimatedMinutes,
  });

  factory ExerciseRecommendation.fromJson(Map<String, dynamic> json) {
    final name = '${json['name'] ?? ''}'.trim();
    if (name.isEmpty) throw const FormatException('Exercise name is missing.');
    return ExerciseRecommendation(
      name: name,
      muscleGroup: '${json['muscle_group'] ?? 'Unknown'}',
      equipment: '${json['equipment'] ?? 'Unknown'}',
      level: '${json['level'] ?? 'Unknown'}',
      estimatedMinutes: _requiredInt(
        json['estimated_time_mins'],
        'estimated_time_mins',
      ),
    );
  }

  final String name;
  final String muscleGroup;
  final String equipment;
  final String level;
  final int estimatedMinutes;
}

class ProgressiveOverloadRecommendation {
  ProgressiveOverloadRecommendation._({
    required this.rawResponse,
    required this.nextWeight,
    required this.nextRepTarget,
    required this.action,
    required this.message,
  });

  factory ProgressiveOverloadRecommendation.fromJson(
    Map<String, dynamic> json,
  ) {
    final data = _requiredMap(json['data'], 'data');
    final message = '${data['message'] ?? ''}'.trim();
    if (message.isEmpty) {
      throw const FormatException('Progressive Overload message is missing.');
    }
    return ProgressiveOverloadRecommendation._(
      rawResponse: Map<String, dynamic>.unmodifiable(json),
      nextWeight: _requiredDouble(data['next_weight'], 'next_weight'),
      nextRepTarget: _requiredInt(data['next_rep_target'], 'next_rep_target'),
      action: '${data['action'] ?? ''}',
      message: message,
    );
  }

  final Map<String, dynamic> rawResponse;
  final double nextWeight;
  final int nextRepTarget;
  final String action;
  final String message;
}
