import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optifit/models/recommendation_models.dart';
import 'package:optifit/screens/workout_screen.dart';
import 'package:optifit/services/recommendation_service.dart';
import 'package:optifit/widgets/exercise_log_dialog.dart';
import 'package:sqflite/sqflite.dart';

class _Recommendations extends RecommendationService {
  final requests = <({String split, String level, int minutes})>[];
  Completer<WorkoutRecommendation> response = Completer();

  @override
  Future<WorkoutRecommendation> recommendWorkout({
    required String split,
    required String level,
    required int minutes,
  }) {
    requests.add((split: split, level: level, minutes: minutes));
    return response.future;
  }
}

WorkoutRecommendation _workout() => WorkoutRecommendation.fromJson({
      'target_time': 45,
      'estimated_time': 10,
      'total_exercises': 1,
      'note': '',
      'data': [
        {
          'name': 'Bench Press',
          'muscle_group': 'Chest',
          'equipment': 'Barbell',
          'level': 'Beginner',
          'estimated_time_mins': 10,
        },
      ],
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('saved plan keeps the request metadata after selectors change', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final previousFactory = databaseFactoryOrNull;
    databaseFactoryOrNull = databaseFactorySqflitePlugin;
    addTearDown(() => databaseFactoryOrNull = previousFactory);
    const channel = MethodChannel('com.tekartik.sqflite');
    final inserts = <Map<dynamic, dynamic>>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'getDatabasesPath':
          return '/test-databases';
        case 'openDatabase':
          return {'id': 1};
        case 'query':
          return [
            {'user_version': 3}
          ];
        case 'insert':
          inserts.add(Map<dynamic, dynamic>.from(call.arguments as Map));
          return inserts.length;
        case 'execute':
        case 'closeDatabase':
          return null;
        default:
          throw StateError('Unexpected SQLite call: ${call.method}');
      }
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final recommendations = _Recommendations();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: WorkoutScreen(recommendations: recommendations)),
      ),
    );

    await tester.tap(find.text('GENERATE WORKOUT'));
    await tester.pump();
    expect(recommendations.requests.single, (
      split: 'Push',
      level: 'Beginner',
      minutes: 45,
    ));

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Pull').last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Pro • max 9 exercises').last);
    await tester.pump(const Duration(milliseconds: 300));

    recommendations.response.complete(_workout());
    await tester.pumpAndSettle();
    await tester.tap(find.text('SAVE WORKOUT PLAN'));
    await tester.pumpAndSettle();

    final saved = inserts.single;
    expect(saved['sql'], contains('workout_plan_history'));
    final arguments = saved['arguments'] as List;
    expect(arguments[0], 'Push');
    expect(arguments[1], 'Beginner');
    expect(
      (jsonDecode(arguments[4] as String) as Map)['data'][0]['name'],
      'Bench Press',
    );

    recommendations.response = Completer();
    await tester.tap(find.text('GENERATE WORKOUT'));
    await tester.pump();
    expect(find.text('SAVE WORKOUT PLAN'), findsNothing);
    expect(recommendations.requests.last, (
      split: 'Pull',
      level: 'Pro',
      minutes: 45,
    ));
    recommendations.response.completeError(
      const RecommendationException('No workout available.'),
    );
    await tester.pumpAndSettle();
    expect(find.text('No workout available.'), findsOneWidget);
    expect(find.text('SAVE WORKOUT PLAN'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exercise log rejects non-finite and excessive weight', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ExerciseLogDialog(exerciseName: 'Bench Press')),
      ),
    );

    for (final value in ['NaN', 'Infinity', '1001', '-1']) {
      await tester.enterText(find.byType(TextFormField).first, value);
      await tester.tap(find.text('Calculate'));
      await tester.pump();
      expect(find.text('Use a weight from 0 to 1000 kg.'), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
}
