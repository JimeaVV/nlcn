import '../models/weight_entry.dart';

/// Energy in one kilogram of body weight change: a common approximation
/// (about 7700 kcal/kg), not exact for every person or every diet.
const kcalPerKgBodyWeight = 7700.0;

/// What the estimate needs from the last [AdaptiveTdeeRules.windowDays].
class AdaptiveTdeeRules {
  const AdaptiveTdeeRules({
    this.windowDays = 28,
    this.minLoggedDays = 10,
    this.minWeighIns = 3,
    this.minWeighInSpanDays = 10,
    this.minDayCalories = 500,
  });

  final int windowDays;

  /// Days with food logged, each at least [minDayCalories].
  final int minLoggedDays;
  final int minWeighIns;

  /// Days between the first and the last weigh-in.
  final int minWeighInSpanDays;

  /// A day logged below this is taken as incomplete and left out.
  final double minDayCalories;
}

/// TDEE measured from the user's own diary and weigh-ins: what they ate on
/// average, corrected by how their weight moved. MacroFactor-style apps work
/// the same way; this is a plain, explainable version of it.
class AdaptiveTdee {
  const AdaptiveTdee({
    required this.tdee,
    required this.averageIntake,
    required this.weeklyChangeKg,
    required this.loggedDays,
    required this.weighIns,
    required this.weighInSpanDays,
    required this.plausible,
  });

  /// Null until there is enough data, see [AdaptiveTdeeRules].
  final double? tdee;
  final double averageIntake;
  final double weeklyChangeKg;
  final int loggedDays;
  final int weighIns;
  final int weighInSpanDays;

  /// False when the result is far from the formula estimate, which usually
  /// means days were not logged in full.
  final bool plausible;

  bool get ready => tdee != null;
}

/// Estimates TDEE from [dailyCalories] (calories eaten per calendar day) and
/// [weights] over the window that ends on [today]:
///
///   TDEE = average intake − (weight slope in kg/day × [kcalPerKgBodyWeight])
///
/// The slope is the least-squares line through the weigh-ins, so a single
/// heavy or light morning moves it little. [formulaTdee] (Mifflin-St Jeor ×
/// activity) only judges whether the result is plausible.
AdaptiveTdee estimateAdaptiveTdee({
  required Map<DateTime, double> dailyCalories,
  required List<WeightEntry> weights,
  required double formulaTdee,
  required DateTime today,
  AdaptiveTdeeRules rules = const AdaptiveTdeeRules(),
}) {
  final end = DateTime(today.year, today.month, today.day);
  final start = DateTime(end.year, end.month, end.day - rules.windowDays + 1);
  bool inWindow(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    return !date.isBefore(start) && !date.isAfter(end);
  }

  final intake = [
    for (final entry in dailyCalories.entries)
      if (inWindow(entry.key) && entry.value >= rules.minDayCalories)
        entry.value,
  ];
  final weighIns = [
    for (final weight in weights)
      if (inWindow(weight.recordedAt)) weight,
  ]..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

  final averageIntake =
      intake.isEmpty ? 0.0 : intake.reduce((a, b) => a + b) / intake.length;
  final span = weighIns.length < 2
      ? 0
      : _days(weighIns.first.recordedAt, weighIns.last.recordedAt);
  final slope = weighIns.length < 2
      ? 0.0
      : _slopePerDay([
          for (final weight in weighIns)
            (_days(start, weight.recordedAt).toDouble(), weight.weight),
        ]);

  final enough = intake.length >= rules.minLoggedDays &&
      weighIns.length >= rules.minWeighIns &&
      span >= rules.minWeighInSpanDays;
  final tdee = enough ? averageIntake - slope * kcalPerKgBodyWeight : null;
  final plausible = tdee != null &&
      tdee >= 1000 &&
      tdee <= 6000 &&
      tdee >= formulaTdee * 0.7 &&
      tdee <= formulaTdee * 1.4;
  return AdaptiveTdee(
    tdee: tdee,
    averageIntake: averageIntake,
    weeklyChangeKg: slope * 7,
    loggedDays: intake.length,
    weighIns: weighIns.length,
    weighInSpanDays: span,
    plausible: plausible,
  );
}

int _days(DateTime from, DateTime to) => DateTime.utc(to.year, to.month, to.day)
    .difference(DateTime.utc(from.year, from.month, from.day))
    .inDays;

/// Least-squares slope of y over x.
double _slopePerDay(List<(double, double)> points) {
  final n = points.length;
  final meanX = points.map((p) => p.$1).reduce((a, b) => a + b) / n;
  final meanY = points.map((p) => p.$2).reduce((a, b) => a + b) / n;
  var numerator = 0.0;
  var denominator = 0.0;
  for (final (x, y) in points) {
    numerator += (x - meanX) * (y - meanY);
    denominator += (x - meanX) * (x - meanX);
  }
  return denominator == 0 ? 0 : numerator / denominator;
}
