import 'package:flutter/material.dart';

import '../core/cyber_theme.dart';
import '../l10n/l10n.dart';
import '../models/history_models.dart';
import '../models/recommendation_models.dart';
import '../widgets/meal_result.dart';
import '../widgets/workout_result.dart';
import '../services/database_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  final db = DatabaseService.instance;

  bool loading = true;
  bool loadFailed = false;
  List<MealHistoryEntry> meals = [];
  List<WorkoutHistoryEntry> workouts = [];
  List<WorkoutLogEntry> workoutLogs = [];

  bool get hasHistory {
    return meals.isNotEmpty || workouts.isNotEmpty || workoutLogs.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    try {
      final mealFuture = db.getMealHistory();
      final workoutFuture = db.getWorkoutHistory();
      final logFuture = db.getWorkoutLogs();
      final mealRows = await mealFuture;
      final workoutRows = await workoutFuture;
      final logRows = await logFuture;
      if (!mounted) return;
      setState(() {
        meals = mealRows;
        workouts = workoutRows;
        workoutLogs = logRows;
        loading = false;
        loadFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        loadFailed = true;
      });
    }
  }

  Future<void> showMeal(MealHistoryEntry entry) async {
    final response = db.tryDecodeJson(entry.planJson);
    DietRecommendation recommendation;
    try {
      recommendation = DietRecommendation.fromJson(response ?? {});
    } on FormatException {
      _showMessage(context.l10n.savedMealCorrupted);
      return;
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CyberColors.surface,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .8,
        maxChildSize: .95,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(18),
          children: [
            Text(context.l10n.savedMealPlan,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            MealResult(recommendation: recommendation),
          ],
        ),
      ),
    );
  }

  Future<void> showWorkout(WorkoutHistoryEntry entry) async {
    final response = db.tryDecodeJson(entry.exercisesJson);
    WorkoutRecommendation recommendation;
    try {
      recommendation = WorkoutRecommendation.fromJson(response ?? {});
    } on FormatException {
      _showMessage(context.l10n.savedWorkoutCorrupted);
      return;
    }
    final items = recommendation.exercises;
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CyberColors.surface,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .7,
        maxChildSize: .92,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(18),
          children: [
            Text(
              context.l10n.savedWorkout,
              style: TextStyle(
                color: CyberColors.magenta,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(items.length, (index) {
              final exercise = items[index];
              return Card(
                color: CyberColors.surfaceAlt,
                child: ListTile(
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  title: Text(exercise.name),
                  subtitle: Text(exerciseDetails(context.l10n, exercise)),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirm(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(context.l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(context.l10n.delete),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deleteRecord({
    required String label,
    required Future<void> Function() delete,
  }) async {
    final confirmed = await _confirm(
      context.l10n.deleteRecordTitle(label),
      context.l10n.deleteRecordBody,
    );
    if (!confirmed) return;
    try {
      await delete();
      await refresh();
    } catch (_) {
      if (mounted) _showMessage(context.l10n.deleteRecordFailed);
    }
  }

  Future<void> _clearAllHistory() async {
    final confirmed = await _confirm(
      context.l10n.clearAllTitle,
      context.l10n.clearAllBody,
    );
    if (!confirmed) return;
    try {
      await db.clearAllHistory();
      await refresh();
    } catch (_) {
      if (mounted) _showMessage(context.l10n.clearAllFailed);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    final l10n = context.l10n;

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.historyTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton(
                tooltip: l10n.clearAllHistory,
                onPressed: hasHistory ? _clearAllHistory : null,
                icon: const Icon(Icons.delete_sweep_outlined),
              ),
            ],
          ),
          if (loadFailed) ...[
            const SizedBox(height: 8),
            Text(l10n.historyLoadFailed,
                style: TextStyle(color: CyberColors.danger)),
          ],
          const SizedBox(height: 16),
          _HistoryHeading(
              title: l10n.historyMealPlans, color: CyberColors.cyan),
          const SizedBox(height: 8),
          if (meals.isEmpty) Text(l10n.noMealPlans),
          ...meals.map(
            (row) => Card(
              child: ListTile(
                onTap: () => showMeal(row),
                leading: Icon(
                  Icons.restaurant_menu_rounded,
                  color: CyberColors.cyan,
                ),
                title: Text(
                  l10n.mealHistoryTitle(
                    context.formatNumber(row.totalCalories.round()),
                    context.formatNumber(row.totalProtein, decimals: 1),
                  ),
                ),
                subtitle: Text(formatDateTime(row.createdAt)),
                trailing: IconButton(
                  tooltip: l10n.deleteMealPlan,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteRecord(
                    label: l10n.recordMealPlan,
                    delete: () => db.deleteMealPlan(row.id),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _HistoryHeading(
              title: l10n.historyWorkoutPlans, color: CyberColors.magenta),
          const SizedBox(height: 8),
          if (workouts.isEmpty) Text(l10n.noWorkoutPlans),
          ...workouts.map(
            (row) => Card(
              child: ListTile(
                onTap: () => showWorkout(row),
                leading: Icon(
                  Icons.fitness_center_rounded,
                  color: CyberColors.magenta,
                ),
                title: Text('${row.split} • ${l10n.levelLabel(row.level)}'),
                subtitle: Text(
                  l10n.workoutHistorySubtitle(
                    '${row.estimatedTime}',
                    formatDateTime(row.createdAt),
                  ),
                ),
                trailing: IconButton(
                  tooltip: l10n.deleteWorkoutPlan,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteRecord(
                    label: l10n.recordWorkoutPlan,
                    delete: () => db.deleteWorkoutPlan(row.id),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _HistoryHeading(
            title: l10n.historyOverloadLogs,
            color: CyberColors.lime,
          ),
          const SizedBox(height: 8),
          if (workoutLogs.isEmpty) Text(l10n.noExerciseLogs),
          ...workoutLogs.map(
            (row) => Card(
              child: ListTile(
                leading: Icon(
                  Icons.trending_up_rounded,
                  color: CyberColors.lime,
                ),
                title: Text(row.exerciseName),
                subtitle: Text(
                  l10n.exerciseLogSubtitle(
                    context.formatMeasurement(row.weight),
                    '${row.set1Reps}/${row.set2Reps}/${row.set3Reps}',
                    context.formatMeasurement(row.suggestedWeight),
                    '${row.suggestedReps}',
                    formatDateTime(row.performedAt),
                  ),
                ),
                isThreeLine: true,
                trailing: IconButton(
                  tooltip: l10n.deleteExerciseLog,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteRecord(
                    label: l10n.recordExerciseLog,
                    delete: () => db.deleteWorkoutLog(row.id),
                  ),
                ),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: Text(row.exerciseName),
                    content:
                        Text(l10n.overloadMessage(row.action, row.message)),
                    actions: [
                      FilledButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text(l10n.ok),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryHeading extends StatelessWidget {
  const _HistoryHeading({required this.title, required this.color});

  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(color: color, fontWeight: FontWeight.w900),
    );
  }
}
