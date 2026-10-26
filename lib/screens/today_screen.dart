import 'package:flutter/material.dart';

import '../core/cyber_theme.dart';
import '../core/haptics.dart';
import '../engine/daily_habits.dart';
import '../engine/nutrition_targets.dart';
import '../l10n/l10n.dart';
import '../models/food_log_entry.dart';
import '../models/history_models.dart';
import '../models/user_profile.dart';
import '../models/weight_entry.dart';
import '../services/database_service.dart';
import '../services/home_widget_sync.dart';
import '../services/water_reminder_service.dart';
import '../widgets/cyber_card.dart';
import '../widgets/error_box.dart';
import '../widgets/info_button.dart';
import '../widgets/intake_summary.dart';
import '../widgets/water_glasses.dart';

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
    this.waterReminders,
  });

  /// Scheduled again whenever the day's water is known or changes.
  final WaterReminderController? waterReminders;

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
  int _water = 0;
  int _streak = 0;
  bool _loggedToday = false;
  WeekSummary? _week;
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
      // A year of daily totals covers the streak and the week. Both are
      // extras: the day's overview still shows if they fail.
      var days = const <DateTime, FoodLogTotals>{};
      var water = 0;
      try {
        days = await _database.getDailyTotals(
            DateTime(now.year, now.month, now.day - 365), now);
        water = await _database.getWater(now);
      } catch (_) {}
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
        _water = water;
        _streak = loggingStreak(days.keys, now);
        _loggedToday = food.isNotEmpty;
        _week = summarizeWeek(
          dailyTotals: days,
          workoutLogs: logs,
          weights: weights,
          today: now,
        );
        _loading = false;
        _loadFailed = false;
      });
      _syncHomeWidget();
      _refreshWaterReminders();
    } catch (_) {
      if (!mounted || version != _loadVersion) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  /// Adds [delta] ml (negative to remove) to what is already counted, so
  /// two quick taps count twice.
  Future<void> _addWater(int delta) async {
    final value = (_water + delta).clamp(0, 10000);
    Haptics.tap();
    setState(() => _water = value);
    try {
      await _database.setWater(DateTime.now(), value);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.diarySaveFailed)));
      }
    }
    _syncHomeWidget();
    _refreshWaterReminders();
  }

  /// Reaching the goal ends today's water reminders; opening the app also
  /// schedules the days ahead again.
  void _refreshWaterReminders() {
    widget.waterReminders?.refresh(
      texts: WaterReminderTexts.of(context.l10n),
      goalReachedToday: _water >= waterTargetMl,
    );
  }

  /// The home-screen widget shows the same numbers as this screen.
  void _syncHomeWidget() {
    if (!mounted) return;
    final l10n = context.l10n;
    final number = context.formatNumber;
    final target = (_targets?['target_calories'] as num?)?.toDouble();
    HomeWidgetSync.update(
      title: l10n.widgetTitle,
      calories: target == null
          ? '${number(_eaten.calories)}\u00A0kcal'
          : l10n.diaryCaloriesProgress(number(_eaten.calories), number(target)),
      water: l10n.widgetWater(number(_water / 1000, decimals: 1),
          number(waterTargetMl / 1000, decimals: 1)),
      streak: l10n.widgetStreak('$_streak'),
    );
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
                streak: _streak,
                loggedToday: _loggedToday,
                onOpenDiary: widget.onOpenDiary,
                onScan: widget.onScan,
              ),
              const SizedBox(height: 14),
              _WaterCard(ml: _water, onAdd: _addWater),
              const SizedBox(height: 14),
              if (_week != null) ...[
                _WeekCard(week: _week!, targets: _targets),
                const SizedBox(height: 14),
              ],
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
    required this.streak,
    required this.loggedToday,
    required this.onOpenDiary,
    required this.onScan,
  });

  final FoodLogTotals eaten;
  final Map<String, dynamic>? targets;
  final int streak;
  final bool loggedToday;
  final VoidCallback? onOpenDiary;
  final VoidCallback? onScan;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CyberCard(
      highlight: true,
      title: l10n.diaryEaten,
      icon: Icons.local_fire_department_outlined,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        StreakBadge(
            key: const ValueKey('today-streak'),
            days: streak,
            loggedToday: loggedToday),
        InfoButton(title: l10n.macroInfoTitle, paragraphs: [l10n.macroInfo]),
      ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (streak == 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(l10n.streakNone,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: CyberColors.muted)),
            ),
          IntakeSummary(totals: eaten, targets: targets),
          const SizedBox(height: 8),
          // Small links: the bar's scan button is the one that stands out.
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              TextButton.icon(
                key: const ValueKey('today-open-diary'),
                onPressed: onOpenDiary,
                icon: const Icon(Icons.menu_book_rounded),
                label: Text(l10n.todayOpenDiary),
              ),
              TextButton.icon(
                key: const ValueKey('today-scan'),
                onPressed: onScan,
                icon: const Icon(Icons.photo_camera_rounded),
                label: Text(l10n.navScan),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WaterCard extends StatelessWidget {
  const _WaterCard({required this.ml, required this.onAdd});

  final int ml;
  final ValueChanged<int> onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final number = context.formatNumber;
    return CyberCard(
      key: const ValueKey('today-water'),
      title: l10n.waterTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton.outlined(
                key: const ValueKey('water-remove'),
                tooltip: l10n.waterRemove,
                onPressed: ml == 0 ? null : () => onAdd(-waterGlassMl),
                icon: const Icon(Icons.remove_rounded),
              ),
              Expanded(
                child: Column(
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        l10n.waterProgress(number(ml), number(waterTargetMl)),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Text(
                      l10n.waterGlasses(
                          '${ml ~/ waterGlassMl}', '$waterGlassMl'),
                      style: TextStyle(color: CyberColors.muted),
                    ),
                  ],
                ),
              ),
              IconButton.filled(
                key: const ValueKey('water-add'),
                tooltip: l10n.waterAdd,
                onPressed: () => onAdd(waterGlassMl),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 4),
          WaterGlasses(ml: ml, onSet: (value) => onAdd(value - ml)),
          const SizedBox(height: 6),
          Text(l10n.waterNote,
              style: TextStyle(color: CyberColors.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.week, required this.targets});

  final WeekSummary week;
  final Map<String, dynamic>? targets;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final number = context.formatNumber;
    final target = (targets?['target_calories'] as num?)?.toDouble();
    final change = week.weightChange;
    final muted = TextStyle(color: CyberColors.muted);
    return CyberCard(
      key: const ValueKey('today-week'),
      title: l10n.weekTitle,
      child: week.loggedDays == 0 && week.trainingDays == 0 && change == null
          ? Text(l10n.weekEmpty, style: muted)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.weekLogged('${week.loggedDays}'),
                    style: Theme.of(context).textTheme.titleMedium),
                if (week.loggedDays > 0) ...[
                  const SizedBox(height: 4),
                  Text(l10n.weekAverage(number(week.averageCalories),
                      number(week.averageProtein, decimals: 1))),
                  if (target != null)
                    Text(
                      l10n.weekVsTarget(number(target),
                          context.formatSigned(week.averageCalories - target)),
                      style: muted,
                    ),
                ],
                const SizedBox(height: 4),
                Text(
                  [
                    l10n.weekTraining('${week.trainingDays}'),
                    if (change != null)
                      l10n.weekWeight(
                          context.formatSigned(change.kg, decimals: 1),
                          formatShortDate(change.since)),
                  ].join(' • '),
                  style: muted,
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
    // The same comparison as the week card, so both show one number.
    final change = weeklyWeightChange(weights);
    return CyberCard(
      title: l10n.weightTracking,
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
            if (change != null) ...[
              const SizedBox(height: 4),
              Text(
                l10n.todayWeightWeek(
                    context.formatSigned(change.kg, decimals: 1),
                    formatShortDate(change.since)),
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
