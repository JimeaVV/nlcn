import 'dart:math' as math;

import '../models/user_profile.dart';
import '../models/vn_food.dart';
import 'meal_planner.dart';
import 'number_utils.dart';

/// Above this daily target a snack joins the three meals: a short breakfast
/// cannot be made up later, and single meals of 1000+ kcal look unreal.
const snackFromCalories = 2600.0;

/// Default upper bound on search nodes per meal. It replaces a wall-clock
/// limit so the same seed gives the same plan on every phone.
const defaultNodeBudget = 300000;

const _gramsPerBowlOfRice = 150.0;

/// Whole dishes scoring within this share of the meal's calories of the best
/// one count as equally good (the score is about one point per kcal of
/// error), so a 600 kcal breakfast accepts dishes up to [_nearTie]·600 worse.
const _nearTie = 0.12;

/// A cutting meal up to this size keeps rice to 200 g; above it (people
/// with a high TDEE) up to 300 g.
const _cutFullMeal = 600.0;

/// Which dishes and components the planner may use, read from
/// `assets/data/vn_food/meal_plan.csv`.
class MealPlanTag {
  const MealPlanTag({
    required this.code,
    required this.kind,
    required this.slots,
    required this.goals,
  });

  /// A dish code for kinds dish, combo and soup; a component code for
  /// staple, main and side.
  final String code;

  /// `dish` is eaten whole, `combo` is rice with sides built by the search
  /// (cơm phần), `soup` goes with a combo, and `staple`, `main` and `side`
  /// are the parts a combo is built from.
  final String kind;
  final Set<String> slots;
  final Set<NutritionGoal> goals;

  bool fits(String slot, NutritionGoal goal) =>
      slots.contains(slot) && goals.contains(goal);
}

const _kinds = {'dish', 'combo', 'soup', 'staple', 'main', 'side'};
const _slotNames = {
  'breakfast': 'Breakfast',
  'lunch': 'Lunch',
  'dinner': 'Dinner',
  'snack': 'Snack',
};

List<MealPlanTag> parseMealPlanTags(String csv) => [
      for (final row in parseCsv(csv))
        MealPlanTag(
          code: row['code']!,
          kind: _checked(row['kind']!, _kinds, 'kind'),
          slots: {
            for (final slot in _split(row['slots']))
              _slotNames[_checked(slot, _slotNames.keys.toSet(), 'slot')]!,
          },
          goals: {
            for (final goal in _split(row['goals']))
              NutritionGoal.values.byName(_checked(goal,
                  {for (final g in NutritionGoal.values) g.name}, 'goal')),
          },
        ),
    ];

Iterable<String> _split(String? value) => (value ?? '')
    .split('|')
    .map((part) => part.trim())
    .where((p) => p.isNotEmpty);

String _checked(String value, Set<String> allowed, String field) {
  if (!allowed.contains(value)) {
    throw FormatException('Unknown $field in meal_plan.csv: $value');
  }
  return value;
}

/// Counters from one meal's search, kept for the report and for tests.
class SearchStats {
  int nodes = 0;
  int pruned = 0;
  bool budgetExhausted = false;

  Map<String, dynamic> toJson() => {
        'nodes': nodes,
        'pruned': pruned,
        'budget_exhausted': budgetExhausted,
      };
}

/// Plans a day of realistic Vietnamese meals for the user's targets.
///
/// Breakfast is a whole dish such as phở or bánh mì, scaled to 0.75–1.5
/// servings. Lunch and dinner are either a whole dish or a cơm phần that
/// Branch & Bound builds from rice, one or two mains, vegetables and an
/// optional soup. Which dishes fit which meal and goal comes from
/// [tags]; losing weight also weighs rice, up to 200 g a meal (300 g for
/// the large meals of a high TDEE).
///
/// The [seed] shuffles the candidates, so each press gives a different day
/// while the same seed always reproduces the same plan. The output has the
/// same shape as [generateMealPlan], so the app shows and logs it alike.
Map<String, dynamic> generateVnMealPlan(
  VnFoodData data,
  List<MealPlanTag> tags, {
  required double dailyCalories,
  required double proteinTarget,
  required double bodyWeightKg,
  required NutritionGoal goal,
  required int seed,
  String languageCode = 'vi',
  int nodeBudget = defaultNodeBudget,
  bool calorieBound = true,
}) {
  if (!dailyCalories.isFinite || dailyCalories <= 0) {
    throw ArgumentError('Daily calories must be finite and greater than 0.');
  }
  if (!proteinTarget.isFinite || proteinTarget <= 0) {
    throw ArgumentError('Protein target must be finite and greater than 0.');
  }
  final planner = _Planner(data, tags, goal, languageCode, nodeBudget,
      calorieBound, math.Random(seed));
  final ratios = dailyCalories >= snackFromCalories
      ? const {'Breakfast': 0.25, 'Lunch': 0.30, 'Dinner': 0.30, 'Snack': 0.15}
      : goal == NutritionGoal.lose
          // A light breakfast and fuller main meals, as people cutting eat.
          ? const {'Breakfast': 0.25, 'Lunch': 0.375, 'Dinner': 0.375}
          : const {'Breakfast': 0.30, 'Lunch': 0.35, 'Dinner': 0.35};

  // Vietnamese breakfasts and snacks carry little protein, so they get a
  // smaller share of it; lunch and dinner take the rest.
  final proteinShares = {
    for (final slot in ratios.keys)
      slot: switch (slot) {
        'Breakfast' => 0.20,
        'Snack' => 0.05,
        _ => 0.0,
      },
  };
  final mainMeals = ratios.keys.where((s) => s == 'Lunch' || s == 'Dinner');
  final rest = 1 - proteinShares.values.fold(0.0, (a, b) => a + b);
  for (final slot in mainMeals) {
    proteinShares[slot] = rest / mainMeals.length;
  }

  // Whole-dish meals are planned first; whatever they miss carries over to
  // lunch and dinner, whose rice combos can absorb it.
  final order = [
    for (final slot in ['Breakfast', 'Snack', 'Lunch', 'Dinner'])
      if (ratios.containsKey(slot)) slot,
  ];
  final planned = <String, Map<String, dynamic>>{};
  var leftCalories = dailyCalories, leftProtein = proteinTarget;
  var leftCalorieShare = 1.0, leftProteinShare = 1.0;
  var calories = 0.0, protein = 0.0, carbs = 0.0, fat = 0.0;
  final stopwatch = Stopwatch()..start();
  for (final slot in order) {
    final calorieShare = ratios[slot]! / leftCalorieShare;
    final proteinShare = proteinShares[slot]! / leftProteinShare;
    final meal = planner.planMeal(
      slot,
      math.max(100.0, leftCalories * calorieShare),
      math.max(1.0, leftProtein * proteinShare),
    );
    planned[slot] = meal;
    leftCalories -= meal['calo'] as double;
    leftProtein -= meal['protein'] as double;
    leftCalorieShare -= ratios[slot]!;
    leftProteinShare -= proteinShares[slot]!;
    calories += meal['calo'] as double;
    protein += meal['protein'] as double;
    carbs += meal['carb'] as double;
    fat += meal['fat'] as double;
  }
  // Shown in the order of the day.
  final meals = {for (final slot in ratios.keys) slot: planned[slot]};
  return {
    'planner': 'vn',
    'seed': seed,
    'meals': meals,
    'target_calo': _round(dailyCalories),
    'protein_target': _round(proteinTarget),
    'protein_per_kg': _round(proteinTarget / bodyWeightKg),
    'body_weight_kg': _round(bodyWeightKg),
    'total_calo': _round(calories),
    'total_protein': _round(protein),
    'total_carb': _round(carbs),
    'total_fat': _round(fat),
    'calorie_difference': _round(calories - dailyCalories),
    'protein_difference': _round(protein - proteinTarget),
    'time': _round(stopwatch.elapsedMicroseconds / 1000000, 6),
  };
}

double _round(double value, [int digits = 2]) =>
    roundLikePython(value, digits: digits);

/// One way to fill a meal slot: a portion of a component or of a whole dish.
class _Choice {
  _Choice({
    required this.code,
    required this.kind,
    required this.name,
    required this.label,
    required this.grams,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.detail = '',
    this.order = 0,
  });

  final String code;
  final String kind;
  final String name;
  final String label;
  final double grams;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final String detail;

  /// Position among the main choices, so a pair of mains is tried once.
  final int order;

  Map<String, dynamic> toResult() => {
        'code': code,
        'name': name,
        'display_name': label,
        'food_group': kind,
        'portion_g': _round(grams, 0),
        'serving_calo': _round(calories),
        'serving_protein': _round(protein),
        'serving_carb': _round(carbs),
        'serving_fat': _round(fat),
        'suggested_prep': detail,
      };
}

/// A combo position: one choice from [options], or none if [optional].
class _Group {
  _Group(this.options, {this.optional = false});

  final List<_Choice> options;
  final bool optional;

  late final double minCalories =
      optional ? 0 : options.map((c) => c.calories).reduce(math.min);
  late final double maxCalories =
      options.map((c) => c.calories).reduce(math.max);
  late final double maxProtein = options.map((c) => c.protein).reduce(math.max);
}

class _Planner {
  _Planner(this.data, this.tags, this.goal, this.language, this.nodeBudget,
      this.calorieBound, this.rng);

  final VnFoodData data;
  final List<MealPlanTag> tags;
  final NutritionGoal goal;
  final String language;
  final int nodeBudget;
  final bool calorieBound;
  final math.Random rng;
  final _usedDishes = <String>{};
  final _usedMains = <String>{};

  Iterable<MealPlanTag> _tagged(String kind, String slot) =>
      tags.where((tag) => tag.kind == kind && tag.fits(slot, goal));

  /// Up to [count] items in seeded random order, preferring unused ones.
  List<T> _sample<T>(List<T> items, int count, bool Function(T) used) {
    final fresh = items.where((item) => !used(item)).toList()..shuffle(rng);
    final pool = fresh.isNotEmpty ? fresh : (items.toList()..shuffle(rng));
    return pool.take(count).toList();
  }

  Map<String, dynamic> planMeal(
      String slot, double targetCalories, double targetProtein) {
    final stats = SearchStats();
    var bestScore = double.infinity;
    List<_Choice>? best;

    double score(double cal, double pro, double carb, double fatG) => scoreMeal(
          calories: cal,
          protein: pro,
          carbs: carb,
          fat: fatG,
          targetCalories: targetCalories,
          targetProtein: targetProtein,
        );

    // Whole dishes: every serving size of every tagged dish not eaten yet
    // today. The seed picks among those nearly as good as the best, so
    // days vary without settling for a clearly worse dish.
    final tagged = [
      for (final tag in _tagged('dish', slot))
        if (data.dish(tag.code) != null) data.dish(tag.code)!,
    ];
    final fresh = [
      for (final dish in tagged)
        if (!_usedDishes.contains(dish.code)) dish,
    ];
    final ceiling = targetCalories * calorieOvershootRatio;
    final bestPerDish = <String, (double, _Choice)>{};
    for (final dish in fresh.isNotEmpty ? fresh : tagged) {
      for (final servings in _servings()) {
        stats.nodes++;
        final choice = _dishChoice(dish, servings);
        if (choice.calories > ceiling) continue;
        final value =
            score(choice.calories, choice.protein, choice.carbs, choice.fat);
        final previous = bestPerDish[dish.code];
        if (previous == null || value < previous.$1) {
          bestPerDish[dish.code] = (value, choice);
        }
      }
    }
    if (bestPerDish.isNotEmpty) {
      final top = bestPerDish.values.map((entry) => entry.$1).reduce(math.min);
      final near = [
        for (final code in bestPerDish.keys.toList()..sort())
          if (bestPerDish[code]!.$1 <= top + _nearTie * targetCalories)
            bestPerDish[code]!,
      ];
      final pick = near[rng.nextInt(near.length)];
      bestScore = pick.$1;
      best = [pick.$2];
    }

    // Cơm phần: Branch & Bound over rice, mains, vegetables and soup,
    // starting from the best whole dish as the incumbent.
    if (_tagged('combo', slot).isNotEmpty) {
      final groups = _comboGroups(slot, targetCalories);
      if (groups != null) {
        final result = _branchAndBound(groups, targetCalories, targetProtein,
            ceiling, bestScore, stats, score);
        if (result != null) {
          bestScore = result.$1;
          best = result.$2;
        }
      }
    }

    if (best == null) {
      throw MealPlanUnavailableError('No Vietnamese meal fits $slot.');
    }
    for (final choice in best) {
      if (choice.kind == 'dish') _usedDishes.add(choice.code);
      if (choice.kind == 'main') _usedMains.add(choice.code);
    }
    double total(double Function(_Choice) field) =>
        _round(best!.fold(0.0, (sum, choice) => sum + field(choice)));
    final protein = total((c) => c.protein);
    return {
      'items': [for (final choice in best) choice.toResult()],
      'target_calo': _round(targetCalories),
      'target_protein': _round(targetProtein),
      'calo': total((c) => c.calories),
      'protein': protein,
      'carb': total((c) => c.carbs),
      'fat': total((c) => c.fat),
      'protein_difference': _round(protein - targetProtein),
      'score': _round(bestScore, 3),
      'search': stats.toJson(),
    };
  }

  List<double> _servings() => switch (goal) {
        // Only light dishes are tagged for cutting, so a larger bowl of
        // cháo still keeps breakfast in budget.
        NutritionGoal.lose => const [0.75, 1, 1.25, 1.5, 2],
        NutritionGoal.maintain => const [0.75, 1, 1.25, 1.5],
        NutritionGoal.gain => const [1, 1.25, 1.5, 2],
      };

  /// Rice as (grams, bowls or null). People cutting weigh their rice, so
  /// they get grams; everyone else counts bowls.
  List<(double, double?)> _rice(double mealCalories) => switch (goal) {
        NutritionGoal.lose => [
            for (final grams in mealCalories <= _cutFullMeal
                ? const [100.0, 150.0, 200.0]
                : const [100.0, 150.0, 200.0, 250.0, 300.0])
              (grams, null),
          ],
        NutritionGoal.maintain => [
            for (final bowls in const [1.0, 1.5, 2.0])
              (bowls * _gramsPerBowlOfRice, bowls),
          ],
        NutritionGoal.gain => [
            for (final bowls in const [1.0, 1.5, 2.0, 2.5, 3.0])
              (bowls * _gramsPerBowlOfRice, bowls),
          ],
      };

  List<double> _mainGrams() => switch (goal) {
        NutritionGoal.gain => const [80, 100, 150, 200, 250],
        _ => const [60, 80, 100, 120, 150, 200],
      };

  /// Portions of a main as (grams, natural units or null). Pieces people
  /// count (eggs, a fried chicken leg, a fish steak) come in whole or half
  /// units; small or loose ones such as shrimp by weight.
  List<(double, double?)> _mainPortions(VnComponent main) {
    final unit = main.unitGrams;
    if (unit == null || unit < 30 || main.unitNameVi == null) {
      return [for (final grams in _mainGrams()) (grams, null)];
    }
    final counts =
        unit < 80 ? const [1.0, 2.0, 3.0] : const [0.5, 1.0, 1.5, 2.0];
    return [
      for (final count in counts)
        if (count * unit <= 300) (count * unit, count),
    ];
  }

  List<_Group>? _comboGroups(String slot, double mealCalories) {
    final staple = _tagged('staple', slot)
        .map((tag) => data.components[tag.code])
        .whereType<VnComponent>()
        .where((c) => c.hasNutrition)
        .toList();
    final mains = _sample(
      [
        for (final tag in _tagged('main', slot))
          if (data.components[tag.code]?.hasNutrition ?? false)
            data.components[tag.code]!,
      ],
      4,
      (main) => _usedMains.contains(main.code),
    );
    final sides = _tagged('side', slot)
        .map((tag) => data.components[tag.code])
        .whereType<VnComponent>()
        .where((c) => c.hasNutrition)
        .toList();
    final soups = _sample(
      [
        for (final tag in _tagged('soup', slot))
          if (data.dish(tag.code) != null) data.dish(tag.code)!,
      ],
      1,
      (_) => false,
    );
    if (staple.isEmpty || mains.isEmpty || sides.isEmpty) return null;

    final mainChoices = [
      for (final (index, (main, units)) in [
        for (final main in mains)
          for (final units in _mainPortions(main)) (main, units),
      ].indexed)
        units.$2 == null
            ? _componentChoice(main, units.$1, 'main', order: index)
            : _componentChoice(main, units.$1, 'main',
                units: units.$2, order: index),
    ];
    return [
      _Group([
        for (final rice in staple)
          for (final (grams, bowls) in _rice(mealCalories))
            _componentChoice(rice, grams, 'staple', units: bowls),
      ]),
      _Group(mainChoices),
      _Group(mainChoices, optional: true),
      _Group([
        for (final side in sides)
          for (final grams in const [80.0, 120.0, 150.0, 200.0])
            _componentChoice(side, grams, 'side'),
      ]),
      if (soups.isNotEmpty)
        _Group([
          for (final soup in soups)
            for (final servings in const [0.75, 1.0])
              _dishChoice(soup, servings, kind: 'soup'),
        ], optional: true),
    ];
  }

  (double, List<_Choice>)? _branchAndBound(
    List<_Group> groups,
    double targetCalories,
    double targetProtein,
    double ceiling,
    double incumbent,
    SearchStats stats,
    double Function(double, double, double, double) score,
  ) {
    // Bounds over the groups not chosen yet, from position i to the end.
    final minRest = List<double>.filled(groups.length + 1, 0);
    final maxRest = List<double>.filled(groups.length + 1, 0);
    final proteinRest = List<double>.filled(groups.length + 1, 0);
    for (var i = groups.length - 1; i >= 0; i--) {
      minRest[i] = minRest[i + 1] + groups[i].minCalories;
      maxRest[i] = maxRest[i + 1] + groups[i].maxCalories;
      proteinRest[i] = proteinRest[i + 1] + groups[i].maxProtein;
    }

    var bestScore = incumbent;
    List<_Choice>? best;
    final chosen = <_Choice>[];

    void search(int i, double cal, double pro, double carb, double fatG) {
      if (stats.nodes >= nodeBudget) {
        stats.budgetExhausted = true;
        return;
      }
      stats.nodes++;
      // Lower bound: protein the rest can still add at most, and (when
      // enabled) the closest total the rest can still reach.
      final shortage = math.max(0.0, targetProtein - pro - proteinRest[i]);
      var bound = shortage * proteinShortageWeight;
      if (calorieBound) {
        final low = cal + minRest[i];
        final high = math.min(cal + maxRest[i], ceiling);
        bound += targetCalories < low
            ? low - targetCalories
            : targetCalories > high
                ? targetCalories - high
                : 0;
      }
      if (bound >= bestScore) {
        stats.pruned++;
        return;
      }
      if (i == groups.length) {
        final value = score(cal, pro, carb, fatG);
        if (value < bestScore) {
          bestScore = value;
          best = List.of(chosen);
        }
        return;
      }
      final group = groups[i];
      if (group.optional) search(i + 1, cal, pro, carb, fatG);
      for (final option in group.options) {
        if (stats.budgetExhausted) return;
        // Two mains must differ, and the second follows the first's order
        // so each pair is visited once.
        if (option.kind == 'main' &&
            chosen.any((c) =>
                c.kind == 'main' &&
                (c.code == option.code || c.order >= option.order))) {
          continue;
        }
        final next = cal + option.calories;
        if (next > ceiling) continue;
        chosen.add(option);
        search(i + 1, next, pro + option.protein, carb + option.carbs,
            fatG + option.fat);
        chosen.removeLast();
      }
    }

    search(0, 0, 0, 0, 0);
    final found = best;
    return found == null ? null : (bestScore, found);
  }

  _Choice _componentChoice(VnComponent c, double grams, String kind,
      {double? units, int order = 0}) {
    final name = c.name(language);
    final label = units != null && language == 'vi' && c.unitNameVi != null
        ? '${_count(units)} ${c.unitNameVi} $name'
        : '${grams.round()}\u00A0g $name';
    return _Choice(
      code: c.code,
      kind: kind,
      name: name,
      label: label,
      grams: grams,
      calories: c.kcalPer100g! * grams / 100,
      protein: c.proteinPer100g! * grams / 100,
      carbs: c.carbPer100g! * grams / 100,
      fat: c.fatPer100g! * grams / 100,
      order: order,
    );
  }

  _Choice _dishChoice(VnDish dish, double servings, {String kind = 'dish'}) {
    var grams = 0.0, cal = 0.0, pro = 0.0, carb = 0.0, fatG = 0.0;
    final parts = <String>[];
    for (final part in dish.parts) {
      final c = data.components[part.component]!;
      if (!c.hasNutrition) continue;
      final g = (part.defaultGrams ??
              (part.defaultUnits ?? 1) * (c.unitGrams ?? 100)) *
          servings;
      grams += g;
      cal += c.kcalPer100g! * g / 100;
      pro += c.proteinPer100g! * g / 100;
      carb += c.carbPer100g! * g / 100;
      fatG += c.fatPer100g! * g / 100;
      parts.add('${g.round()}\u00A0g ${c.name(language)}');
    }
    final name = dish.name(language);
    final label = language == 'vi'
        ? '${_count(servings)} suất $name'
        : servings == 1
            ? name
            : '${_count(servings)} × $name';
    return _Choice(
      code: dish.code,
      kind: kind,
      name: name,
      label: label,
      grams: grams,
      calories: cal,
      protein: pro,
      carbs: carb,
      fat: fatG,
      detail: parts.join(', '),
    );
  }

  String _count(double value) {
    final text = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
    return language == 'vi' ? text.replaceAll('.', ',') : text;
  }
}
