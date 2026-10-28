import 'package:flutter/material.dart';

import '../core/cyber_theme.dart';
import '../engine/nutrition_targets.dart';
import '../l10n/l10n.dart';
import '../models/food_log_entry.dart';
import '../models/food_variant.dart';
import '../models/user_profile.dart';
import '../services/database_service.dart';
import '../services/dataset_repository.dart';
import '../widgets/cyber_card.dart';
import '../widgets/info_button.dart';
import '../widgets/intake_summary.dart';
import '../widgets/variant_picker_sheet.dart';
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
    FoodVariants? variants;
    final skinName = skinNamer(context.l10n);
    try {
      final vn = await _vnFood.load();
      variants = vn.variants;
      foods.addAll([
        for (final component in vn.components.values)
          if (component.hasNutrition) component.toFoodMap(language),
        // Searchable too: "uc ga luoc" finds the boiled breast.
        for (final variant in vn.variants.all)
          variant.toFoodMap(language, skinName),
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
        variants: variants,
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
    final hasTargets = targets?['target_calories'] != null &&
        targets?['protein_target'] != null;
    return CyberCard(
      highlight: true,
      title: l10n.diaryEaten,
      icon: Icons.local_fire_department_outlined,
      trailing:
          InfoButton(title: l10n.macroInfoTitle, paragraphs: [l10n.macroInfo]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntakeSummary(
              totals: totals,
              targets: hasTargets ? targets : null,
              compact: true),
          if (!hasTargets) ...[
            const SizedBox(height: 10),
            Text(l10n.diaryNoTarget,
                textAlign: TextAlign.center,
                style: TextStyle(color: CyberColors.muted)),
          ],
        ],
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
    final groups = groupDiaryEntries(entries);
    return CyberCard(
      title: l10n.mealSlotLabel(meal),
      // A meal of one row already shows its numbers on that row.
      trailing: groups.length < 2
          ? null
          : Text(
              l10n.mealTotalKcal(
                  context.formatNumber(FoodLogTotals.of(entries).calories)),
              style: TextStyle(color: CyberColors.muted),
            ),
      // The card paints its own background; list tiles need a Material for
      // their ink.
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entries.isEmpty)
              Text(l10n.diaryEmptyMeal,
                  style: TextStyle(color: CyberColors.muted))
            else ...[
              for (final group in groups)
                if (group.dish == null)
                  _entryTile(context, group.entries.single)
                else
                  _DishGroup(
                    dish: group.dish!,
                    entries: group.entries,
                    tileFor: (entry) => _entryTile(context, entry,
                        title: group.partName(entry)),
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
      ),
    );
  }
}

extension on _MealSection {
  /// One logged food; [title] replaces its name, e.g. "Cơm" inside the
  /// "Cơm tấm" group instead of "Cơm (Cơm tấm)".
  Widget _entryTile(BuildContext context, FoodLogEntry entry, {String? title}) {
    final l10n = context.l10n;
    final number = context.formatNumber;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title ?? entry.name),
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
            onPressed: onDelete == null ? null : () => onDelete!(entry),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

/// Foods logged from one scanned dish, e.g. "Cơm (Cơm tấm)" and
/// "Sườn nướng (Cơm tấm)", shown as one "Cơm tấm" row that opens into its
/// parts.
class DiaryGroup {
  const DiaryGroup(this.dish, this.entries);

  /// Null for a food logged on its own.
  final String? dish;
  final List<FoodLogEntry> entries;

  String partName(FoodLogEntry entry) =>
      _dishName.firstMatch(entry.name)?.group(1) ?? entry.name;
}

final _dishName = RegExp(r'^(.+) \((.+)\)$');

/// Neighbouring entries named "<part> (<dish>)" with the same dish form one
/// group; everything else stays on its own, in the same order.
List<DiaryGroup> groupDiaryEntries(List<FoodLogEntry> entries) {
  final groups = <DiaryGroup>[];
  for (final entry in entries) {
    final dish = _dishName.firstMatch(entry.name)?.group(2);
    final last = groups.isEmpty ? null : groups.last;
    if (dish != null && last != null && last.dish == dish) {
      last.entries.add(entry);
    } else {
      groups.add(DiaryGroup(dish, [entry]));
    }
  }
  // A dish with a single part reads better as that one row.
  return [
    for (final group in groups)
      group.dish != null && group.entries.length == 1
          ? DiaryGroup(null, group.entries)
          : group,
  ];
}

class _DishGroup extends StatelessWidget {
  const _DishGroup(
      {required this.dish, required this.entries, required this.tileFor});

  final String dish;
  final List<FoodLogEntry> entries;
  final Widget Function(FoodLogEntry entry) tileFor;

  @override
  Widget build(BuildContext context) {
    final totals = FoodLogTotals.of(entries);
    final number = context.formatNumber;
    return Theme(
      // No divider lines above and below when it opens.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: ValueKey('diary-dish-$dish'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(left: 14),
        title: Text(dish),
        // Same look as a single food's details.
        subtitle: Text(
            context.l10n.diaryDishSummary(
              '${entries.length}',
              number(totals.calories),
              number(totals.protein, decimals: 1),
            ),
            style: Theme.of(context).textTheme.bodyMedium),
        children: [for (final entry in entries) tileFor(entry)],
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
