import 'package:flutter_test/flutter_test.dart';
import 'package:optifit/engine/adaptive_tdee.dart';
import 'package:optifit/models/weight_entry.dart';

final _today = DateTime(2026, 10, 21);

DateTime _daysAgo(int days) =>
    DateTime(_today.year, _today.month, _today.day - days);

/// [kcal] eaten on each of the last [days] days.
Map<DateTime, double> _intake(int days, double kcal) =>
    {for (var i = 0; i < days; i++) _daysAgo(i): kcal};

/// Weigh-ins every [every] days over the last [days], starting at [start] and
/// moving [perWeek] kg a week.
List<WeightEntry> _weights(
    {int days = 21, int every = 3, double start = 70, double perWeek = 0}) {
  var id = 1;
  return [
    for (var ago = days; ago >= 0; ago -= every)
      WeightEntry(
        id: id++,
        weight: start + perWeek * (days - ago) / 7,
        recordedAt: _daysAgo(ago),
      ),
  ];
}

AdaptiveTdee _estimate(Map<DateTime, double> intake, List<WeightEntry> weights,
        {double formula = 2300}) =>
    estimateAdaptiveTdee(
      dailyCalories: intake,
      weights: weights,
      formulaTdee: formula,
      today: _today,
    );

void main() {
  test('a steady weight means TDEE equals what was eaten', () {
    final result = _estimate(_intake(20, 2200), _weights());
    expect(result.ready, isTrue);
    expect(result.tdee, closeTo(2200, 1e-6));
    expect(result.weeklyChangeKg, closeTo(0, 1e-9));
    expect(result.loggedDays, 20);
    expect(result.plausible, isTrue);
  });

  test('losing 0.5 kg a week adds its energy to the intake', () {
    // 0.5 kg / 7 days × 7700 kcal/kg = 550 kcal a day burnt from the body.
    final result =
        _estimate(_intake(20, 1800), _weights(start: 72, perWeek: -0.5));
    expect(result.weeklyChangeKg, closeTo(-0.5, 1e-9));
    expect(result.tdee, closeTo(2350, 1e-6));
  });

  test('gaining weight means eating above TDEE', () {
    final result =
        _estimate(_intake(20, 2800), _weights(start: 65, perWeek: 0.35));
    expect(result.tdee, closeTo(2800 - 0.35 / 7 * 7700, 1e-6));
  });

  test('one odd weigh-in moves the fitted line only a little', () {
    final weights = _weights();
    final odd = [
      ...weights.take(4),
      WeightEntry(id: 99, weight: 71.5, recordedAt: weights[4].recordedAt),
      ...weights.skip(5),
    ];
    final result = _estimate(_intake(20, 2200), odd);
    // A 1.5 kg spike on one day, against 2200 kcal × 7700 / kg.
    expect((result.tdee! - 2200).abs(), lessThan(150));
  });

  test('days logged under 500 kcal are left out as incomplete', () {
    final intake = {..._intake(12, 2000), _daysAgo(15): 300.0};
    final result = _estimate(intake, _weights());
    expect(result.loggedDays, 12);
    expect(result.averageIntake, 2000);
  });

  test('data outside the four-week window is ignored', () {
    final intake = {..._intake(12, 2000), _daysAgo(40): 5000.0};
    final weights = [
      WeightEntry(id: 50, weight: 90, recordedAt: _daysAgo(60)),
      ..._weights(),
    ];
    final result = _estimate(intake, weights);
    expect(result.averageIntake, 2000);
    expect(result.tdee, closeTo(2000, 1e-6));
  });

  test('too little data gives no estimate but says what is there', () {
    final fewDays = _estimate(_intake(9, 2000), _weights());
    expect(fewDays.ready, isFalse);
    expect(fewDays.loggedDays, 9);

    final fewWeighIns = _estimate(_intake(20, 2000), _weights(every: 11));
    expect(fewWeighIns.weighIns, 2);
    expect(fewWeighIns.ready, isFalse);

    final shortSpan = _estimate(_intake(20, 2000), _weights(days: 6));
    expect(shortSpan.weighInSpanDays, 6);
    expect(shortSpan.ready, isFalse);
  });

  test('a result far from the formula is marked implausible', () {
    // Logging half of what was eaten looks like a huge deficit.
    final result = _estimate(_intake(20, 1100), _weights(), formula: 2400);
    expect(result.ready, isTrue);
    expect(result.plausible, isFalse);
  });
}
