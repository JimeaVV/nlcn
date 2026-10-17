import 'package:flutter_test/flutter_test.dart';
import 'package:optifit/engine/fitness_engine.dart';
import 'package:optifit/models/recommendation_models.dart';

Map<String, dynamic> exercise(
  String name,
  String muscle, {
  String equipment = 'Body Only',
  String level = 'Beginner',
  Object? minutes,
}) =>
    {
      'name': name,
      'muscle_group': muscle,
      'equipment': equipment,
      'level': level,
      if (minutes != null) 'estimated_time_mins': minutes,
    };

void main() {
  group('workout rule parity', () {
    test('prefers exact experience level over the free weight bonus', () {
      final result = recommendWorkoutRoutine([
        exercise('Exact-level exercise', 'Abdominals'),
        exercise('Adjacent-level exercise', 'Abdominals',
            equipment: 'Barbell', level: 'Intermediate'),
      ], targetSplit: 'Core', targetLevel: 'Beginner', availableTimeMins: 15);
      final parsed = WorkoutRecommendation.fromJson(result);
      expect(parsed.exercises.single.name, 'Exact-level exercise');
      expect(parsed.estimatedTime, 7);
      expect(result['level_fallback_used'], isFalse);
      expect(result['used_levels'], ['Beginner']);
    });

    test('continues searching for a shorter candidate that fits', () {
      final result = recommendWorkoutRoutine([
        exercise('Chest machine', 'Chest', equipment: 'Machine'),
        exercise('Long shoulder exercise', 'Shoulders', equipment: 'Barbell'),
        exercise('Short shoulder exercise', 'Shoulders'),
      ], targetSplit: 'Push', targetLevel: 'Beginner', availableTimeMins: 17);
      expect(result, {
        'status': 'success',
        'message': 'Workout plan generated successfully!',
        'target_time': 17,
        'estimated_time': 17,
        'remaining_time': 0,
        'total_exercises': 2,
        'exercise_limit': 5,
        'requested_level': 'Beginner',
        'used_levels': ['Beginner'],
        'level_fallback_used': false,
        'note': '',
        'data': [
          {
            ...exercise('Chest machine', 'Chest', equipment: 'Machine'),
            'estimated_time_mins': 10,
            'score': 6
          },
          {
            ...exercise('Short shoulder exercise', 'Shoulders'),
            'estimated_time_mins': 7,
            'score': 6
          },
        ],
      });
    });

    test('respects all experience limits and balances muscle groups', () {
      final exercises = [
        for (final muscle in ['Chest', 'Shoulders', 'Triceps'])
          for (var index = 0; index < 10; index++)
            exercise('$muscle $index', muscle),
      ];
      for (final entry in workoutExerciseLimits.entries) {
        final result = recommendWorkoutRoutine(exercises,
            targetSplit: 'Push',
            targetLevel: entry.key,
            availableTimeMins: 180);
        final data = result['data'] as List<Map<String, dynamic>>;
        expect(data.length, entry.value);
        expect(result['estimated_time'], entry.value * 7);
        expect(data.take(3).map((row) => row['muscle_group']),
            ['Chest', 'Shoulders', 'Triceps']);
      }
    });

    test('deduplicates names across overlapping muscle groups', () {
      final result = recommendWorkoutRoutine([
        exercise('Bench Press', 'Chest, Shoulders', equipment: 'Barbell'),
        exercise(' bench press ', 'Chest', equipment: 'Dumbbell'),
        exercise('Triceps extension', 'Triceps'),
      ], targetSplit: 'Push', targetLevel: 'Beginner');
      final data = result['data'] as List<Map<String, dynamic>>;
      expect(data.length, 2);
      expect(
          data
              .where((row) =>
                  (row['name'] as String).trim().toLowerCase() == 'bench press')
              .length,
          1);
    });

    test('reports fallback and preserves dataset rows without mutating input',
        () {
      final row = exercise('Intermediate crunch', 'Abdominals',
          level: 'Intermediate', minutes: '9.5');
      final original = Map<String, dynamic>.from(row);
      final result = recommendWorkoutRoutine([row],
          targetSplit: 'Core', targetLevel: 'Pro');
      expect(result['requested_level'], 'Pro');
      expect(result['used_levels'], ['Intermediate']);
      expect(result['level_fallback_used'], isTrue);
      expect(result['estimated_time'], 9);
      expect(result['note'], contains('warm-up'));
      expect((result['data'] as List).single['score'], 3);
      expect(row, original);
    });

    test('uses equipment estimates when the dataset time is invalid', () {
      expect(estimateExerciseTime('BARBELL'), 12);
      expect(estimateExerciseTime('Dumbbell'), 10);
      expect(estimateExerciseTime('Machine'), 10);
      expect(estimateExerciseTime('Body Only'), 7);
      final result = recommendWorkoutRoutine([
        exercise('Crunch', 'Abdominals', minutes: -5),
      ], targetSplit: 'Core', targetLevel: 'Beginner');
      expect(result['estimated_time'], 7);
    });

    test('rejects invalid requests and distinguishes no available routine', () {
      final rows = [exercise('Crunch', 'Abdominals')];
      expect(
          () => recommendWorkoutRoutine(rows,
              targetSplit: 'Unknown', targetLevel: 'Beginner'),
          throwsArgumentError);
      expect(
          () => recommendWorkoutRoutine(rows,
              targetSplit: 'Core', targetLevel: 'Expert'),
          throwsArgumentError);
      for (final minutes in [14, 181]) {
        expect(
            () => recommendWorkoutRoutine(rows,
                targetSplit: 'Core',
                targetLevel: 'Beginner',
                availableTimeMins: minutes),
            throwsArgumentError);
      }
      expect(
          () => recommendWorkoutRoutine([],
              targetSplit: 'Core', targetLevel: 'Beginner'),
          throwsStateError);
      expect(
          () => recommendWorkoutRoutine(rows,
              targetSplit: 'Legs', targetLevel: 'Beginner'),
          throwsStateError);
      expect(
          () => recommendWorkoutRoutine([
                exercise('Long crunch', 'Abdominals', minutes: 20),
              ],
                  targetSplit: 'Core',
                  targetLevel: 'Beginner',
                  availableTimeMins: 15),
          throwsStateError);
    });
  });

  group('progressive overload rule parity', () {
    Map<String, dynamic> recommend(List<int> reps, String difficulty,
            {double weight = 50}) =>
        suggestProgressiveOverload(
          exerciseName: 'Bench Press',
          currentWeight: weight,
          repsPerSet: reps,
          difficulty: difficulty,
        );

    test('preserves complete endpoint envelope and increase-weight branch', () {
      final result = recommend([12, 12, 12], 'Moderate');
      expect(result, {
        'status': 'success',
        'message': 'Progressive overload recommendation generated.',
        'exercise_name': 'Bench Press',
        'data': {
          'current_weight': 50.0,
          'set_1_reps': 12,
          'set_2_reps': 12,
          'set_3_reps': 12,
          'total_reps': 36,
          'difficulty': 'Moderate',
          'target_sets': 3,
          'rep_range_min': 8,
          'rep_range_max': 12,
          'next_weight': 52.5,
          'next_rep_target': 8,
          'action': 'increase_weight',
          'message':
              'Completed 3x12 with manageable difficulty. Increase the load by '
                  '2.5kg next session and restart within the 8-12 rep range.',
        },
      });
      expect(
          ProgressiveOverloadRecommendation.fromJson(result).nextWeight, 52.5);
      expect(
          recommend([13, 12, 15], 'Easy')['data']['action'], 'increase_weight');
    });

    test('maintains heavy sets and increases reps on incomplete sets', () {
      final hard = recommend([12, 12, 12], 'Hard')['data'];
      expect(hard['action'], 'maintain_weight');
      expect(hard['next_weight'], 50.0);
      expect(hard['next_rep_target'], 12);
      expect(recommend([10, 10, 10], 'Moderate')['data']['action'],
          'increase_reps');
      expect(recommend([8, 8, 8], 'Easy')['data']['action'], 'increase_reps');
    });

    test('reduces load on failure or any low set, never below zero', () {
      expect(recommend([10, 10, 10], 'Failure')['data']['action'],
          'decrease_weight');
      // Reaching 3x12 even at failure met the target: keep the load.
      expect(recommend([12, 12, 12], 'Failure')['data']['action'],
          'maintain_weight');
      expect(recommend([7, 12, 12], 'Easy')['data']['next_weight'], 47.5);
      final result = recommend([7, 8, 8], 'Hard', weight: 1)['data'];
      expect(result['next_weight'], 0.0);
      expect(result['next_rep_target'], 8);
    });

    test('with history, the load rises only after two good sessions', () {
      Map<String, dynamic> next(Map<String, dynamic>? previous) =>
          suggestProgressiveOverload(
            exerciseName: 'Bench Press',
            currentWeight: 50,
            repsPerSet: const [12, 12, 12],
            difficulty: 'Moderate',
            twoSessionRule: true,
            previousSession: previous,
          )['data'] as Map<String, dynamic>;
      final first = next(null);
      expect(first['action'], 'confirm_increase');
      expect(first['next_weight'], 50.0);
      expect(
          next({
            'weight': 50.0,
            'reps': [12, 13, 12],
            'difficulty': 'Easy',
          })['next_weight'],
          52.5);
      // A good session at another load, or a hard one, does not count.
      for (final previous in [
        {
          'weight': 47.5,
          'reps': [12, 12, 12],
          'difficulty': 'Easy'
        },
        {
          'weight': 50.0,
          'reps': [12, 12, 12],
          'difficulty': 'Hard'
        },
        {
          'weight': 50.0,
          'reps': [12, 11, 12],
          'difficulty': 'Easy'
        },
      ]) {
        expect(next(previous)['action'], 'confirm_increase');
      }
    });

    test('bodyweight work progresses by reps, not by load', () {
      final easy = recommend([12, 14, 12], 'Easy', weight: 0)['data'];
      expect(easy['action'], 'increase_reps_bodyweight');
      expect(easy['next_weight'], 0.0);
      expect(easy['next_rep_target'], 16);
      final failed = recommend([6, 5, 5], 'Failure', weight: 0)['data'];
      expect(failed['action'], 'decrease_reps_bodyweight');
      expect(failed['next_rep_target'], 8);
    });

    test('matches Python float rounding including halfway and binary cases',
        () {
      for (final entry
          in {1.125: 1.12, 1.375: 1.38, 2.675: 2.67, 2.685: 2.69}.entries) {
        expect(
            recommend([10, 10, 10], 'Moderate', weight: entry.key)['data']
                ['current_weight'],
            entry.value);
      }
    });

    test('validates endpoint bounds and requires three sets', () {
      for (final weight in [-1.0, 1001.0, double.nan, double.infinity]) {
        expect(() => recommend([12, 12, 12], 'Moderate', weight: weight),
            throwsArgumentError);
      }
      for (final reps in [
        [12],
        [12, 12, 12, 12],
        [-1, 12, 12],
        [31, 12, 12]
      ]) {
        expect(() => recommend(reps, 'Moderate'), throwsArgumentError);
      }
      expect(() => recommend([12, 12, 12], 'Unknown'), throwsArgumentError);
      expect(
          () => suggestProgressiveOverload(
              exerciseName: '',
              currentWeight: 0,
              repsPerSet: [12, 12, 12],
              difficulty: 'Easy'),
          throwsArgumentError);
      expect(
          () => suggestProgressiveOverload(
              exerciseName: 'x' * 201,
              currentWeight: 0,
              repsPerSet: [12, 12, 12],
              difficulty: 'Easy'),
          throwsArgumentError);
    });
  });
}
