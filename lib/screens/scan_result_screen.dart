import 'dart:io';

import 'package:flutter/material.dart';

import '../core/cyber_theme.dart';
import '../l10n/l10n.dart';
import '../models/food_log_entry.dart';
import '../models/scan_plate.dart';
import '../models/vn_food.dart';
import '../services/database_service.dart';
import '../services/food_recognizer.dart';
import '../widgets/cyber_card.dart';
import '../widgets/error_box.dart';
import '../widgets/food_log_sheet.dart';

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
  ScanPlate? _plate;
  MealSlot _meal = mealSlotFor(DateTime.now());
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _recognize();
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
          top.first.value >= result.thresholds.confidentDish) {
        _choose(top.first.key);
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
    return Scaffold(
      appBar: AppBar(title: Text(l10n.scanResultTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.file(
                  File(widget.imagePath),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: CyberColors.surfaceAlt,
                    child: Icon(Icons.image_not_supported_outlined,
                        color: CyberColors.muted, size: 48),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (_recognizing)
              const Center(child: CircularProgressIndicator())
            else ...[
              _DishCard(
                recognition: _recognition,
                modelAvailable: widget.recognizer.isAvailable,
                data: widget.data,
                selected: plate?.dish.code,
                onChoose: (code) => setState(() => _choose(code)),
                onPickOther: _pickDish,
              ),
              if (plate != null) ...[
                const SizedBox(height: 14),
                _ComponentsCard(
                  plate: plate,
                  onChanged: () => setState(() {}),
                  onAdd: _addComponent,
                ),
                const SizedBox(height: 14),
                _SummaryCard(
                  plate: plate,
                  meal: _meal,
                  saving: _saving,
                  onMealChanged: (meal) => setState(() => _meal = meal),
                  onSave: _save,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
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

class _ComponentsCard extends StatelessWidget {
  const _ComponentsCard({
    required this.plate,
    required this.onChanged,
    required this.onAdd,
  });

  final ScanPlate plate;
  final VoidCallback onChanged;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final language = Localizations.localeOf(context).languageCode;
    return CyberCard(
      title: l10n.scanComponentsTitle,
      icon: Icons.checklist_rounded,
      accent: CyberColors.magenta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in plate.items)
            _ComponentRow(
              key: ValueKey('component-${item.component.code}'),
              item: item,
              language: language,
              onChanged: onChanged,
            ),
          TextButton.icon(
            key: const ValueKey('scan-add-component'),
            onPressed: onAdd,
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
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
    final language = Localizations.localeOf(context).languageCode;
    final missing = plate.missingNutrition;
    return CyberCard(
      title: l10n.diaryEaten,
      icon: Icons.local_fire_department_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.scanTotal(context.formatNumber(plate.calories),
                context.formatNumber(plate.protein, decimals: 1)),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (plate.selected.isEmpty) ...[
            const SizedBox(height: 8),
            Text(l10n.scanNothingSelected,
                style: TextStyle(color: CyberColors.muted)),
          ],
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 10),
            ErrorBox(
              message: l10n.scanMissingNutrition(missing
                  .map((item) => item.component.name(language))
                  .join(', ')),
            ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<MealSlot>(
            initialValue: meal,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.diaryMealSlot),
            items: [
              for (final slot in MealSlot.values)
                DropdownMenuItem(
                    value: slot, child: Text(l10n.mealSlotLabel(slot))),
            ],
            onChanged: (value) => onMealChanged(value!),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('scan-save'),
            onPressed: plate.canLog && !saving ? onSave : null,
            icon: const Icon(Icons.menu_book_rounded),
            label: Text(l10n.scanSave),
          ),
        ],
      ),
    );
  }
}
