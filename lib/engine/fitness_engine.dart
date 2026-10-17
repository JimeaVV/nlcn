import 'dart:math' as math;

import 'number_utils.dart';

/// The existing FastAPI fitness rules, executed entirely on the device.
///
/// Result keys match the previous HTTP responses so saved plans remain readable.
const workoutExerciseLimits = {'Beginner': 5, 'Intermediate': 7, 'Pro': 9};
const _splitMuscles = {
  'Push': ['Chest', 'Shoulders', 'Triceps'],
  'Pull': ['Back', 'Biceps', 'Lats', 'Forearms', 'Traps'],
  'Legs': [
    'Quadriceps',
    'Hamstrings',
    'Calves',
    'Glutes',
    'Adductors',
    'Abductors',
  ],
  'Core': ['Abdominals'],
};
const _levelRanks = {'beginner': 0, 'intermediate': 1, 'pro': 2};

int estimateExerciseTime(String equipment) {
  final normalized = equipment.toLowerCase();
  if (normalized.contains('barbell')) return 12;
  if (normalized.contains('machine') || normalized.contains('dumbbell')) {
    return 10;
  }
  return 7;
}

Map<String, dynamic> recommendWorkoutRoutine(
  List<Map<String, dynamic>> exercises, {
  required String targetSplit,
  required String targetLevel,
  int availableTimeMins = 45,
}) {
  final muscles = _splitMuscles[targetSplit];
  if (muscles == null) {
    throw ArgumentError('Workout split must be Push, Pull, Legs or Core.');
  }
  final limit = workoutExerciseLimits[targetLevel];
  if (limit == null) {
    throw ArgumentError(
        'Experience level must be Beginner, Intermediate or Pro.');
  }
  if (availableTimeMins < 15 || availableTimeMins > 180) {
    throw ArgumentError(
        'Available workout time must be between 15 and 180 minutes.');
  }

  final candidates = <_WorkoutCandidate>[];
  final targetRank = _levelRanks[targetLevel.toLowerCase()]!;
  for (var index = 0; index < exercises.length; index++) {
    final exercise = exercises[index];
    for (final key in ['name', 'muscle_group', 'equipment', 'level']) {
      if (exercise[key] is! String) {
        throw ArgumentError('Exercise dataset is missing a valid $key.');
      }
    }
    final muscleGroup = (exercise['muscle_group'] as String).toLowerCase();
    if (!muscles.any((muscle) => muscleGroup.contains(muscle.toLowerCase()))) {
      continue;
    }
    final equipment = exercise['equipment'] as String;
    final level = exercise['level'] as String;
    final rank = _levelRanks[level.trim().toLowerCase()];
    var score =
        rank == null ? 0 : math.max(0, 6 - (rank - targetRank).abs() * 3);
    final normalizedEquipment = equipment.toLowerCase();
    if (normalizedEquipment.contains('barbell') ||
        normalizedEquipment.contains('dumbbell')) {
      score += 2;
    }
    final rawTime = exercise['estimated_time_mins'];
    final parsedTime =
        rawTime is num ? rawTime.toDouble() : double.tryParse('$rawTime');
    final estimatedTime =
        parsedTime != null && parsedTime.isFinite && parsedTime > 0
            ? parsedTime.toInt()
            : estimateExerciseTime(equipment);
    candidates.add(_WorkoutCandidate(
      sourceIndex: index,
      muscleGroup: muscleGroup,
      row: {
        'name': exercise['name'],
        'muscle_group': exercise['muscle_group'],
        'equipment': equipment,
        'level': level,
        'estimated_time_mins': estimatedTime,
        'score': score,
      },
    ));
  }
  if (candidates.isEmpty) {
    throw StateError('No exercises are available for the $targetSplit split.');
  }
  candidates.sort((a, b) {
    var comparison = b.score.compareTo(a.score);
    if (comparison == 0) comparison = a.minutes.compareTo(b.minutes);
    if (comparison == 0) comparison = a.name.compareTo(b.name);
    if (comparison == 0) comparison = a.sourceIndex.compareTo(b.sourceIndex);
    return comparison;
  });
  final grouped = {
    for (final muscle in muscles)
      muscle: candidates
          .where(
              (exercise) => exercise.muscleGroup.contains(muscle.toLowerCase()))
          .toList(),
  };
  final positions = {for (final muscle in muscles) muscle: 0};
  final usedNames = <String>{};
  final routine = <Map<String, dynamic>>[];
  var usedMinutes = 0;
  while (routine.length < limit) {
    var added = false;
    for (final muscle in muscles) {
      if (routine.length >= limit) break;
      final choices = grouped[muscle]!;
      while (positions[muscle]! < choices.length) {
        final exercise = choices[positions[muscle]!];
        positions[muscle] = positions[muscle]! + 1;
        final normalizedName = exercise.name.trim().toLowerCase();
        if (normalizedName.isEmpty || usedNames.contains(normalizedName)) {
          continue;
        }
        // A later candidate may still fit even when the highest score does not.
        if (usedMinutes + exercise.minutes > availableTimeMins) continue;
        routine.add(exercise.row);
        usedNames.add(normalizedName);
        usedMinutes += exercise.minutes;
        added = true;
        break;
      }
    }
    if (!added) break;
  }
  if (routine.isEmpty) {
    throw StateError('No exercises fit the requested workout constraints.');
  }
  final remaining = math.max(0, availableTimeMins - usedMinutes);
  final usedLevels =
      routine.map((row) => row['level'] as String).toSet().toList()..sort();
  return {
    'status': 'success',
    'message': 'Workout plan generated successfully!',
    'target_time': availableTimeMins,
    'estimated_time': usedMinutes,
    'remaining_time': remaining,
    'total_exercises': routine.length,
    'exercise_limit': limit,
    'requested_level': targetLevel,
    'used_levels': usedLevels,
    'level_fallback_used': usedLevels
        .any((level) => level.toLowerCase() != targetLevel.toLowerCase()),
    'note': remaining > 0
        ? 'Remaining time can be used for warm-up, rest between sets, cool-down or cardio.'
        : '',
    'data': routine,
  };
}

/// Suggests the next session for one exercise from 3 working sets.
///
/// Loads move in 2.5 kg steps, the smallest plate pair in a gym. With
/// [twoSessionRule] the load only goes up after two sessions in a row at
/// the same load reached 3x12 comfortably: the app passes the previous
/// session as [previousSession] (`weight`, `reps`, `difficulty`), or null
/// when there is none. Bodyweight work (0 kg) progresses by reps instead.
Map<String, dynamic> suggestProgressiveOverload({
  required String exerciseName,
  required double currentWeight,
  required List<int> repsPerSet,
  required String difficulty,
  bool twoSessionRule = false,
  Map<String, dynamic>? previousSession,
}) {
  if (exerciseName.isEmpty || exerciseName.runes.length > 200) {
    throw ArgumentError(
        'Exercise name must contain between 1 and 200 characters.');
  }
  _validateNumber(currentWeight, 'Current weight', 0, 1000);
  if (repsPerSet.length != 3) {
    throw ArgumentError('Exactly 3 sets are required.');
  }
  if (repsPerSet.any((reps) => reps < 0 || reps > 30)) {
    throw ArgumentError('Each set must contain between 0 and 30 reps.');
  }
  if (!_difficulties.contains(difficulty)) {
    throw ArgumentError('Difficulty must be Easy, Moderate, Hard or Failure.');
  }
  final totalReps = repsPerSet.fold(0, (sum, reps) => sum + reps);
  final completed = repsPerSet.every((reps) => reps >= 12);
  final belowMinimum = repsPerSet.any((reps) => reps < 8);
  final bodyweight = currentWeight == 0;
  var nextWeight = currentWeight;
  var nextRepTarget = 12;
  late String action;
  late String message;
  if (completed && (difficulty == 'Easy' || difficulty == 'Moderate')) {
    if (bodyweight) {
      nextRepTarget = math.min(30, repsPerSet.reduce(math.max) + 2);
      action = 'increase_reps_bodyweight';
      message = 'Completed 3x12 without added load. Add 2 reps per set next '
          'session, or move to a harder variation.';
    } else if (twoSessionRule &&
        !_comfortableAtTarget(previousSession, currentWeight)) {
      action = 'confirm_increase';
      message = 'First comfortable 3x12 at this load. Repeat it once more; '
          'if it is comfortable again, add 2.5kg.';
    } else {
      nextWeight += 2.5;
      nextRepTarget = 8;
      action = 'increase_weight';
      message = 'Completed 3x12 with manageable difficulty. Increase the load '
          'by 2.5kg next session and restart within the 8-12 rep range.';
    }
  } else if (completed) {
    // Hard, or reached failure only on the last reps: the target was met.
    action = 'maintain_weight';
    message = 'Completed 3x12, but effort was high. Keep the same load for one '
        'more session before increasing it.';
  } else if (difficulty == 'Failure' || belowMinimum) {
    nextRepTarget = 8;
    if (bodyweight) {
      action = 'decrease_reps_bodyweight';
      message = 'Performance fell below the target rep range. Aim for 8 clean '
          'reps per set, or use an easier variation.';
    } else {
      nextWeight = math.max(0, currentWeight - 2.5);
      action = 'decrease_weight';
      message = 'Performance fell below the target rep range. Reduce the load '
          'by 2.5kg and prioritize controlled technique.';
    }
  } else {
    action = 'increase_reps';
    message =
        'Keep the same load and try to add reps until all three sets reach '
        '12 reps.';
  }
  return {
    'status': 'success',
    'message': 'Progressive overload recommendation generated.',
    'exercise_name': exerciseName,
    'data': {
      'current_weight': roundLikePython(currentWeight),
      'set_1_reps': repsPerSet[0],
      'set_2_reps': repsPerSet[1],
      'set_3_reps': repsPerSet[2],
      'total_reps': totalReps,
      'difficulty': difficulty,
      'target_sets': 3,
      'rep_range_min': 8,
      'rep_range_max': 12,
      'next_weight': roundLikePython(nextWeight),
      'next_rep_target': nextRepTarget,
      'action': action,
      'message': message,
    },
  };
}

const _difficulties = {'Easy', 'Moderate', 'Hard', 'Failure'};

/// Whether [session] reached 3x12 comfortably at [weight].
bool _comfortableAtTarget(Map<String, dynamic>? session, double weight) {
  if (session == null) return false;
  final reps = session['reps'];
  final previousWeight = session['weight'];
  return previousWeight is num &&
      (previousWeight - weight).abs() < 0.01 &&
      reps is List &&
      reps.length == 3 &&
      reps.every((r) => r is int && r >= 12) &&
      (session['difficulty'] == 'Easy' || session['difficulty'] == 'Moderate');
}

void _validateNumber(double value, String name, double minimum, double maximum,
    {bool allowZero = true}) {
  if (!value.isFinite ||
      value > maximum ||
      (allowZero ? value < minimum : value <= minimum)) {
    throw ArgumentError(
        '$name must be ${allowZero ? 'at least' : 'greater than'} '
        '$minimum and at most $maximum.');
  }
}

class _WorkoutCandidate {
  const _WorkoutCandidate(
      {required this.sourceIndex,
      required this.muscleGroup,
      required this.row});

  final int sourceIndex;
  final String muscleGroup;
  final Map<String, dynamic> row;
  String get name => row['name'] as String;
  int get minutes => row['estimated_time_mins'] as int;
  int get score => row['score'] as int;
}
