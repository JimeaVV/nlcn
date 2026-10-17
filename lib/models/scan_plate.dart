import '../services/food_recognizer.dart';
import 'food_log_entry.dart';
import 'vn_food.dart';

/// One component on the scanned plate and the amount the user confirmed.
class PlateItem {
  PlateItem({
    required this.component,
    required this.included,
    required this.inUnits,
    required this.amount,
    this.confidence,
    this.uncertain = false,
  });

  final VnComponent component;
  bool included;

  /// True when [amount] counts natural units (e.g. eggs), false for grams.
  final bool inUnits;
  double amount;

  /// The recognizer's probability, or null when not recognized by the model.
  final double? confidence;

  /// Shown as "maybe" because the model was not sure.
  bool uncertain;

  double get step => inUnits ? 0.5 : 10;

  /// Null while the weight of one unit is not known yet.
  double? get grams => inUnits
      ? (component.unitGrams == null ? null : amount * component.unitGrams!)
      : amount;

  bool get hasNutrition => grams != null && component.hasNutrition;

  double _scaled(double? per100) => per100! * grams! / 100;

  double get calories => _scaled(component.kcalPer100g);
  double get protein => _scaled(component.proteinPer100g);
  double get carbs => _scaled(component.carbPer100g);
  double get fat => _scaled(component.fatPer100g);
}

/// The dish chosen for a photo and the components the user keeps.
class ScanPlate {
  ScanPlate._(this.dish, this.items);

  /// Default parts of [dish], adjusted by what [recognition] saw: confident
  /// components are ticked, unsure ones are asked about, and confident
  /// components outside the usual recipe are added.
  factory ScanPlate.forDish(
    VnFoodData data,
    VnDish dish,
    FoodRecognition recognition,
  ) {
    final seen = recognition.components;
    final items = <PlateItem>[];
    for (final part in dish.parts) {
      final component = data.components[part.component]!;
      final score = seen[component.code];
      final included = component.isBase ||
          recognition.isEmpty ||
          (score ?? 0) >= recognition.thresholds.checked;
      final inUnits = part.defaultUnits != null ||
          (part.defaultGrams == null && component.unitNameVi != null);
      items.add(PlateItem(
        component: component,
        included: included,
        inUnits: inUnits,
        amount: inUnits ? part.defaultUnits ?? 1 : part.defaultGrams ?? 100,
        confidence: component.isBase ? null : score,
        uncertain:
            !included && score != null && score >= recognition.thresholds.ask,
      ));
    }
    final listed = {for (final part in dish.parts) part.component};
    for (final entry in seen.entries) {
      final component = data.components[entry.key];
      if (component == null ||
          component.isBase ||
          listed.contains(entry.key) ||
          entry.value < recognition.thresholds.ask) {
        continue;
      }
      final confident = entry.value >= recognition.thresholds.checked;
      items.add(PlateItem(
        component: component,
        included: confident,
        inUnits: component.unitNameVi != null,
        amount: component.unitNameVi != null ? 1 : 100,
        confidence: entry.value,
        uncertain: !confident,
      ));
    }
    return ScanPlate._(dish, items);
  }

  final VnDish dish;
  final List<PlateItem> items;

  Iterable<PlateItem> get selected => items.where((item) => item.included);

  /// Selected components whose nutrition is still unknown.
  List<PlateItem> get missingNutrition => [
        for (final item in selected)
          if (!item.hasNutrition) item
      ];

  bool get canLog => selected.isNotEmpty && missingNutrition.isEmpty;

  double get calories => selected
      .where((item) => item.hasNutrition)
      .fold(0, (sum, item) => sum + item.calories);

  double get protein => selected
      .where((item) => item.hasNutrition)
      .fold(0, (sum, item) => sum + item.protein);

  /// Adds a component the user found on the plate; the model did not see it.
  void add(VnComponent component) {
    if (items.any((item) => item.component.code == component.code)) return;
    items.add(PlateItem(
      component: component,
      included: true,
      inUnits: component.unitNameVi != null,
      amount: component.unitNameVi != null ? 1 : 100,
    ));
  }

  /// One diary row per selected component, named "Component (Dish)".
  List<FoodLogEntry> toEntries({
    required DateTime date,
    required MealSlot meal,
    required String languageCode,
  }) {
    if (!canLog) {
      throw StateError('Every selected component needs nutrition data.');
    }
    return [
      for (final item in selected)
        FoodLogEntry(
          date: date,
          meal: meal,
          name: '${item.component.name(languageCode)} '
              '(${dish.name(languageCode)})',
          grams: item.grams,
          calories: item.calories,
          protein: item.protein,
          carbs: item.carbs,
          fat: item.fat,
          source: FoodLogSource.camera,
          confidence: item.confidence,
        ),
    ];
  }
}
