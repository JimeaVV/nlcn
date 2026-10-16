import 'package:flutter/material.dart';

import '../core/cyber_theme.dart';
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
    final exercises = recommendation.exercises;
    final note = recommendation.note;

    return Column(
      children: [
        CyberCard(
          title: 'Session summary',
          accent: CyberColors.lime,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: MetricTile(
                      label: 'Target',
                      value: '${recommendation.targetTime}',
                      unit: 'min',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: MetricTile(
                      label: 'Estimated',
                      value: '${recommendation.estimatedTime}',
                      unit: 'min',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: MetricTile(
                      label: 'Exercises',
                      value: '${recommendation.totalExercises}',
                    ),
                  ),
                ],
              ),
              if (note.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(note, style: TextStyle(color: CyberColors.muted)),
              ],
              if (recommendation.levelFallbackUsed) ...[
                const SizedBox(height: 10),
                Text(
                  'Limited exercises for ${recommendation.requestedLevel}. '
                  'This plan includes: ${recommendation.usedLevels.join(', ')}.',
                  style: TextStyle(color: CyberColors.muted),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        CyberCard(
          title: 'Exercise sequence',
          accent: CyberColors.cyan,
          child: exercises.isEmpty
              ? const Text('No exercise data returned.')
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
                          subtitle: Text(
                            '${exercise.muscleGroup} • '
                            '${exercise.equipment} • '
                            '${exercise.estimatedMinutes} min',
                          ),
                          trailing: IconButton(
                            tooltip: logging ? 'Saving result' : 'Log result',
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
