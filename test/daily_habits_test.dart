import 'package:flutter_test/flutter_test.dart';
import 'package:optifit/engine/daily_habits.dart';
import 'package:optifit/models/food_log_entry.dart';
import 'package:optifit/models/history_models.dart';
import 'package:optifit/models/weight_entry.dart';

final _today = DateTime(2026, 10, 21, 15);

DateTime _ago(int days) => DateTime(2026, 10, 21 - days);

WorkoutLogEntry _workout(DateTime at) => WorkoutLogEntry.fromMap({
      'id': at.day,
      'exercise_name': 'Squat',
      'weight_kg': 60,
      'set_1_reps': 8,
      'set_2_reps': 8,
      'set_3_reps': 8,
      'suggested_weight': 62.5,
      'suggested_reps': 8,
      'action': 'increase_weight',
      'suggestion_message': '',
      'performed_at': at.toIso8601String(),
    });

void main() {
  group('logging streak', () {
    test('counts days in a row ending today', () {
      expect(loggingStreak([_ago(0), _ago(1), _ago(2), _ago(4)], _today), 3);
    });

    test('an unlogged today keeps the streak up to yesterday', () {
      expect(loggingStreak([_ago(1), _ago(2)], _today), 2);
    });

    test('a gap before yesterday ends it', () {
      expect(loggingStreak([_ago(2), _ago(3)], _today), 0);
      expect(loggingStreak(const [], _today), 0);
    });

    test('times of day and duplicates do not matter', () {
      expect(
          loggingStreak([
            DateTime(2026, 10, 21, 23, 59),
            DateTime(2026, 10, 21, 7),
            DateTime(2026, 10, 20, 12),
          ], _today),
          2);
    });
  });

  test('the week averages logged days only and counts training days', () {
    final week = summarizeWeek(
      dailyTotals: {
        _ago(0): const FoodLogTotals(calories: 2000, protein: 100),
        _ago(3): const FoodLogTotals(calories: 1600, protein: 80),
        _ago(9): const FoodLogTotals(calories: 9000, protein: 900),
      },
      workoutLogs: [
        _workout(DateTime(2026, 10, 21, 7)),
        _workout(DateTime(2026, 10, 21, 18)),
        _workout(DateTime(2026, 10, 18, 18)),
        _workout(DateTime(2026, 10, 1, 18)),
      ],
      weights: [
        WeightEntry(id: 1, weight: 71, recordedAt: _ago(6)),
        WeightEntry(id: 2, weight: 70.2, recordedAt: _ago(0)),
        WeightEntry(id: 3, weight: 75, recordedAt: _ago(20)),
      ],
      today: _today,
    );
    expect(week.loggedDays, 2);
    expect(week.averageCalories, 1800);
    expect(week.averageProtein, 90);
    expect(week.trainingDays, 2);
    // Against the weigh-in closest to a week before the latest: 6 days ago,
    // not the one 20 days ago.
    expect(week.weightChange!.kg, closeTo(-0.8, 1e-9));
    expect(week.weightChange!.since, _ago(6));
  });

  test('the weekly change compares with the weigh-in nearest a week back', () {
    WeightEntry w(int id, double kg, int daysAgo) =>
        WeightEntry(id: id, weight: kg, recordedAt: _ago(daysAgo));
    expect(weeklyWeightChange([w(1, 70, 0)]), isNull);
    final nine =
        weeklyWeightChange([w(1, 69.6, 0), w(2, 70, 4), w(3, 70.4, 9)])!;
    expect(nine.kg, closeTo(-0.8, 1e-9), reason: '9 days is nearer 7 than 4');
    expect(nine.since, _ago(9));
    // 5 and 9 days are both 2 days off a week: the older one counts.
    expect(weeklyWeightChange([w(1, 69, 0), w(2, 70, 5), w(3, 71, 9)])!.since,
        _ago(9));
    // Only recent weigh-ins: the change since the earliest of them.
    expect(weeklyWeightChange([w(1, 69.8, 0), w(2, 70, 2)])!.kg,
        closeTo(-0.2, 1e-9));
  });

  test('a week without a weigh-in has no weight change', () {
    final week =
        summarizeWeek(dailyTotals: const {}, workoutLogs: const [], weights: [
      WeightEntry(id: 1, weight: 70, recordedAt: _ago(9)),
      WeightEntry(id: 2, weight: 71, recordedAt: _ago(16)),
    ], today: _today);
    expect(week.weightChange, isNull);
  });

  test('an empty week has zero averages and no weight change', () {
    final week = summarizeWeek(
        dailyTotals: const {},
        workoutLogs: const [],
        weights: const [],
        today: _today);
    expect(week.loggedDays, 0);
    expect(week.averageCalories, 0);
    expect(week.weightChange, isNull);
  });
}
