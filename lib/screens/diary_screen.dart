import 'package:flutter/material.dart';

import '../core/cyber_theme.dart';
import '../engine/nutrition_targets.dart';
import '../l10n/l10n.dart';
import '../models/food_log_entry.dart';
import '../models/user_profile.dart';
import '../services/database_service.dart';
import '../services/dataset_repository.dart';
import '../widgets/cyber_card.dart';
import '../widgets/error_box.dart';
import '../widgets/food_log_sheet.dart';
import '../widgets/neon_button.dart';

/// What the user ate on one day, compared with the saved profile targets.
class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key, this.database, this.datasets});

  final DatabaseService? database;
  final DatasetRepository? datasets;

  @override
  State<DiaryScreen> createState() => DiaryScreenState();
}

class DiaryScreenState extends State<DiaryScreen> {
  late final DatasetRepository _datasets =
      widget.datasets ?? DatasetRepository();
  DatabaseService get _database => widget.database ?? DatabaseService.instance;

  DateTime _day = _today();
  List<FoodLogEntry> _entries = const [];
  Map<String, dynamic>? _targets;
  bool _loading = true;
  bool _loadFailed = false;
  bool _saving = false;
  int _loadVersion = 0;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool get _isToday => _day == _today();

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final version = ++_loadVersion;
    try {
      final entries = await _database.getFoodLog(_day);
      final row = await _database.getProfile();
      Map<String, dynamic>? targets;
      if (row != null) {
        try {
          targets = calculateNutritionTargets(UserProfile.fromMap(row));
        } on ArgumentError {
          targets = null;
        }
      }
      if (!mounted || version != _loadVersion) return;
      setState(() {
        _entries = entries;
        _targets = targets;
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

  void _changeDay(int offset) {
    final next = DateTime(_day.year, _day.month, _day.day + offset);
    if (next.isAfter(_today())) return;
    setState(() {
      _day = next;
      _loading = true;
    });
    refresh();
  }

  Future<void> _addFood() async {
    if (_saving) return;
    List<Map<String, dynamic>> foods;
    try {
      foods = (await _datasets.load()).foods;
    } catch (_) {
      foods = const [];
    }
    if (!mounted) return;
    final entry = await showModalBottomSheet<FoodLogEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CyberColors.surface,
      builder: (_) => FoodLogSheet(foods: foods, date: _day),
    );
    if (entry == null || !mounted) return;
    await _save([entry], context.l10n.diaryAdded);
  }

  Future<void> _save(List<FoodLogEntry> entries, String message) async {
    setState(() => _saving = true);
    try {
      await _database.addFoodLogEntries(entries);
      await refresh();
      if (mounted) _message(message);
    } catch (_) {
      if (mounted) _message(context.l10n.diarySaveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(FoodLogEntry entry) async {
    final id = entry.id;
    if (id == null || _saving) return;
    final l10n = context.l10n;
    try {
      await _database.deleteFoodLogEntry(id);
      await refresh();
    } catch (_) {
      if (mounted) _message(l10n.diarySaveFailed);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(l10n.diaryDeleted),
        action: SnackBarAction(
          label: l10n.diaryUndo,
          onPressed: () => _save([entry.withoutId()], l10n.diaryAdded),
        ),
      ));
  }

  void _message(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
          children: [
            Text(l10n.diarySubtitle,
                style: TextStyle(color: CyberColors.muted)),
            const SizedBox(height: 12),
            _DaySelector(
              label: _isToday ? l10n.diaryToday : formatDate(_day),
              onPrevious: () => _changeDay(-1),
              onNext: _isToday ? null : () => _changeDay(1),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_loadFailed)
              ErrorBox(message: l10n.diaryLoadFailed)
            else ...[
              _Summary(
                totals: FoodLogTotals.of(_entries),
                targets: _targets,
              ),
              const SizedBox(height: 14),
              NeonButton(
                key: const ValueKey('diary-add'),
                label: l10n.diaryAddFood,
                icon: Icons.add_rounded,
                loading: _saving,
                onPressed: _addFood,
              ),
              const SizedBox(height: 14),
              for (final meal in MealSlot.values) ...[
                _MealSection(
                  meal: meal,
                  entries: [
                    for (final entry in _entries)
                      if (entry.meal == meal) entry,
                  ],
                  onDelete: _saving ? null : _delete,
                ),
                const SizedBox(height: 12),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _DaySelector extends StatelessWidget {
  const _DaySelector({
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        IconButton(
          tooltip: l10n.diaryPreviousDay,
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          tooltip: l10n.diaryNextDay,
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.totals, required this.targets});

  final FoodLogTotals totals;
  final Map<String, dynamic>? targets;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final calorieTarget = (targets?['target_calories'] as num?)?.toDouble();
    final proteinTarget = (targets?['protein_target'] as num?)?.toDouble();
    final number = context.formatNumber;
    return CyberCard(
      title: l10n.diaryEaten,
      icon: Icons.local_fire_department_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (calorieTarget == null || proteinTarget == null) ...[
            Text('${number(totals.calories)} kcal',
                style: Theme.of(context).textTheme.titleLarge),
            Text('${number(totals.protein, decimals: 1)} g protein'),
            const SizedBox(height: 8),
            Text(l10n.diaryNoTarget,
                style: TextStyle(color: CyberColors.muted)),
          ] else ...[
            Text(
              l10n.diaryCaloriesProgress(
                  number(totals.calories), number(calorieTarget)),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            _Progress(value: totals.calories, target: calorieTarget),
            const SizedBox(height: 6),
            Text(
              totals.calories <= calorieTarget
                  ? l10n.diaryRemaining(number(calorieTarget - totals.calories))
                  : l10n.diaryOver(number(totals.calories - calorieTarget)),
              style: TextStyle(color: CyberColors.muted),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.diaryProteinProgress(
                number(totals.protein, decimals: 1),
                number(proteinTarget, decimals: 1),
              ),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            _Progress(value: totals.protein, target: proteinTarget),
          ],
          const SizedBox(height: 10),
          Text(
            l10n.diaryMacros(number(totals.carbs, decimals: 1),
                number(totals.fat, decimals: 1)),
            style: TextStyle(color: CyberColors.muted),
          ),
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.value, required this.target});

  final double value;
  final double target;

  @override
  Widget build(BuildContext context) {
    final over = value > target;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        minHeight: 8,
        value: target > 0 ? (value / target).clamp(0.0, 1.0) : 0,
        color: over ? Colors.orange : CyberColors.lime,
        backgroundColor: CyberColors.surfaceAlt,
      ),
    );
  }
}

class _MealSection extends StatelessWidget {
  const _MealSection({
    required this.meal,
    required this.entries,
    required this.onDelete,
  });

  final MealSlot meal;
  final List<FoodLogEntry> entries;
  final void Function(FoodLogEntry entry)? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final totals = FoodLogTotals.of(entries);
    final number = context.formatNumber;
    return CyberCard(
      title: l10n.mealSlotLabel(meal),
      accent: CyberColors.magenta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entries.isEmpty)
            Text(l10n.diaryEmptyMeal,
                style: TextStyle(color: CyberColors.muted))
          else ...[
            for (final entry in entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(entry.name),
                subtitle: Text(
                  entry.grams == null
                      ? l10n.diaryEntryDetailsNoGrams(
                          number(entry.calories),
                          number(entry.protein, decimals: 1),
                        )
                      : l10n.diaryEntryDetails(
                          context.formatMeasurement(entry.grams!),
                          number(entry.calories),
                          number(entry.protein, decimals: 1),
                        ),
                ),
                trailing: IconButton(
                  tooltip: l10n.diaryDeleteEntry,
                  onPressed: onDelete == null ? null : () => onDelete!(entry),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ),
            Text(
              '${number(totals.calories)} kcal • '
              'P ${number(totals.protein, decimals: 1)} g',
              style: TextStyle(color: CyberColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}
