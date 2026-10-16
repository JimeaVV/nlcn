import 'package:flutter/material.dart';

import '../core/cyber_theme.dart';
import '../models/recommendation_models.dart';
import '../services/recommendation_service.dart';
import '../services/database_service.dart';
import '../widgets/cyber_card.dart';
import '../widgets/exercise_log_dialog.dart';
import '../widgets/neon_button.dart';
import '../widgets/workout_result.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key, required this.recommendations});

  final RecommendationService recommendations;

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  final formKey = GlobalKey<FormState>();
  final timeController = TextEditingController(text: '45');

  String split = 'Push';
  String level = 'Beginner';
  bool loading = false;
  bool saving = false;
  bool logging = false;
  String? error;
  WorkoutRecommendation? result;
  String? resultSplit;
  String? resultLevel;

  @override
  void dispose() {
    timeController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (loading || saving) return;
    FocusScope.of(context).unfocus();
    if (!formKey.currentState!.validate()) return;

    final requestedSplit = split;
    final requestedLevel = level;
    final requestedMinutes = int.parse(timeController.text.trim());

    setState(() {
      loading = true;
      error = null;
      result = null;
      resultSplit = null;
      resultLevel = null;
    });

    try {
      final response = await widget.recommendations.recommendWorkout(
        split: requestedSplit,
        level: requestedLevel,
        minutes: requestedMinutes,
      );
      if (mounted) {
        setState(() {
          result = response;
          resultSplit = requestedSplit;
          resultLevel = requestedLevel;
        });
      }
    } on RecommendationException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> saveWorkout() async {
    final recommendation = result;
    final savedSplit = resultSplit;
    final savedLevel = resultLevel;
    if (recommendation == null ||
        savedSplit == null ||
        savedLevel == null ||
        saving) {
      return;
    }
    setState(() => saving = true);
    try {
      await DatabaseService.instance.saveWorkoutPlan(
        split: savedSplit,
        level: savedLevel,
        recommendation: recommendation,
      );
      if (mounted) _showMessage('Workout plan saved.');
    } catch (_) {
      if (mounted) _showMessage('Could not save the workout plan.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> logExercise(String exerciseName) async {
    if (logging) return;
    final input = await showDialog<ExerciseLogInput>(
      context: context,
      builder: (context) => ExerciseLogDialog(exerciseName: exerciseName),
    );
    if (input == null || !mounted) return;

    setState(() => logging = true);
    try {
      final recommendation =
          await widget.recommendations.recommendProgressiveOverload(
        exerciseName: exerciseName,
        currentWeight: input.currentWeight,
        set1Reps: input.set1Reps,
        set2Reps: input.set2Reps,
        set3Reps: input.set3Reps,
        difficulty: input.difficulty,
      );
      await DatabaseService.instance.saveWorkoutLog(
        exerciseName: exerciseName,
        currentWeight: input.currentWeight,
        set1Reps: input.set1Reps,
        set2Reps: input.set2Reps,
        set3Reps: input.set3Reps,
        difficulty: input.difficulty,
        recommendation: recommendation,
      );

      if (!mounted) return;
      await _showProgressiveOverloadResult(recommendation);
    } on RecommendationException catch (exception) {
      if (mounted) _showMessage(exception.message);
    } catch (_) {
      if (mounted) _showMessage('Could not save the exercise result.');
    } finally {
      if (mounted) setState(() => logging = false);
    }
  }

  Future<void> _showProgressiveOverloadResult(
    ProgressiveOverloadRecommendation recommendation,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Next-session recommendation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${recommendation.nextWeight} kg • 3 sets • '
              'target ${recommendation.nextRepTarget} reps',
              style: TextStyle(
                color: CyberColors.cyan,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Text(recommendation.message),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          Text(
            'WORKOUT PROTOCOL',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 18),
          CyberCard(
            title: 'Training setup',
            icon: Icons.tune_rounded,
            accent: CyberColors.magenta,
            child: Form(
              key: formKey,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: split,
                    decoration: const InputDecoration(
                      labelText: 'Workout split',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Push', child: Text('Push')),
                      DropdownMenuItem(value: 'Pull', child: Text('Pull')),
                      DropdownMenuItem(value: 'Legs', child: Text('Legs')),
                      DropdownMenuItem(value: 'Core', child: Text('Core')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => split = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: level,
                    decoration: const InputDecoration(
                      labelText: 'Experience level',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Beginner',
                        child: Text('Beginner • max 5 exercises'),
                      ),
                      DropdownMenuItem(
                        value: 'Intermediate',
                        child: Text('Intermediate • max 7 exercises'),
                      ),
                      DropdownMenuItem(
                        value: 'Pro',
                        child: Text('Pro • max 9 exercises'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => level = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: timeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Available time (minutes)',
                    ),
                    validator: (value) {
                      final number = int.tryParse(value?.trim() ?? '');
                      if (number == null || number < 15 || number > 180) {
                        return 'Use 15–180 minutes.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  NeonButton(
                    label: 'GENERATE WORKOUT',
                    icon: Icons.bolt_rounded,
                    color: CyberColors.magenta,
                    loading: loading,
                    onPressed: saving ? null : submit,
                  ),
                ],
              ),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(error!, style: TextStyle(color: CyberColors.danger)),
          ],
          if (result != null) ...[
            const SizedBox(height: 16),
            WorkoutResult(
              recommendation: result!,
              onLogExercise: logExercise,
              logging: logging,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: saving ? null : saveWorkout,
              icon: const Icon(Icons.bookmark_add_outlined),
              label: Text(saving ? 'SAVING...' : 'SAVE WORKOUT PLAN'),
            ),
          ],
        ],
      ),
    );
  }
}
