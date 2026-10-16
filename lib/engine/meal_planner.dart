import 'dart:math' as math;

import 'number_utils.dart';

const _timeLimit = Duration(milliseconds: 1500);
const _calorieOvershootRatio = 1.12;
const _proteinShortageWeight = 120.0;
const _proteinExcessWeight = 15.0;
const _proteinExcessRatio = 1.20;

const _mealRatios = {'Breakfast': 0.30, 'Lunch': 0.35, 'Dinner': 0.35};
const _requiredGroups = {
  'Breakfast': ['starch', 'dairyegg', 'fruit'],
  'Lunch': ['starch', 'meat', 'veggie'],
  'Dinner': ['starch', 'meat', 'veggie'],
};
const _portionRanges = {
  'starch': (75, 250),
  'meat': (100, 250),
  'dairyegg': (50, 250),
  'veggie': (100, 250),
  'fruit': (75, 200),
  'fat': (0, 15),
};
const _lunchDinnerStarchKeywords = [
  'rice',
  'potato',
  'sweet potato',
  'quinoa',
  'bread',
  'pasta',
  'noodle',
  'couscous',
  'barley',
  'corn',
];

/// The dataset or search could not produce a meal for otherwise valid targets.
class MealPlanUnavailableError extends ArgumentError {
  MealPlanUnavailableError(String super.message);
}

/// One required or optional food group for [branchAndBoundMeal].
class MealCandidateGroup {
  const MealCandidateGroup({
    required this.group,
    required this.foods,
    this.optional = false,
  });

  final String group;
  final List<Map<String, dynamic>> foods;
  final bool optional;
}

/// Produces the same meal-plan map consumed by the existing app models.
///
/// Ranking, portions, nutrition penalties and meal ratios follow the Python
/// engine. Portion nutrition is calculated once, before searching. The search
/// retains the original 1.5-second limit for each meal; callers should execute
/// it on a worker isolate. A seed fixes candidate sampling, although a search
/// stopped by its time limit may still differ between devices.
Map<String, dynamic> generateMealPlan(
  List<Map<String, dynamic>> foodList, {
  required double dailyCalories,
  required double bodyWeightKg,
  double proteinPerKg = 1.8,
  double? proteinTarget,
  int? seed,
}) {
  if (foodList.isEmpty) throw ArgumentError('Food list is empty.');
  _requirePositive(dailyCalories, 'Daily calories');
  _requirePositive(bodyWeightKg, 'Body weight');
  _requirePositive(proteinPerKg, 'Protein per kg');
  final dailyProteinTarget = proteinTarget ?? bodyWeightKg * proteinPerKg;
  _requirePositive(dailyProteinTarget, 'Daily protein target');

  final pools = _preparePools(foodList);
  final rng = math.Random(seed);
  final meals = <String, dynamic>{};
  final usedStarches = <String>{};
  final usedProteins = <String>{};
  var totalCalories = 0.0;
  var totalProtein = 0.0;
  var totalCarbs = 0.0;
  var totalFat = 0.0;
  final stopwatch = Stopwatch()..start();

  for (final entry in _mealRatios.entries) {
    final groups = _mealCandidateGroups(
      pools,
      entry.key,
      rng,
      usedStarches,
      usedProteins,
    );
    final meal = _searchMeal(
      groups,
      dailyCalories * entry.value,
      dailyProteinTarget * entry.value,
      _timeLimit,
    );
    meals[entry.key] = meal;

    if (entry.key == 'Lunch' || entry.key == 'Dinner') {
      for (final item in meal['items'] as List<Map<String, dynamic>>) {
        final name = '${item['name'] ?? ''}'.trim().toLowerCase();
        if (item['food_group'] == 'starch') usedStarches.add(name);
        if (item['food_group'] == 'meat') usedProteins.add(name);
      }
    }
    totalCalories += meal['calo'] as double;
    totalProtein += meal['protein'] as double;
    totalCarbs += meal['carb'] as double;
    totalFat += meal['fat'] as double;
  }

  totalCalories = _round(totalCalories);
  totalProtein = _round(totalProtein);
  return {
    'meals': meals,
    'target_calo': _round(dailyCalories),
    'protein_target': _round(dailyProteinTarget),
    'protein_per_kg': _round(dailyProteinTarget / bodyWeightKg),
    'body_weight_kg': _round(bodyWeightKg),
    'total_calo': totalCalories,
    'total_protein': totalProtein,
    'total_carb': _round(totalCarbs),
    'total_fat': _round(totalFat),
    'calorie_difference': _round(totalCalories - dailyCalories),
    'protein_difference': _round(totalProtein - dailyProteinTarget),
    'time': _round(stopwatch.elapsedMicroseconds / 1000000, 6),
  };
}

/// Searches the supplied groups without sampling, useful for focused checks.
Map<String, dynamic> branchAndBoundMeal(
  List<MealCandidateGroup> candidateGroups, {
  required double targetCalories,
  required double targetProtein,
  Duration timeLimit = _timeLimit,
}) {
  _requirePositive(targetCalories, 'Target calories');
  if (!targetProtein.isFinite || targetProtein < 0) {
    throw ArgumentError('Target protein must be finite and non-negative.');
  }
  if (timeLimit <= Duration.zero) {
    throw ArgumentError('Search time limit must be greater than 0.');
  }
  final groups = candidateGroups.map((candidate) {
    final group = candidate.group.trim().toLowerCase();
    if (!_portionRanges.containsKey(group)) {
      throw ArgumentError('Unknown food group: ${candidate.group}');
    }
    final foods = candidate.foods
        .where(_isUsableFood)
        .map((food) => _PreparedFood(food, group))
        .toList(growable: false);
    return _PreparedGroup(group, foods, candidate.optional);
  }).toList(growable: false);
  return _searchMeal(groups, targetCalories, targetProtein, timeLimit);
}

void _requirePositive(double value, String field) {
  if (!value.isFinite || value <= 0) {
    throw ArgumentError('$field must be finite and greater than 0.');
  }
}

double _number(dynamic value, [double fallback = 0]) {
  final parsed = value is num ? value.toDouble() : double.tryParse('$value');
  return parsed != null && parsed.isFinite ? parsed : fallback;
}

double _round(double value, [int digits = 2]) =>
    roundLikePython(value, digits: digits);

bool _isUsableFood(Map<String, dynamic> food) =>
    '${food['name'] ?? ''}'.trim().isNotEmpty &&
    _number(food['calories_per_100g']) > 0 &&
    _number(food['max_amount_g']) > 0;

Map<String, List<_PreparedFood>> _preparePools(
  List<Map<String, dynamic>> foodList,
) {
  final pools = {
    for (final group in _portionRanges.keys) group: <_PreparedFood>[],
  };
  final seen = <String>{};
  for (final food in foodList) {
    final name = '${food['name'] ?? ''}'.trim().toLowerCase();
    final group = '${food['macro_group'] ?? ''}'.trim().toLowerCase();
    if (seen.contains(name) ||
        !pools.containsKey(group) ||
        !_isUsableFood(food)) {
      continue;
    }
    seen.add(name);
    pools[group]!.add(_PreparedFood(food, group));
  }
  return pools;
}

class _PreparedFood {
  _PreparedFood(Map<String, dynamic> source, this.group)
      : data = Map<String, dynamic>.from(source),
        name = '${source['name'] ?? ''}'.trim(),
        calories = _number(source['calories_per_100g']),
        protein = _number(source['protein_g']),
        carbs = _number(source['carb_g']),
        fat = _number(source['fat_g']) {
    normalizedName = name.toLowerCase();
    isCheese = normalizedName.contains('cheese');
    portions = [
      for (final grams in _portionOptions(data, group))
        if (grams > 0) _Portion(this, grams),
    ];
  }

  final Map<String, dynamic> data;
  final String name;
  final String group;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  late final String normalizedName;
  late final bool isCheese;
  late final List<_Portion> portions;

  double candidateScore(String mealName) {
    final calorieBase = math.max(calories, 1.0);
    double score;
    if (group == 'meat' || group == 'dairyegg') {
      score = protein / calorieBase * 4;
    } else if (group == 'starch') {
      score = carbs / calorieBase;
    } else if (group == 'fruit' || group == 'veggie') {
      score = (carbs + 5) / calorieBase;
    } else {
      score = fat / calorieBase;
    }
    if (isCheese) score -= 0.10;
    if ((mealName == 'Lunch' || mealName == 'Dinner') && group == 'starch') {
      if (_lunchDinnerStarchKeywords.any(normalizedName.contains)) {
        score += 0.15;
      }
      if (normalizedName.contains('oat')) score -= 0.18;
    }
    return score;
  }
}

List<int> _portionOptions(Map<String, dynamic> food, String group) {
  final (minimum, configuredMaximum) = _portionRanges[group]!;
  if (group == 'fat') {
    final maximum = math.min(
      _number(food['max_amount_g'], 15).toInt(),
      configuredMaximum,
    );
    return [
      for (final grams in [0, 5, 10, 15])
        if (grams <= maximum) grams
    ];
  }
  final maximum = math.min(
    math.max(1, _number(food['max_amount_g'], 200).toInt()),
    configuredMaximum,
  );
  if (maximum < minimum) return [maximum];
  return [for (var grams = minimum; grams <= maximum; grams += 25) grams];
}

class _Portion {
  _Portion(this.food, this.grams)
      : calories = food.calories * (grams / 100),
        protein = food.protein * (grams / 100),
        carbs = food.carbs * (grams / 100),
        fat = food.fat * (grams / 100);

  final _PreparedFood food;
  final int grams;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  Map<String, dynamic> toResult() => {
        ...food.data,
        'portion_g': grams,
        'serving_calo': _round(calories),
        'serving_protein': _round(protein),
        'serving_carb': _round(carbs),
        'serving_fat': _round(fat),
        'display_name': '${grams}g ${food.name}',
        'food_group': food.group,
        'suggested_prep': '${food.data['suggested_prep'] ?? ''}'.trim(),
      };
}

class _PreparedGroup {
  const _PreparedGroup(this.group, this.foods, this.optional);

  final String group;
  final List<_PreparedFood> foods;
  final bool optional;
}

List<_PreparedFood> _pickCandidates(
  List<_PreparedFood> pool,
  String mealName,
  int limit,
  math.Random rng, [
  Set<String> excludedNames = const {},
]) {
  // Use the source index to preserve Python's stable ordering for score ties.
  final ranked = [
    for (final (index, food) in pool.indexed)
      if (!excludedNames.contains(food.normalizedName))
        (index: index, food: food, score: food.candidateScore(mealName)),
  ];
  ranked.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : a.index.compareTo(b.index);
  });
  final filtered = ranked.map((entry) => entry.food).toList();
  if (filtered.length <= limit) return filtered;

  final topCount = math.max(2, limit ~/ 2);
  final top = filtered.take(topCount).toList();
  final remaining = filtered.skip(topCount).toList();
  final randomCount = math.min(limit - top.length, remaining.length);
  // Partial Fisher-Yates samples without replacement, using only the seed.
  for (var index = 0; index < randomCount; index++) {
    final picked = index + rng.nextInt(remaining.length - index);
    final swap = remaining[index];
    remaining[index] = remaining[picked];
    remaining[picked] = swap;
    top.add(remaining[index]);
  }
  return top;
}

List<_PreparedGroup> _mealCandidateGroups(
  Map<String, List<_PreparedFood>> pools,
  String mealName,
  math.Random rng,
  Set<String> usedStarches,
  Set<String> usedProteins,
) {
  final groups = <_PreparedGroup>[];
  for (final group in _requiredGroups[mealName]!) {
    final exclusions = mealName == 'Dinner'
        ? switch (group) {
            'starch' => usedStarches,
            'meat' => usedProteins,
            _ => <String>{},
          }
        : <String>{};
    var candidates =
        _pickCandidates(pools[group]!, mealName, 6, rng, exclusions);
    if (candidates.isEmpty && exclusions.isNotEmpty) {
      candidates = _pickCandidates(pools[group]!, mealName, 6, rng);
    }
    if (candidates.isEmpty) {
      throw MealPlanUnavailableError(
          'No foods available for required group: $group');
    }
    groups.add(_PreparedGroup(group, candidates, false));
  }
  final fats = _pickCandidates(pools['fat']!, mealName, 4, rng);
  if (fats.isNotEmpty) groups.add(_PreparedGroup('fat', fats, true));
  return groups;
}

double _mealScore(
  double calories,
  double protein,
  double carbs,
  double fat,
  double targetCalories,
  double targetProtein,
  int cheeseCount,
) {
  final shortage = math.max(0.0, targetProtein - protein);
  final excess = math.max(0.0, protein - targetProtein * _proteinExcessRatio);
  final calorieError = (calories - targetCalories).abs();
  final carbRatio = carbs * 4 / math.max(calories, 1.0);
  final fatRatio = fat * 9 / math.max(calories, 1.0);
  final macroPenalty =
      (math.max(0.0, 0.20 - carbRatio) + math.max(0.0, fatRatio - 0.40)) * 50;
  final repetitionPenalty = math.max(0, cheeseCount - 1) * 20;
  return shortage * _proteinShortageWeight +
      excess * _proteinExcessWeight +
      calorieError +
      macroPenalty +
      repetitionPenalty;
}

Map<String, dynamic> _searchMeal(
  List<_PreparedGroup> groups,
  double targetCalories,
  double targetProtein,
  Duration timeLimit,
) {
  final stopwatch = Stopwatch()..start();
  var bestScore = double.infinity;
  var bestSelection = <_Portion>[];
  final selected = <_Portion>[];
  var timedOut = false;
  final calorieCeiling = targetCalories * _calorieOvershootRatio;
  final maxRemainingProtein = List<double>.filled(groups.length + 1, 0);
  for (var index = groups.length - 1; index >= 0; index--) {
    var maximum = 0.0;
    for (final food in groups[index].foods) {
      for (final portion in food.portions) {
        maximum = math.max(maximum, portion.protein);
      }
    }
    maxRemainingProtein[index] = maxRemainingProtein[index + 1] + maximum;
  }

  void search(
    int index,
    double calories,
    double protein,
    double carbs,
    double fat,
    int cheeseCount,
  ) {
    if (timedOut) return;
    if (stopwatch.elapsedMicroseconds > timeLimit.inMicroseconds) {
      timedOut = true;
      return;
    }
    final optimisticProtein = protein + maxRemainingProtein[index];
    final shortage = math.max(0.0, targetProtein - optimisticProtein);
    if (shortage * _proteinShortageWeight > bestScore) return;

    if (index == groups.length) {
      final score = _mealScore(
        calories,
        protein,
        carbs,
        fat,
        targetCalories,
        targetProtein,
        cheeseCount,
      );
      if (score < bestScore) {
        bestScore = score;
        bestSelection = List<_Portion>.from(selected);
      }
      return;
    }

    final group = groups[index];
    if (group.optional) {
      search(index + 1, calories, protein, carbs, fat, cheeseCount);
    }
    for (final food in group.foods) {
      for (final portion in food.portions) {
        if (timedOut) return;
        final newCalories = calories + portion.calories;
        if (newCalories > calorieCeiling) continue;
        selected.add(portion);
        search(
          index + 1,
          newCalories,
          protein + portion.protein,
          carbs + portion.carbs,
          fat + portion.fat,
          cheeseCount + (food.isCheese ? 1 : 0),
        );
        selected.removeLast();
      }
    }
  }

  search(0, 0, 0, 0, 0, 0);
  if (bestSelection.isEmpty) {
    throw MealPlanUnavailableError(
      'No feasible meal combination was found within the search limit.',
    );
  }
  final items = bestSelection.map((portion) => portion.toResult()).toList();
  double total(String key) => _round(
        items.fold<double>(0, (sum, item) => sum + (item[key] as double)),
      );
  final totalProtein = total('serving_protein');
  return {
    'items': items,
    'target_calo': _round(targetCalories),
    'target_protein': _round(targetProtein),
    'calo': total('serving_calo'),
    'protein': totalProtein,
    'carb': total('serving_carb'),
    'fat': total('serving_fat'),
    'protein_difference': _round(totalProtein - targetProtein),
    'score': bestScore.isFinite ? _round(bestScore, 3) : null,
  };
}
