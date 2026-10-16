import 'package:flutter/material.dart';

import '../core/cyber_theme.dart';
import '../l10n/l10n.dart';
import '../models/recommendation_models.dart';
import 'cyber_card.dart';
import 'metric_tile.dart';

class WorkoutResult extends StatelessWidget {
  const WorkoutResult({
    super.key,
    required this.recommendation,
    required this.onLogExercise,
    this.logging = false,
  });

  final WorkoutRecommendation recommendation;
  final Future<void> Function(String exerciseName) onLogExercise;
  final bool logging;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final exercises = recommendation.exercises;
    // The engine's English note is stored with the plan; derive the text here
    // so it follows the selected language.
    final remaining = recommendation.targetTime - recommendation.estimatedTime;

    return Column(
      children: [
        CyberCard(
          title: l10n.sessionSummary,
          accent: CyberColors.lime,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: MetricTile(
                      label: l10n.targetLabel,
                      value: '${recommendation.targetTime}',
                      unit: l10n.minutesUnit,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: MetricTile(
                      label: l10n.estimatedLabel,
                      value: '${recommendation.estimatedTime}',
                      unit: l10n.minutesUnit,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: MetricTile(
                      label: l10n.exercisesLabel,
                      value: '${recommendation.totalExercises}',
                    ),
                  ),
                ],
              ),
              if (remaining > 0) ...[
                const SizedBox(height: 10),
                Text(l10n.remainingTimeNote('$remaining'),
                    style: TextStyle(color: CyberColors.muted)),
              ],
              if (recommendation.levelFallbackUsed) ...[
                const SizedBox(height: 10),
                Text(
                  l10n.levelFallbackNote(
                    l10n.levelLabel(recommendation.requestedLevel),
                    recommendation.usedLevels.map(l10n.levelLabel).join(', '),
                  ),
                  style: TextStyle(color: CyberColors.muted),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        CyberCard(
          title: l10n.exerciseSequence,
          accent: CyberColors.cyan,
          child: exercises.isEmpty
              ? Text(l10n.noExerciseData)
              : Column(
                  children: List.generate(exercises.length, (index) {
                    final exercise = exercises[index];
                    final exerciseName = exercise.name;
                    return Card(
                      color: CyberColors.surfaceAlt,
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: ListTile(
                          leading: CircleAvatar(child: Text('${index + 1}')),
                          title: Text(exerciseName),
                          subtitle: Text(exerciseDetails(l10n, exercise)),
                          trailing: IconButton(
                            tooltip:
                                logging ? l10n.savingResult : l10n.logResult,
                            onPressed: logging
                                ? null
                                : () => onLogExercise(exerciseName),
                            icon: Icon(
                              Icons.trending_up_rounded,
                              color: CyberColors.lime,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
        ),
      ],
    );
  }
}

/// Muscle group, equipment and duration in the selected language.
String exerciseDetails(
        AppLocalizations l10n, ExerciseRecommendation exercise) =>
    l10n.exerciseDetails(
      l10n.muscleLabel(exercise.muscleGroup),
      l10n.equipmentLabel(exercise.equipment),
      '${exercise.estimatedMinutes}',
    );
