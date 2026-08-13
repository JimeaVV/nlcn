import 'package:flutter/material.dart';

import '../core/cyber_theme.dart';
import '../models/history_models.dart';
import '../models/recommendation_models.dart';
import '../services/database_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  final db = DatabaseService.instance;

  bool loading = true;
  String? error;
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
        error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Could not load local history.';
      });
    }
  }

  String dateText(DateTime value) {
    final date = value.toLocal();
    String pad(int value) => value.toString().padLeft(2, '0');
    return '${pad(date.day)}/${pad(date.month)}/${date.year} '
        '${pad(date.hour)}:${pad(date.minute)}';
  }

  Future<void> showMeal(MealHistoryEntry entry) async {
    final response = db.tryDecodeJson(entry.planJson);
    DietRecommendation recommendation;
    try {
      recommendation = DietRecommendation.fromJson(response ?? {});
    } on FormatException {
      _showMessage('This saved meal plan is incomplete or corrupted.');
      return;
    }
    final mealData = recommendation.plan.meals;
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CyberColors.surface,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .75,
        maxChildSize: .92,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(18),
          children: [
            Text(
              'SAVED MEAL PLAN',
              style: TextStyle(
                color: CyberColors.cyan,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            ...mealData.entries.map((entry) {
              final meal = entry.value;
              final items = meal.items;
              return Card(
                color: CyberColors.surfaceAlt,
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key.toUpperCase(),
                        style: TextStyle(
                          color: CyberColors.magenta,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (items.isEmpty) const Text('No food items stored.'),
                      ...items.map((item) {
                        final prep = item.suggestedPrep;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: Text(
                            '• ${item.displayName}'
                            '${prep.isEmpty ? '' : '\n  Prep: $prep'}',
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            }),
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
      _showMessage('This saved workout plan is incomplete or corrupted.');
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
              'SAVED WORKOUT',
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
                  subtitle: Text(
                    '${exercise.muscleGroup} • '
                    '${exercise.equipment} • '
                    '${exercise.estimatedMinutes} min',
                  ),
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
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Delete'),
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
      'Delete $label?',
      'This record cannot be recovered after deletion.',
    );
    if (!confirmed) return;
    try {
      await delete();
      await refresh();
    } catch (_) {
      if (mounted) _showMessage('Could not delete the selected record.');
    }
  }

  Future<void> _clearAllHistory() async {
    final confirmed = await _confirm(
      'Clear all history?',
      'All saved meal plans, workout plans and Progressive Overload logs '
          'will be deleted. Your user profile will be preserved.',
    );
    if (!confirmed) return;
    try {
      await db.clearAllHistory();
      await refresh();
    } catch (_) {
      if (mounted) _showMessage('Could not clear local history.');
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

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'HISTORY ARCHIVE',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton(
                tooltip: 'Clear all history',
                onPressed: hasHistory ? _clearAllHistory : null,
                icon: const Icon(Icons.delete_sweep_outlined),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!, style: TextStyle(color: CyberColors.danger)),
          ],
          const SizedBox(height: 16),
          _HistoryHeading(title: 'MEAL PLANS', color: CyberColors.cyan),
          const SizedBox(height: 8),
          if (meals.isEmpty) const Text('No saved meal plans yet.'),
          ...meals.map(
            (row) => Card(
              child: ListTile(
                onTap: () => showMeal(row),
                leading: Icon(
                  Icons.restaurant_menu_rounded,
                  color: CyberColors.cyan,
                ),
                title: Text(
                  '${row.totalCalories.round()} kcal • '
                  '${row.totalProtein.toStringAsFixed(1)}g protein',
                ),
                subtitle: Text(dateText(row.createdAt)),
                trailing: IconButton(
                  tooltip: 'Delete meal plan',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteRecord(
                    label: 'meal plan',
                    delete: () => db.deleteMealPlan(row.id),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _HistoryHeading(title: 'WORKOUT PLANS', color: CyberColors.magenta),
          const SizedBox(height: 8),
          if (workouts.isEmpty) const Text('No saved workout plans yet.'),
          ...workouts.map(
            (row) => Card(
              child: ListTile(
                onTap: () => showWorkout(row),
                leading: Icon(
                  Icons.fitness_center_rounded,
                  color: CyberColors.magenta,
                ),
                title: Text('${row.split} • ${row.level}'),
                subtitle: Text(
                  '${row.estimatedTime} min • ${dateText(row.createdAt)}',
                ),
                trailing: IconButton(
                  tooltip: 'Delete workout plan',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteRecord(
                    label: 'workout plan',
                    delete: () => db.deleteWorkoutPlan(row.id),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _HistoryHeading(
            title: 'PROGRESSIVE OVERLOAD LOGS',
            color: CyberColors.lime,
          ),
          const SizedBox(height: 8),
          if (workoutLogs.isEmpty) const Text('No exercise logs yet.'),
          ...workoutLogs.map(
            (row) => Card(
              child: ListTile(
                leading: Icon(
                  Icons.trending_up_rounded,
                  color: CyberColors.lime,
                ),
                title: Text(row.exerciseName),
                subtitle: Text(
                  '${row.weight}kg • '
                  '${row.set1Reps}/${row.set2Reps}/${row.set3Reps} reps\n'
                  'Next: ${row.suggestedWeight}kg • '
                  'target ${row.suggestedReps} reps\n'
                  '${dateText(row.performedAt)}',
                ),
                isThreeLine: true,
                trailing: IconButton(
                  tooltip: 'Delete exercise log',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteRecord(
                    label: 'exercise log',
                    delete: () => db.deleteWorkoutLog(row.id),
                  ),
                ),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: Text(row.exerciseName),
                    content: Text(row.message),
                    actions: [
                      FilledButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('OK'),
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
