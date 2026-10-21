import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optifit/models/history_models.dart';
import 'package:optifit/widgets/exercise_log_dialog.dart';
import 'package:optifit/widgets/rest_timer.dart';

import 'helpers/localized_app.dart';

void main() {
  testWidgets('the rest timer counts down, can be extended and ends',
      (tester) async {
    var closed = false;
    await tester.pumpWidget(localizedApp(
      home: Scaffold(
        body: RestTimerBar(
          exerciseName: 'Bench Press',
          seconds: 3,
          onClose: () => closed = true,
        ),
      ),
    ));
    expect(find.text('Nghỉ 0:03'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Nghỉ 0:02'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('rest-more')));
    await tester.pump();
    expect(find.text('Nghỉ 0:17'), findsOneWidget);

    await tester.pump(const Duration(seconds: 17));
    expect(find.text('Hết giờ nghỉ, vào hiệp tiếp!'), findsOneWidget);
    // Adding time after the end starts it again.
    await tester.tap(find.byKey(const ValueKey('rest-more')));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Nghỉ 0:14'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('rest-stop')));
    expect(closed, isTrue);
  });

  testWidgets('the log dialog shows the last session and starts from it',
      (tester) async {
    final previous = WorkoutLogEntry(
      id: 1,
      exerciseName: 'Bench Press',
      weight: 60,
      set1Reps: 10,
      set2Reps: 9,
      set3Reps: 8,
      difficulty: 'Moderate',
      suggestedWeight: 62.5,
      suggestedReps: 10,
      message: '',
      performedAt: DateTime(2026, 10, 18, 18),
    );
    await tester.pumpWidget(localizedApp(
      home: Scaffold(
        body:
            ExerciseLogDialog(exerciseName: 'Bench Press', previous: previous),
      ),
    ));
    expect(find.text('Lần trước (18/10/2026): 60 kg × 10 · 9 · 8'),
        findsOneWidget);
    expect(find.text('Gợi ý hôm nay: 62,5 kg × 10 lần'), findsOneWidget);
    final fields = tester.widgetList<TextFormField>(find.byType(TextFormField));
    expect([for (final field in fields) field.controller!.text],
        ['62,5', '10', '10', '10']);
  });
}
