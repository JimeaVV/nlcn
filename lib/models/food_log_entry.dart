/// Meal slots in the intake diary; generated plans fill the first three.
enum MealSlot { breakfast, lunch, dinner, snack }

/// Where a diary entry came from. [camera] is reserved for on-device food
/// recognition, which will also record the model's [FoodLogEntry.confidence].
enum FoodLogSource { manual, mealPlan, camera }

/// The calendar-day key stored in SQLite, e.g. 2026-10-16 (local time).
String diaryDateKey(DateTime value) {
  final date = value.toLocal();
  String pad(int value) => value.toString().padLeft(2, '0');
  return '${date.year.toString().padLeft(4, '0')}-${pad(date.month)}-'
      '${pad(date.day)}';
}

/// One food the user ate. Nutrition is a snapshot taken when it was logged,
/// so later dataset updates never change past days.
class FoodLogEntry {
  const FoodLogEntry({
    this.id,
    required this.date,
    required this.meal,
    required this.name,
    this.grams,
    required this.calories,
    required this.protein,
    this.carbs = 0,
    this.fat = 0,
    this.source = FoodLogSource.manual,
    this.confidence,
    this.createdAt,
  });

  /// Scales a dataset food, whose values are per 100 g, to [grams].
  factory FoodLogEntry.fromFood(
    Map<String, dynamic> food, {
    required double grams,
    required DateTime date,
    required MealSlot meal,
    FoodLogSource source = FoodLogSource.manual,
    double? confidence,
  }) {
    double per100(String key) {
      final value = food[key];
      return value is num ? value.toDouble() * grams / 100 : 0;
    }

    return FoodLogEntry(
      date: DateTime(date.year, date.month, date.day),
      meal: meal,
      name: '${food['name'] ?? ''}'.trim(),
      grams: grams,
      calories: per100('calories_per_100g'),
      protein: per100('protein_g'),
      carbs: per100('carb_g'),
      fat: per100('fat_g'),
      source: source,
      confidence: confidence,
    );
  }

  factory FoodLogEntry.fromMap(Map<String, dynamic> row) {
    final date = DateTime.tryParse('${row['logged_date']}');
    if (date == null) throw const FormatException('Invalid diary date.');
    double number(String key) {
      final value = row[key];
      if (value is! num) throw FormatException('Invalid diary value: $key.');
      return value.toDouble();
    }

    T byName<T extends Enum>(List<T> values, String key) => values.firstWhere(
          (value) => value.name == row[key],
          orElse: () => throw FormatException('Invalid diary value: $key.'),
        );

    return FoodLogEntry(
      id: row['id'] as int?,
      date: date,
      meal: byName(MealSlot.values, 'meal'),
      name: '${row['food_name'] ?? ''}',
      grams: (row['grams'] as num?)?.toDouble(),
      calories: number('calories'),
      protein: number('protein'),
      carbs: number('carbs'),
      fat: number('fat'),
      source: byName(FoodLogSource.values, 'source'),
      confidence: (row['confidence'] as num?)?.toDouble(),
      createdAt: DateTime.tryParse('${row['created_at']}'),
    );
  }

  final int? id;
  final DateTime date;
  final MealSlot meal;
  final String name;

  /// Null when the portion is unknown, e.g. a custom dish logged by calories.
  final double? grams;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final FoodLogSource source;

  /// Recognition confidence between 0 and 1; only set for camera entries.
  final double? confidence;
  final DateTime? createdAt;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'logged_date': diaryDateKey(date),
        'meal': meal.name,
        'food_name': name.trim(),
        'grams': grams,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'source': source.name,
        'confidence': confidence,
        'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
      };

  /// The same food without its database id, used to undo a deletion.
  FoodLogEntry withoutId() => FoodLogEntry(
        date: date,
        meal: meal,
        name: name,
        grams: grams,
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
        source: source,
        confidence: confidence,
        createdAt: createdAt,
      );

  void validate() {
    if (name.trim().isEmpty || name.runes.length > 200) {
      throw ArgumentError('Food name must contain 1 to 200 characters.');
    }
    final portion = grams;
    if (portion != null &&
        (!portion.isFinite || portion <= 0 || portion > 5000)) {
      throw ArgumentError('Portion must be greater than 0 and at most 5000 g.');
    }
    if (!calories.isFinite || calories < 0 || calories > 10000) {
      throw ArgumentError('Calories must be between 0 and 10000 kcal.');
    }
    for (final value in [protein, carbs, fat]) {
      if (!value.isFinite || value < 0 || value > 1000) {
        throw ArgumentError('Macronutrients must be between 0 and 1000 g.');
      }
    }
    final score = confidence;
    if (score != null && (!score.isFinite || score < 0 || score > 1)) {
      throw ArgumentError('Confidence must be between 0 and 1.');
    }
  }
}

/// Totals for one day of the diary.
class FoodLogTotals {
  const FoodLogTotals({
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
  });

  factory FoodLogTotals.of(Iterable<FoodLogEntry> entries) => entries.fold(
        const FoodLogTotals(),
        (total, entry) => FoodLogTotals(
          calories: total.calories + entry.calories,
          protein: total.protein + entry.protein,
          carbs: total.carbs + entry.carbs,
          fat: total.fat + entry.fat,
        ),
      );

  final double calories;
  final double protein;
  final double carbs;
  final double fat;
}
