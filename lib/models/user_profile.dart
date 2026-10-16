enum NutritionGoal { lose, maintain, gain }

extension NutritionGoalLabel on NutritionGoal {
  String get label => switch (this) {
        NutritionGoal.lose => 'Giảm mỡ',
        NutritionGoal.maintain => 'Giữ cân',
        NutritionGoal.gain => 'Tăng cân',
      };
}

const profileActivityFactors = [1.2, 1.375, 1.55, 1.725, 1.9];

class UserProfile {
  const UserProfile({
    required this.age,
    required this.gender,
    required this.height,
    required this.weight,
    required this.activityLevel,
    this.goal = NutritionGoal.maintain,
    this.calorieOverride,
    this.proteinOverride,
    this.updatedAt,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    final rawAge = _number(map['age'], 'Age');
    if (!rawAge.isFinite || rawAge != rawAge.truncateToDouble()) {
      throw ArgumentError('Age must be a whole number.');
    }
    final rawGoal = map['goal'];
    // Earlier profiles belonged to the old deficit-only recommendation flow.
    final goal = rawGoal == null
        ? NutritionGoal.lose
        : NutritionGoal.values.firstWhere(
            (goal) => goal.name == rawGoal,
            orElse: () =>
                throw ArgumentError('Nutrition goal is not supported.'),
          );
    final rawUpdatedAt = map['updated_at'];
    final updatedAt = rawUpdatedAt == null
        ? null
        : rawUpdatedAt is DateTime
            ? rawUpdatedAt
            : DateTime.tryParse('$rawUpdatedAt');
    if (rawUpdatedAt != null && updatedAt == null) {
      throw ArgumentError('Profile update date is invalid.');
    }
    return UserProfile(
      age: rawAge.toInt(),
      gender: '${map['gender'] ?? ''}',
      height: _number(map['height'], 'Height'),
      weight: _number(map['weight'], 'Weight'),
      activityLevel: _number(map['activity_level'], 'Activity level'),
      goal: goal,
      calorieOverride: map['calorie_override'] == null
          ? null
          : _number(map['calorie_override'], 'Manual calories'),
      proteinOverride: map['protein_override'] == null
          ? null
          : _number(map['protein_override'], 'Manual protein'),
      updatedAt: updatedAt,
    );
  }

  final int age;
  final String gender;
  final double height;
  final double weight;
  final double activityLevel;
  final NutritionGoal goal;
  final double? calorieOverride;
  final double? proteinOverride;
  final DateTime? updatedAt;

  Map<String, dynamic> toMap() => {
        'age': age,
        'gender': gender,
        'height': height,
        'weight': weight,
        'activity_level': activityLevel,
        'goal': goal.name,
        'calorie_override': calorieOverride,
        'protein_override': proteinOverride,
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      };

  /// Validates entered values. Target feasibility is checked by the calculator.
  void validate() {
    if (age < 18 || age > 100) {
      throw ArgumentError('Age must be between 18 and 100.');
    }
    if (gender != 'male' && gender != 'female') {
      throw ArgumentError('Gender must be male or female.');
    }
    if (!height.isFinite || height <= 0 || height > 300) {
      throw ArgumentError('Height must be greater than 0 and at most 300 cm.');
    }
    if (!weight.isFinite || weight <= 0 || weight > 500) {
      throw ArgumentError('Weight must be greater than 0 and at most 500 kg.');
    }
    if (!activityLevel.isFinite ||
        !profileActivityFactors.contains(activityLevel)) {
      throw ArgumentError('Activity level is not supported.');
    }
    final calories = calorieOverride;
    if (calories != null &&
        (!calories.isFinite || calories < 1000 || calories > 10000)) {
      throw ArgumentError(
          'Manual calories must be between 1000 and 10000 kcal.');
    }
    final protein = proteinOverride;
    if (protein != null &&
        (!protein.isFinite || protein <= 0 || protein > 500)) {
      throw ArgumentError(
          'Manual protein must be greater than 0 and at most 500 g.');
    }
  }
}

double _number(dynamic value, String name) {
  final number = value is num ? value.toDouble() : double.tryParse('$value');
  if (number == null) throw ArgumentError('$name must be numeric.');
  return number;
}
