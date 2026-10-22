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

  /// Newest minus oldest weigh-in of the week; null with fewer than two.
  final double? weightChange;
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
  final weighIns = [
    for (final weight in weights)
      if (inWeek(weight.recordedAt)) weight,
  ]..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
  return WeekSummary(
    loggedDays: days.length,
    averageCalories: average((day) => day.calories),
    averageProtein: average((day) => day.protein),
    trainingDays: trained.length,
    weightChange: weighIns.length < 2
        ? null
        : weighIns.last.weight - weighIns.first.weight,
  );
}
