import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../core/cyber_theme.dart';
import '../core/haptics.dart';
import '../l10n/l10n.dart';
import '../models/food_log_entry.dart';
import '../models/scan_plate.dart';
import '../models/vn_food.dart';
import '../services/database_service.dart';
import '../services/food_recognizer.dart';
import '../widgets/cyber_card.dart';
import '../widgets/error_box.dart';
import '../widgets/food_log_sheet.dart';
import '../widgets/scan_sweep.dart';

/// Confirms what is on a photographed plate and logs it to today's diary.
/// Pops with `true` after logging.
class ScanResultScreen extends StatefulWidget {
  const ScanResultScreen({
    super.key,
    required this.imagePath,
    required this.data,
    required this.recognizer,
    this.database,
  });

  final String imagePath;
  final VnFoodData data;
  final FoodRecognizer recognizer;
  final DatabaseService? database;

  @override
  State<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends State<ScanResultScreen> {
  FoodRecognition _recognition = FoodRecognition.empty;
  bool _recognizing = true;

  // The model answers in a fraction of a second, which hid the scan sweep;
  // it now plays at least one full pass over the photo.
  bool _sweepShown = true;
  Timer? _sweepTimer;
  ScanPlate? _plate;
  MealSlot _meal = mealSlotFor(DateTime.now());
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _sweepTimer = Timer(ScanSweep.onePass, () {
      if (mounted) setState(() => _sweepShown = false);
    });
    _recognize();
  }

  @override
  void dispose() {
    _sweepTimer?.cancel();
    super.dispose();
  }

  Future<void> _recognize() async {
    FoodRecognition result;
    try {
      result = await widget.recognizer.recognize(widget.imagePath);
    } catch (_) {
      result = FoodRecognition.empty;
    }
    if (!mounted) return;
    setState(() {
      _recognition = result;
      _recognizing = false;
      final top = result.topDishes(1);
      // A confident guess opens directly; otherwise the user picks.
      if (top.isNotEmpty &&
          !result.looksUnknown &&
          top.first.value >= result.thresholds.confidentDish) {
        _choose(top.first.key);
        Haptics.found();
      }
    });
  }

  void _choose(String code) {
    final dish = widget.data.dish(code);
    if (dish == null) return;
    _plate = ScanPlate.forDish(widget.data, dish, _recognition);
  }

  Future<void> _pickDish() async {
    final language = Localizations.localeOf(context).languageCode;
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CyberColors.surface,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .7,
        builder: (context, controller) => ListView(
          controller: controller,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(context.l10n.scanChooseDish,
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            for (final dish in widget.data.dishes)
              ListTile(
                key: ValueKey('dish-${dish.code}'),
                title: Text(dish.name(language)),
                onTap: () => Navigator.pop(context, dish.code),
              ),
          ],
        ),
      ),
    );
    if (code != null && mounted) setState(() => _choose(code));
  }

  Future<void> _addComponent() async {
    final plate = _plate;
    if (plate == null) return;
    final language = Localizations.localeOf(context).languageCode;
    final present = {for (final item in plate.items) item.component.code};
    final options = [
      for (final component in widget.data.addableComponents)
        if (!present.contains(component.code)) component,
    ];
    final picked = await showModalBottomSheet<VnComponent>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CyberColors.surface,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .7,
        builder: (context, controller) => ListView(
          controller: controller,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(context.l10n.scanAddComponent,
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            for (final component in options)
              ListTile(
                key: ValueKey('add-${component.code}'),
                title: Text(component.name(language)),
                onTap: () => Navigator.pop(context, component),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) setState(() => plate.add(picked));
  }

  Future<void> _save() async {
    final plate = _plate;
    if (plate == null || !plate.canLog || _saving) return;
    setState(() => _saving = true);
    try {
      await (widget.database ?? DatabaseService.instance).addFoodLogEntries(
        plate.toEntries(
          date: DateTime.now(),
          meal: _meal,
          languageCode: Localizations.localeOf(context).languageCode,
        ),
      );
      Haptics.strong();
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.diarySaveFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final plate = _plate;
    final language = Localizations.localeOf(context).languageCode;
    final missing = plate?.missingNutrition ?? const <PlateItem>[];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.scanResultTitle)),
      // The total and the log button stay in reach while the list scrolls.
      bottomNavigationBar: plate == null
          ? null
          : _TotalBar(
              plate: plate,
              meal: _meal,
              saving: _saving,
              onMealChanged: (meal) => setState(() => _meal = meal),
              onSave: _save,
            ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(
                      File(widget.imagePath),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: CyberColors.surfaceAlt,
                        child: Icon(Icons.image_not_supported_outlined,
                            color: CyberColors.muted, size: 48),
                      ),
                    ),
                    if (_recognizing || _sweepShown) const ScanSweep(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (_recognizing)
              Center(
                child: Text(l10n.scanRecognizing,
                    style: TextStyle(
                        color: CyberColors.cyan, fontWeight: FontWeight.w700)),
              )
            else ...[
              _Appear(
                child: _DishCard(
                  recognition: _recognition,
                  modelAvailable: widget.recognizer.isAvailable,
                  data: widget.data,
                  selected: plate?.dish.code,
                  onChoose: (code) {
                    Haptics.tap();
                    setState(() => _choose(code));
                  },
                  onPickOther: _pickDish,
                ),
              ),
              if (plate != null) ...[
                const SizedBox(height: 14),
                _Appear(
                  delay: 1,
                  child: _ComponentsCard(
                    // Another dish starts with its suggestions folded.
                    key: ValueKey('components-${plate.dish.code}'),
                    plate: plate,
                    onChanged: () => setState(() {}),
                    onAdd: _addComponent,
                  ),
                ),
                if (plate.selected.isEmpty) ...[
                  const SizedBox(height: 12),
                  Text(l10n.scanNothingSelected,
                      style: TextStyle(color: CyberColors.muted)),
                ],
                if (missing.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ErrorBox(
                    message: l10n.scanMissingNutrition(missing
                        .map((item) => item.component.name(language))
                        .join(', ')),
                  ),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Fades and slides a card in when it first appears; [delay] staggers cards.
class _Appear extends StatelessWidget {
  const _Appear({required this.child, this.delay = 0});

  final Widget child;
  final int delay;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 260 + 90 * delay),
        curve: Curves.easeOutCubic,
        child: child,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(
              offset: Offset(0, 18 * (1 - t)), child: child),
        ),
      );
}

class _DishCard extends StatelessWidget {
  const _DishCard({
    required this.recognition,
    required this.modelAvailable,
    required this.data,
    required this.selected,
    required this.onChoose,
    required this.onPickOther,
  });

  final FoodRecognition recognition;
  final bool modelAvailable;
  final VnFoodData data;
  final String? selected;
  final ValueChanged<String> onChoose;
  final VoidCallback onPickOther;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final language = Localizations.localeOf(context).languageCode;
    final top = recognition.topDishes();
    final chosen = selected == null ? null : data.dish(selected!);
    return CyberCard(
      title: l10n.scanDishTitle,
      icon: Icons.restaurant_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!modelAvailable)
            Text(l10n.scanModelPending,
                style: TextStyle(color: CyberColors.muted))
          else if (recognition.looksUnknown)
            Text(l10n.scanNotInApp, style: TextStyle(color: CyberColors.muted))
          else if (top.isEmpty)
            Text(l10n.scanNoGuess, style: TextStyle(color: CyberColors.muted))
          else if (top.first.value < recognition.thresholds.confidentDish)
            Text(l10n.scanLowConfidence,
                style: TextStyle(color: CyberColors.muted)),
          if (top.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final guess in top)
                  ChoiceChip(
                    key: ValueKey('guess-${guess.key}'),
                    selected: guess.key == selected,
                    label: Text(
                        '${data.dish(guess.key)?.name(language) ?? guess.key}'
                        ' · ${context.formatNumber(guess.value * 100)}%'),
                    onSelected: (_) => onChoose(guess.key),
                  ),
              ],
            ),
          ],
          if (chosen != null &&
              !top.any((guess) => guess.key == chosen.code)) ...[
            const SizedBox(height: 10),
            Text(chosen.name(language),
                style: Theme.of(context).textTheme.titleLarge),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const ValueKey('scan-pick-dish'),
            onPressed: onPickOther,
            icon: const Icon(Icons.list_rounded),
            label: Text(chosen == null && top.isEmpty
                ? l10n.scanChooseDish
                : l10n.scanOtherDish),
          ),
        ],
      ),
    );
  }
}

/// Servings offered for the whole dish.
const _portions = [0.5, 1.0, 1.5, 2.0];

String _portionLabel(double servings) {
  final whole = servings.floor();
  final half = servings - whole >= .5 ? '½' : '';
  return '×${whole == 0 ? '' : whole}$half';
}

class _ComponentsCard extends StatefulWidget {
  const _ComponentsCard({
    super.key,
    required this.plate,
    required this.onChanged,
    required this.onAdd,
  });

  final ScanPlate plate;
  final VoidCallback onChanged;
  final VoidCallback onAdd;

  @override
  State<_ComponentsCard> createState() => _ComponentsCardState();
}

class _ComponentsCardState extends State<_ComponentsCard> {
  bool _showSuggestions = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final language = Localizations.localeOf(context).languageCode;
    final plate = widget.plate;
    final dishItems = [
      for (final item in plate.items)
        if (!item.suggested) item
    ];
    final suggestions = [
      for (final item in plate.items)
        if (item.suggested) item
    ];
    final chosen = suggestions.where((item) => item.included).length;
    Widget row(PlateItem item) => _ComponentRow(
          key: ValueKey('component-${item.component.code}'),
          item: item,
          language: language,
          onChanged: widget.onChanged,
        );
    return CyberCard(
      title: l10n.scanComponentsTitle,
      icon: Icons.checklist_rounded,
      accent: CyberColors.magenta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.scanPortion,
              style: TextStyle(color: CyberColors.muted, fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final servings in _portions)
                ChoiceChip(
                  key: ValueKey('portion-$servings'),
                  label: Text(_portionLabel(servings)),
                  selected: plate.portion == servings,
                  onSelected: (_) {
                    Haptics.tap();
                    plate.portion = servings;
                    widget.onChanged();
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in dishItems) row(item),
          // Components outside the recipe are folded away: the model is least
          // sure about them, and they would push the dish off the screen.
          if (suggestions.isNotEmpty) ...[
            const Divider(height: 20),
            InkWell(
              key: const ValueKey('scan-suggestions'),
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _showSuggestions = !_showSuggestions),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.help_outline_rounded,
                        size: 18, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        chosen == 0
                            ? l10n.scanSuggestions(suggestions.length)
                            : l10n.scanSuggestionsChosen(
                                suggestions.length, chosen),
                        style: TextStyle(
                            color: CyberColors.text,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _showSuggestions ? .5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.expand_more_rounded,
                          color: CyberColors.muted),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _showSuggestions
                  ? Column(
                      children: [for (final item in suggestions) row(item)])
                  : const SizedBox(width: double.infinity),
            ),
          ],
          TextButton.icon(
            key: const ValueKey('scan-add-component'),
            onPressed: widget.onAdd,
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.scanAddComponent),
          ),
        ],
      ),
    );
  }
}

class _ComponentRow extends StatelessWidget {
  const _ComponentRow({
    super.key,
    required this.item,
    required this.language,
    required this.onChanged,
  });

  final PlateItem item;
  final String language;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final unit = item.inUnits
        ? (language == 'vi' ? item.component.unitNameVi : null) ??
            l10n.scanUnitFallback
        : 'g';
    final amount = '${context.formatMeasurement(item.amount)} $unit';
    final detail = item.hasNutrition
        ? '$amount · ${context.formatNumber(item.calories)} kcal'
        : '$amount · ${l10n.scanNoNutrition}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Checkbox(
            value: item.included,
            onChanged: (value) {
              Haptics.tap();
              item.included = value ?? false;
              item.uncertain = false;
              onChanged();
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(item.component.name(language),
                          style: TextStyle(
                              color: CyberColors.text,
                              fontWeight: FontWeight.w700)),
                    ),
                    if (item.uncertain) ...[
                      const SizedBox(width: 6),
                      _Badge(l10n.scanMaybe),
                    ],
                  ],
                ),
                Text(detail,
                    style: TextStyle(color: CyberColors.muted, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.scanDecrease,
            visualDensity: VisualDensity.compact,
            onPressed: item.amount - item.step <= 0
                ? null
                : () {
                    item.amount -= item.step;
                    onChanged();
                  },
            icon: const Icon(Icons.remove_circle_outline),
          ),
          IconButton(
            tooltip: l10n.scanIncrease,
            visualDensity: VisualDensity.compact,
            onPressed: () {
              item.amount += item.step;
              onChanged();
            },
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text,
            style: const TextStyle(
                color: Colors.orange,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
      );
}

/// Stays at the bottom: the running total, where its calories come from,
/// the meal and the button that logs the plate. Numbers count to new values.
class _TotalBar extends StatelessWidget {
  const _TotalBar({
    required this.plate,
    required this.meal,
    required this.saving,
    required this.onMealChanged,
    required this.onSave,
  });

  final ScanPlate plate;
  final MealSlot meal;
  final bool saving;
  final ValueChanged<MealSlot> onMealChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      color: CyberColors.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: CyberColors.cyan, width: 1.2)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: TweenAnimationBuilder<_Totals>(
              tween: _TotalsTween(end: _Totals.of(plate)),
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutCubic,
              builder: (context, totals, _) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _MacroSplit(totals: totals),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.scanTotal(
                                  context.formatNumber(totals.calories),
                                  context.formatNumber(totals.protein,
                                      decimals: 1)),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              l10n.scanMacroGrams(
                                  context.formatNumber(totals.protein),
                                  context.formatNumber(totals.carbs),
                                  context.formatNumber(totals.fat)),
                              style: TextStyle(
                                  color: CyberColors.muted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<MealSlot>(
                        key: const ValueKey('scan-meal'),
                        value: meal,
                        underline: const SizedBox.shrink(),
                        items: [
                          for (final slot in MealSlot.values)
                            DropdownMenuItem(
                                value: slot,
                                child: Text(l10n.mealSlotLabel(slot))),
                        ],
                        onChanged: (value) => onMealChanged(value!),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    key: const ValueKey('scan-save'),
                    onPressed: plate.canLog && !saving ? onSave : null,
                    icon: const Icon(Icons.menu_book_rounded),
                    label: Text(l10n.scanSave),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The plate's totals, animated together.
class _Totals {
  const _Totals(this.calories, this.protein, this.carbs, this.fat);

  factory _Totals.of(ScanPlate plate) =>
      _Totals(plate.calories, plate.protein, plate.carbs, plate.fat);

  final double calories;
  final double protein;
  final double carbs;
  final double fat;
}

class _TotalsTween extends Tween<_Totals> {
  _TotalsTween({required super.end});

  @override
  _Totals lerp(double t) {
    final from = begin ?? end!;
    double mix(double a, double b) => a + (b - a) * t;
    return _Totals(
      mix(from.calories, end!.calories),
      mix(from.protein, end!.protein),
      mix(from.carbs, end!.carbs),
      mix(from.fat, end!.fat),
    );
  }
}

/// A thin bar split by where the calories come from: protein, carbs, fat.
class _MacroSplit extends StatelessWidget {
  const _MacroSplit({required this.totals});

  final _Totals totals;

  @override
  Widget build(BuildContext context) {
    final parts = [
      (totals.protein * 4, CyberColors.cyan),
      (totals.carbs * 4, CyberColors.lime),
      (totals.fat * 9, CyberColors.magenta),
    ];
    final sum = parts.fold<double>(0, (total, part) => total + part.$1);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 6,
        child: sum <= 0
            ? ColoredBox(color: CyberColors.surfaceAlt)
            : Row(
                children: [
                  for (final (energy, colour) in parts)
                    if (energy > 0)
                      Expanded(
                        flex: (energy / sum * 1000).round().clamp(1, 1000),
                        child: ColoredBox(color: colour),
                      ),
                ],
              ),
      ),
    );
  }
}
