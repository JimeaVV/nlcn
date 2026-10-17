import 'package:flutter/material.dart';

import '../core/cyber_theme.dart';
import '../engine/nutrition_targets.dart';
import '../l10n/l10n.dart';
import '../models/food_log_entry.dart';
import '../models/history_models.dart';
import '../models/user_profile.dart';
import '../models/weight_entry.dart';
import '../services/database_service.dart';
import '../widgets/cyber_card.dart';
import '../widgets/error_box.dart';

/// Overview of the current day: intake against targets, weight trend and
/// training, with shortcuts into the other tabs.
class TodayScreen extends StatefulWidget {
  const TodayScreen({
    super.key,
    this.database,
    this.onOpenDiary,
    this.onOpenWorkout,
    this.onOpenProfile,
    this.onScan,
  });

  final DatabaseService? database;
  final VoidCallback? onOpenDiary;
  final VoidCallback? onOpenWorkout;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onScan;

  @override
  State<TodayScreen> createState() => TodayScreenState();
}

class TodayScreenState extends State<TodayScreen> {
  DatabaseService get _database => widget.database ?? DatabaseService.instance;

  bool _loading = true;
  bool _loadFailed = false;
  bool _hasProfile = false;
  Map<String, dynamic>? _targets;
  FoodLogTotals _eaten = const FoodLogTotals();
  List<WeightEntry> _weights = const [];
  List<WorkoutLogEntry> _todayLogs = const [];
  WorkoutHistoryEntry? _lastWorkout;
  int _loadVersion = 0;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final version = ++_loadVersion;
    try {
      final now = DateTime.now();
      final row = await _database.getProfile();
      final food = await _database.getFoodLog(now);
      final weights = await _database.getWeightHistory(limit: 30);
      final logs = await _database.getWorkoutLogs();
      final workouts = await _database.getWorkoutHistory();
      Map<String, dynamic>? targets;
      if (row != null) {
        try {
          targets = calculateNutritionTargets(UserProfile.fromMap(row));
        } on ArgumentError {
          targets = null;
        }
      }
      final today = diaryDateKey(now);
      if (!mounted || version != _loadVersion) return;
      setState(() {
        _hasProfile = row != null;
        _targets = targets;
        _eaten = FoodLogTotals.of(food);
        _weights = weights;
        _todayLogs = [
          for (final log in logs)
            if (diaryDateKey(log.performedAt) == today) log,
        ];
        _lastWorkout = workouts.isEmpty ? null : workouts.first;
        _loading = false;
        _loadFailed = false;
      });
    } catch (_) {
      if (!mounted || version != _loadVersion) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
          children: [
            Text(l10n.todayTitle,
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(formatDate(DateTime.now()),
                style: TextStyle(color: CyberColors.muted)),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_loadFailed)
              ErrorBox(message: l10n.todayLoadFailed)
            else ...[
              if (!_hasProfile) ...[
                _ProfilePrompt(onOpenProfile: widget.onOpenProfile),
                const SizedBox(height: 14),
              ],
              _NutritionCard(
                eaten: _eaten,
                targets: _targets,
                onOpenDiary: widget.onOpenDiary,
                onScan: widget.onScan,
              ),
              const SizedBox(height: 14),
              _WeightCard(weights: _weights, onOpen: widget.onOpenProfile),
              const SizedBox(height: 14),
              _TrainingCard(
                todayLogs: _todayLogs,
                lastWorkout: _lastWorkout,
                onOpen: widget.onOpenWorkout,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfilePrompt extends StatelessWidget {
  const _ProfilePrompt({required this.onOpenProfile});

  final VoidCallback? onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CyberCard(
      title: l10n.mealProfileRequiredTitle,
      icon: Icons.person_outline_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.diaryNoTarget),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: onOpenProfile,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: Text(l10n.mealOpenProfile),
          ),
        ],
      ),
    );
  }
}

class _NutritionCard extends StatelessWidget {
  const _NutritionCard({
    required this.eaten,
    required this.targets,
    required this.onOpenDiary,
    required this.onScan,
  });

  final FoodLogTotals eaten;
  final Map<String, dynamic>? targets;
  final VoidCallback? onOpenDiary;
  final VoidCallback? onScan;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final number = context.formatNumber;
    final calorieTarget = (targets?['target_calories'] as num?)?.toDouble();
    final proteinTarget = (targets?['protein_target'] as num?)?.toDouble();
    return CyberCard(
      title: l10n.diaryEaten,
      icon: Icons.local_fire_department_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            calorieTarget == null
                ? '${number(eaten.calories)} kcal'
                : l10n.diaryCaloriesProgress(
                    number(eaten.calories), number(calorieTarget)),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (calorieTarget != null) ...[
            const SizedBox(height: 6),
            _Bar(value: eaten.calories, target: calorieTarget),
            const SizedBox(height: 6),
            Text(
              eaten.calories <= calorieTarget
                  ? l10n.diaryRemaining(number(calorieTarget - eaten.calories))
                  : l10n.diaryOver(number(eaten.calories - calorieTarget)),
              style: TextStyle(color: CyberColors.muted),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            proteinTarget == null
                ? l10n.proteinGrams(number(eaten.protein, decimals: 1))
                : l10n.diaryProteinProgress(number(eaten.protein, decimals: 1),
                    number(proteinTarget, decimals: 1)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('today-open-diary'),
                  onPressed: onOpenDiary,
                  icon: const Icon(Icons.menu_book_rounded),
                  label: Text(l10n.todayOpenDiary),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('today-scan'),
                  onPressed: onScan,
                  icon: const Icon(Icons.photo_camera_rounded),
                  label: Text(l10n.navScan),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeightCard extends StatelessWidget {
  const _WeightCard({required this.weights, required this.onOpen});

  final List<WeightEntry> weights;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final latest = weights.isEmpty ? null : weights.first;
    // Compare with the newest weigh-in that is at least a week older.
    final weekAgo = latest == null
        ? null
        : weights.where((entry) =>
            latest.recordedAt.difference(entry.recordedAt).inDays >= 7);
    final previous = weekAgo == null || weekAgo.isEmpty ? null : weekAgo.first;
    return CyberCard(
      title: l10n.weightTracking,
      icon: Icons.monitor_weight_outlined,
      accent: CyberColors.magenta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (latest == null)
            Text(l10n.noWeights)
          else ...[
            Text(
              l10n.latestWeight(context.formatMeasurement(latest.weight),
                  formatDate(latest.recordedAt)),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (previous != null) ...[
              const SizedBox(height: 4),
              Text(
                l10n.todayWeightWeek(context.formatSigned(
                    latest.weight - previous.weight,
                    decimals: 1)),
                style: TextStyle(color: CyberColors.muted),
              ),
            ],
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.logWeight),
          ),
        ],
      ),
    );
  }
}

class _TrainingCard extends StatelessWidget {
  const _TrainingCard({
    required this.todayLogs,
    required this.lastWorkout,
    required this.onOpen,
  });

  final List<WorkoutLogEntry> todayLogs;
  final WorkoutHistoryEntry? lastWorkout;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final last = lastWorkout;
    return CyberCard(
      title: l10n.navWorkout,
      icon: Icons.fitness_center_rounded,
      accent: CyberColors.lime,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            todayLogs.isEmpty
                ? l10n.todayNoExercise
                : l10n.todayExercisesLogged('${todayLogs.length}'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (last != null) ...[
            const SizedBox(height: 4),
            Text(
              l10n.todayLastWorkout(
                  '${last.split} • ${l10n.levelLabel(last.level)}',
                  formatDate(last.createdAt.toLocal())),
              style: TextStyle(color: CyberColors.muted),
            ),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.bolt_rounded),
            label: Text(l10n.workoutGenerate),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.target});

  final double value;
  final double target;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(
          minHeight: 8,
          value: target > 0 ? (value / target).clamp(0.0, 1.0) : 0,
          color: value > target ? Colors.orange : CyberColors.lime,
          backgroundColor: CyberColors.surfaceAlt,
        ),
      );
}
