import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optifit/engine/macro_split.dart';
import 'package:optifit/models/food_log_entry.dart';
import 'package:optifit/widgets/intake_summary.dart';

import 'helpers/localized_app.dart';

void main() {
  test('fat gets 30% of the calories, carbs the rest after protein', () {
    final targets = estimateMacroTargets(calories: 2000, protein: 120);
    expect(targets.fat, closeTo(2000 * 0.30 / 9, 1e-9)); // 66,7 g
    expect(targets.carbs, closeTo((2000 - 480 - 600) / 4, 1e-9)); // 230 g
    expect(targets.protein, 120);
    // Protein so high nothing is left for carbs: zero, never negative.
    expect(estimateMacroTargets(calories: 1200, protein: 250).carbs, 0);
  });

  test('energy shares add up to 100 and are empty before eating', () {
    expect(energyShares(const FoodLogTotals()), isNull);
    final shares = energyShares(
        const FoodLogTotals(calories: 600, carbs: 60, protein: 30, fat: 20))!;
    // 240 + 120 + 180 = 540 kcal from macros.
    expect(shares.carbs, closeTo(240 / 540 * 100, 1e-9));
    expect(shares.protein, closeTo(120 / 540 * 100, 1e-9));
    expect(shares.fat, closeTo(180 / 540 * 100, 1e-9));
    expect(shares.carbs + shares.protein + shares.fat, closeTo(100, 1e-9));
  });

  test('the gauge picture follows the day', () {
    expect(gaugeStateFor(0, 2000), GaugeState.empty);
    expect(gaugeStateFor(1000, 2000), GaugeState.eating);
    expect(gaugeStateFor(1800, 2000), GaugeState.nearlyThere, reason: '90%');
    expect(gaugeStateFor(2000, 2000), GaugeState.nearlyThere);
    expect(gaugeStateFor(2001, 2000), GaugeState.over);
    expect(gaugeStateFor(500, null), GaugeState.eating, reason: 'no target');
  });

  Future<void> mount(WidgetTester tester, FoodLogTotals totals,
      {Map<String, dynamic>? targets}) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(localizedApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: IntakeSummary(totals: totals, targets: targets),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  const targets = {'target_calories': 2000.0, 'protein_target': 120.0};

  testWidgets('the gauge counts what is left, then what is over',
      (tester) async {
    await mount(tester,
        const FoodLogTotals(calories: 1500, carbs: 180, protein: 90, fat: 50),
        targets: targets);
    expect(find.text('500'), findsOneWidget);
    expect(find.text('kcal còn lại'), findsOneWidget);
    expect(find.byIcon(Icons.ramen_dining_rounded), findsOneWidget);
    expect(find.text('1.500 / 2.000 kcal'), findsOneWidget);
    expect(find.text('90 / 120 g'), findsOneWidget);
    expect(find.text('180 / 230 g'), findsOneWidget);

    await mount(tester, const FoodLogTotals(calories: 2300, fat: 100),
        targets: targets);
    expect(find.text('300'), findsOneWidget);
    expect(find.text('kcal vượt mục tiêu'), findsOneWidget);
    expect(find.byIcon(Icons.no_food_rounded), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Vượt mục tiêu 300')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the C/P/B chips show where the energy came from',
      (tester) async {
    await mount(tester,
        const FoodLogTotals(calories: 600, carbs: 60, protein: 30, fat: 20));
    // 240 / 120 / 180 kcal of 540.
    expect(find.text('44%'), findsOneWidget);
    expect(find.text('22%'), findsOneWidget);
    expect(find.text('33%'), findsOneWidget);
    expect(find.text('kcal đã ăn'), findsOneWidget,
        reason: 'no targets: the gauge shows what was eaten');
    // Screen readers hear the eaten calories as one phrase.
    final handle = tester.ensureSemantics();
    expect(tester.getSemantics(find.byType(CalorieGauge)).label, '600 kcal');
    handle.dispose();
  });
}
