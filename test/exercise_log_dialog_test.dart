import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optifit/widgets/exercise_log_dialog.dart';

void main() {
  Future<ExerciseLogInput?> openDialog(WidgetTester tester) async {
    ExerciseLogInput? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result = await showDialog<ExerciseLogInput>(
                  context: context,
                  builder: (_) =>
                      const ExerciseLogDialog(exerciseName: 'Bench Press'),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('tapping outside closes the dialog without controller errors', (
    tester,
  ) async {
    await openDialog(tester);
    expect(find.text('Log Bench Press'), findsOneWidget);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(find.text('Log Bench Press'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('calculate returns validated exercise input', (tester) async {
    ExerciseLogInput? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result = await showDialog<ExerciseLogInput>(
                  context: context,
                  builder: (_) =>
                      const ExerciseLogDialog(exerciseName: 'Bench Press'),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '50');
    await tester.tap(find.text('Calculate'));
    await tester.pumpAndSettle();

    expect(result?.currentWeight, 50);
    expect(result?.set1Reps, 12);
    expect(result?.difficulty, 'Moderate');
    expect(tester.takeException(), isNull);
  });
}
