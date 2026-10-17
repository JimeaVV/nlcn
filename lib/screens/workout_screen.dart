import 'package:flutter/material.dart';

import '../core/cyber_theme.dart';
import '../engine/fitness_engine.dart';
import '../l10n/l10n.dart';
import '../models/recommendation_models.dart';
import '../services/recommendation_service.dart';
import '../services/database_service.dart';
import '../widgets/cyber_card.dart';
import '../widgets/error_box.dart';
import '../widgets/exercise_log_dialog.dart';
import '../widgets/neon_button.dart';
import '../widgets/workout_result.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({
    super.key,
    required this.recommendations,
    this.onHistoryChanged,
  });

  final RecommendationService recommendations;

  /// Called after a workout plan or an exercise log is saved.
  final VoidCallback? onHistoryChanged;

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
  RecommendationException? error;
  WorkoutRecommendation? result;

  /// The plan already saved, so a second tap cannot store a duplicate.
  WorkoutRecommendation? savedResult;
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
      if (mounted) setState(() => error = exception);
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
        saving ||
        identical(recommendation, savedResult)) {
      return;
    }
    setState(() => saving = true);
    try {
      await DatabaseService.instance.saveWorkoutPlan(
        split: savedSplit,
        level: savedLevel,
        recommendation: recommendation,
      );
      if (mounted) setState(() => savedResult = recommendation);
      widget.onHistoryChanged?.call();
      if (mounted) _showMessage(context.l10n.workoutSaved);
    } catch (_) {
      if (mounted) _showMessage(context.l10n.workoutSaveFailed);
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
      // The load only goes up after two good sessions in a row, so the
      // last session of this exercise is part of the decision.
      final history = await DatabaseService.instance.getWorkoutLogs();
      final previous = history
          .where((entry) => entry.exerciseName == exerciseName)
          .firstOrNull;
      final recommendation =
          await widget.recommendations.recommendProgressiveOverload(
        exerciseName: exerciseName,
        currentWeight: input.currentWeight,
        set1Reps: input.set1Reps,
        set2Reps: input.set2Reps,
        set3Reps: input.set3Reps,
        difficulty: input.difficulty,
        twoSessionRule: true,
        previousSession: previous,
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

      widget.onHistoryChanged?.call();
      if (!mounted) return;
      await _showProgressiveOverloadResult(recommendation);
    } on RecommendationException catch (exception) {
      if (mounted) {
        _showMessage(context.l10n.recommendationError(exception));
      }
    } catch (_) {
      if (mounted) _showMessage(context.l10n.exerciseLogSaveFailed);
    } finally {
      if (mounted) setState(() => logging = false);
    }
  }

  Future<void> _showProgressiveOverloadResult(
    ProgressiveOverloadRecommendation recommendation,
  ) async {
    final l10n = context.l10n;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.nextSessionTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.nextSessionSummary(
                context.formatMeasurement(recommendation.nextWeight),
                '${recommendation.nextRepTarget}',
              ),
              style: TextStyle(
                color: CyberColors.cyan,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Text(l10n.overloadMessage(
              recommendation.action,
              recommendation.message,
            )),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.ok),
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
    final l10n = context.l10n;
    String levelOption(String level) => l10n.levelOption(
        l10n.levelLabel(level), '${workoutExerciseLimits[level]}');
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          Text(l10n.workoutSubtitle,
              style: TextStyle(color: CyberColors.muted)),
          const SizedBox(height: 18),
          CyberCard(
            title: l10n.trainingSetup,
            icon: Icons.tune_rounded,
            accent: CyberColors.magenta,
            child: Form(
              key: formKey,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: split,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.workoutSplit,
                    ),
                    items: [
                      DropdownMenuItem(
                          value: 'Push', child: Text(l10n.splitPush)),
                      DropdownMenuItem(
                          value: 'Pull', child: Text(l10n.splitPull)),
                      DropdownMenuItem(
                          value: 'Legs', child: Text(l10n.splitLegs)),
                      DropdownMenuItem(
                          value: 'Core', child: Text(l10n.splitCore)),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => split = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: level,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.experienceLevel,
                    ),
                    items: [
                      for (final value in workoutExerciseLimits.keys)
                        DropdownMenuItem(
                          value: value,
                          child: Text(levelOption(value)),
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
                    decoration: InputDecoration(
                      labelText: l10n.availableTime,
                    ),
                    validator: (value) {
                      final number = int.tryParse(value?.trim() ?? '');
                      if (number == null || number < 15 || number > 180) {
                        return l10n.availableTimeError;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  NeonButton(
                    label: l10n.workoutGenerate,
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
            ErrorBox(message: l10n.recommendationError(error!)),
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
              key: const ValueKey('workout-save-plan'),
              onPressed:
                  saving || identical(result, savedResult) ? null : saveWorkout,
              icon: Icon(identical(result, savedResult)
                  ? Icons.check_rounded
                  : Icons.bookmark_add_outlined),
              label: Text(identical(result, savedResult)
                  ? l10n.planAlreadySaved
                  : saving
                      ? l10n.savingButton
                      : l10n.workoutSave),
            ),
          ],
        ],
      ),
    );
  }
}
