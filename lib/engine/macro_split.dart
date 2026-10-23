import '../models/food_log_entry.dart';

/// Share of the calorie target given to fat when estimating a fat target.
/// The middle of the adult range of 20–35% of energy (Institute of Medicine,
/// Dietary Reference Intakes for Energy and Macronutrients, 2005: the
/// Acceptable Macronutrient Distribution Range). An estimate, not advice.
const fatEnergyShare = 0.30;

/// Energy per gram used for the split (Atwater factors).
const kcalPerGramCarb = 4.0;
const kcalPerGramProtein = 4.0;
const kcalPerGramFat = 9.0;

/// Gram targets for the three macronutrients.
class MacroTargets {
  const MacroTargets(
      {required this.carbs, required this.protein, required this.fat});

  final double carbs;
  final double protein;
  final double fat;
}

/// Carb and fat targets estimated from the calorie and protein targets the
/// app already has: fat takes [fatEnergyShare] of the calories, carbs what
/// is left after protein and fat (never below zero).
MacroTargets estimateMacroTargets(
    {required double calories, required double protein}) {
  final fat = calories * fatEnergyShare / kcalPerGramFat;
  final carbEnergy =
      calories - protein * kcalPerGramProtein - fat * kcalPerGramFat;
  return MacroTargets(
    carbs: carbEnergy > 0 ? carbEnergy / kcalPerGramCarb : 0,
    protein: protein,
    fat: fat,
  );
}

/// Which share of the eaten energy came from carbs, protein and fat, in
/// percent, adding up to 100 (rounding aside). Null before anything with
/// macros is logged.
({double carbs, double protein, double fat})? energyShares(
    FoodLogTotals totals) {
  final carbs = totals.carbs * kcalPerGramCarb;
  final protein = totals.protein * kcalPerGramProtein;
  final fat = totals.fat * kcalPerGramFat;
  final sum = carbs + protein + fat;
  if (sum <= 0) return null;
  return (
    carbs: carbs / sum * 100,
    protein: protein / sum * 100,
    fat: fat / sum * 100,
  );
}
