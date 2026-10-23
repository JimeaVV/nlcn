import '../models/food_log_entry.dart';
import '../models/history_models.dart';
import '../models/weight_entry.dart';

/// A common everyday reference for drinking water, not a personal
/// prescription: needs change with body size, heat and exercise.
const waterTargetMl = 2000;

/// One glass on the water card.
const waterGlassMl = 250;

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

/// Days in a row with food logged, ending today. A today with nothing logged
/// yet does not break the streak: the day is not over.
int loggingStreak(Iterable<DateTime> loggedDays, DateTime today) {
  final days = {for (final day in loggedDays) _day(day)};
  var cursor = _day(today);
  if (!days.contains(cursor)) {
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }
  var streak = 0;
  while (days.contains(cursor)) {
    streak++;
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }
  return streak;
}

/// The last seven days, today included.
class WeekSummary {
  const WeekSummary({
    required this.loggedDays,
    required this.averageCalories,
    required this.averageProtein,
    required this.trainingDays,
    required this.weightChange,
  });

  /// Days with food logged; the averages are over these days only.
  final int loggedDays;
  final double averageCalories;
  final double averageProtein;

  /// Days with at least one exercise logged.
  final int trainingDays;

  /// The same change the weight card shows (see [weeklyWeightChange]); null
  /// when nobody weighed in this week or there is nothing to compare with.
  final WeightChange? weightChange;
}

/// How much the latest weigh-in differs from an earlier one, and which.
class WeightChange {
  const WeightChange({required this.kg, required this.since});

  final double kg;
  final DateTime since;
}

/// The latest weigh-in against the earlier one closest to a week before it
/// (the older one on a tie). The date of that earlier weigh-in is shown with
/// the number, so a gap of 5 or 9 days is not passed off as exactly 7.
WeightChange? weeklyWeightChange(List<WeightEntry> weights) {
  if (weights.length < 2) return null;
  final sorted = List<WeightEntry>.of(weights)
    ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
  final latest = sorted.last;
  final weekBefore = latest.recordedAt.subtract(const Duration(days: 7));
  WeightEntry? best;
  for (final entry in sorted.take(sorted.length - 1)) {
    final distance = entry.recordedAt.difference(weekBefore).abs();
    if (best == null ||
        distance < best.recordedAt.difference(weekBefore).abs()) {
      best = entry;
    }
  }
  return WeightChange(kg: latest.weight - best!.weight, since: best.recordedAt);
}

WeekSummary summarizeWeek({
  required Map<DateTime, FoodLogTotals> dailyTotals,
  required List<WorkoutLogEntry> workoutLogs,
  required List<WeightEntry> weights,
  required DateTime today,
}) {
  final end = _day(today);
  final start = DateTime(end.year, end.month, end.day - 6);
  bool inWeek(DateTime value) {
    final day = _day(value);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  final days = [
    for (final entry in dailyTotals.entries)
      if (inWeek(entry.key)) entry.value,
  ];
  double average(double Function(FoodLogTotals) value) =>
      days.isEmpty ? 0 : days.map(value).reduce((a, b) => a + b) / days.length;
  final trained = {
    for (final log in workoutLogs)
      if (inWeek(log.performedAt.toLocal())) _day(log.performedAt.toLocal()),
  };
  final weighedThisWeek = weights.any((w) => inWeek(w.recordedAt));
  return WeekSummary(
    loggedDays: days.length,
    averageCalories: average((day) => day.calories),
    averageProtein: average((day) => day.protein),
    trainingDays: trained.length,
    weightChange: weighedThisWeek ? weeklyWeightChange(weights) : null,
  );
}
