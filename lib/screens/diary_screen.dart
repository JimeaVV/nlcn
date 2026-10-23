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
import '../services/vn_food_repository.dart';

/// What the user ate on one day, compared with the saved profile targets.
class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key, this.database, this.datasets, this.vnFood});

  final DatabaseService? database;
  final DatasetRepository? datasets;
  final VnFoodRepository? vnFood;

  @override
  State<DiaryScreen> createState() => DiaryScreenState();
}

class DiaryScreenState extends State<DiaryScreen> {
  late final DatasetRepository _datasets =
      widget.datasets ?? DatasetRepository();
  late final VnFoodRepository _vnFood = widget.vnFood ?? VnFoodRepository();
  DatabaseService get _database => widget.database ?? DatabaseService.instance;

  DateTime _day = _today();
  List<FoodLogEntry> _entries = const [];

  /// The day before [_day], only loaded on today for "same as yesterday".
  List<FoodLogEntry> _yesterday = const [];
  List<FoodLogEntry> _favorites = const [];
  List<FoodLogEntry> _recent = const [];
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
      final yesterday = _isToday
          ? await _database
              .getFoodLog(DateTime(_day.year, _day.month, _day.day - 1))
          : const <FoodLogEntry>[];
      // Shortcuts only: the diary still works if they fail to load.
      var favorites = const <FoodLogEntry>[];
      var recent = const <FoodLogEntry>[];
      try {
        favorites = await _database.getFavoriteFoods();
        recent = await _database.getRecentFoods();
      } catch (_) {}
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
        _yesterday = yesterday;
        _favorites = favorites;
        _recent = recent;
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
    final language = Localizations.localeOf(context).languageCode;
    // Vietnamese dishes and components first, then the general food list;
    // either source failing still leaves the other and custom entry.
    final foods = <Map<String, dynamic>>[];
    try {
      final vn = await _vnFood.load();
      foods.addAll([
        for (final component in vn.components.values)
          if (component.hasNutrition) component.toFoodMap(language),
      ]);
    } catch (_) {}
    try {
      foods.addAll((await _datasets.load()).foods);
    } catch (_) {}
    if (!mounted) return;
    final entry = await showModalBottomSheet<FoodLogEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CyberColors.surface,
      builder: (_) => FoodLogSheet(
        foods: foods,
        date: _day,
        favorites: _favorites,
        recent: _recent,
      ),
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
        // With an action Flutter keeps a snack bar until it is tapped; undo
        // is only offered for a few seconds.
        persist: false,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: l10n.diaryUndo,
          onPressed: () => _save([entry.withoutId()], l10n.diaryAdded),
        ),
      ));
  }

  Future<void> _toggleFavorite(FoodLogEntry entry) async {
    final l10n = context.l10n;
    final starred = _favorites.any((food) => food.name == entry.name);
    try {
      if (starred) {
        await _database.removeFavoriteFood(entry.name);
      } else {
        await _database.addFavoriteFood(entry);
      }
      await refresh();
      if (mounted) {
        _message(starred
            ? l10n.diaryFavoriteRemoved(entry.name)
            : l10n.diaryFavoriteAdded(entry.name));
      }
    } catch (_) {
      if (mounted) _message(l10n.diarySaveFailed);
    }
  }

  /// Logs [entries] again on [day], each in its own meal.
  Future<void> _copy(List<FoodLogEntry> entries, DateTime day) {
    if (_saving || entries.isEmpty) return Future.value();
    return _save([for (final entry in entries) entry.copyTo(day, entry.meal)],
        context.l10n.diaryCopied('${entries.length}'));
  }

  /// The copy shortcut for [meal]: a past meal goes to today; an empty meal
  /// today can repeat yesterday's.
  _CopyAction? _copyAction(MealSlot meal, List<FoodLogEntry> entries) {
    final l10n = context.l10n;
    if (!_isToday) {
      if (entries.isEmpty) return null;
      return _CopyAction(l10n.diaryCopyToToday, () => _copy(entries, _today()));
    }
    if (entries.isNotEmpty) return null;
    final before = [
      for (final entry in _yesterday)
        if (entry.meal == meal) entry,
    ];
    if (before.isEmpty) return null;
    return _CopyAction(
      l10n.diaryRepeatYesterday('${before.length}',
          context.formatNumber(FoodLogTotals.of(before).calories)),
      () => _copy(before, _day),
    );
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
                Builder(builder: (context) {
                  final entries = [
                    for (final entry in _entries)
                      if (entry.meal == meal) entry,
                  ];
                  return _MealSection(
                    meal: meal,
                    entries: entries,
                    favoriteNames: {for (final food in _favorites) food.name},
                    onDelete: _saving ? null : _delete,
                    onToggleFavorite: _saving ? null : _toggleFavorite,
                    copy: _saving ? null : _copyAction(meal, entries),
                  );
                }),
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
            Text(l10n.proteinGrams(number(totals.protein, decimals: 1))),
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

/// A button under a meal that logs its foods again on another day.
class _CopyAction {
  const _CopyAction(this.label, this.onPressed);

  final String label;
  final VoidCallback onPressed;
}

class _MealSection extends StatelessWidget {
  const _MealSection({
    required this.meal,
    required this.entries,
    required this.favoriteNames,
    required this.onDelete,
    required this.onToggleFavorite,
    this.copy,
  });

  final MealSlot meal;
  final List<FoodLogEntry> entries;
  final Set<String> favoriteNames;
  final void Function(FoodLogEntry entry)? onDelete;
  final void Function(FoodLogEntry entry)? onToggleFavorite;
  final _CopyAction? copy;

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
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _FavoriteButton(
                      starred: favoriteNames.contains(entry.name),
                      onPressed: onToggleFavorite == null
                          ? null
                          : () => onToggleFavorite!(entry),
                    ),
                    IconButton(
                      tooltip: l10n.diaryDeleteEntry,
                      onPressed:
                          onDelete == null ? null : () => onDelete!(entry),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
              ),
            Text(
              l10n.kcalProteinLine(
                  number(totals.calories), number(totals.protein, decimals: 1)),
              style: TextStyle(color: CyberColors.muted),
            ),
          ],
          if (copy != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: ValueKey('diary-copy-${meal.name}'),
                onPressed: copy!.onPressed,
                icon: const Icon(Icons.content_copy_rounded, size: 18),
                label: Text(copy!.label),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({required this.starred, required this.onPressed});

  final bool starred;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return IconButton(
      tooltip: starred ? l10n.diaryFavoriteRemove : l10n.diaryFavoriteAdd,
      onPressed: onPressed,
      icon: Icon(
        starred ? Icons.star_rounded : Icons.star_outline_rounded,
        color: starred ? CyberColors.lime : null,
      ),
    );
  }
}
