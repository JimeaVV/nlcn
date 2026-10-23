import 'package:flutter/material.dart';

import '../core/cyber_theme.dart';
import '../l10n/l10n.dart';
import '../models/food_log_entry.dart';
import '../models/food_variant.dart';
import 'variant_picker_sheet.dart';
import '../core/number_input.dart';
import '../core/text_search.dart';

/// Picks a dataset food by weight, or takes a custom dish by its nutrition,
/// and returns the resulting [FoodLogEntry] without saving it. Favorite and
/// recent foods sit on top and are returned in one tap.
class FoodLogSheet extends StatefulWidget {
  const FoodLogSheet({
    super.key,
    required this.foods,
    required this.date,
    this.favorites = const [],
    this.recent = const [],
    this.variants,
  });

  /// Meat, eggs, fish and starches by part and cooking; chips open a picker.
  final FoodVariants? variants;

  final List<Map<String, dynamic>> foods;
  final DateTime date;
  final List<FoodLogEntry> favorites;
  final List<FoodLogEntry> recent;

  @override
  State<FoodLogSheet> createState() => _FoodLogSheetState();
}

/// A sensible default slot for the current time of day.
MealSlot mealSlotFor(DateTime time) => switch (time.hour) {
      < 10 => MealSlot.breakfast,
      < 14 => MealSlot.lunch,
      >= 17 && < 21 => MealSlot.dinner,
      _ => MealSlot.snack,
    };

class _FoodLogSheetState extends State<FoodLogSheet> {
  final _formKey = GlobalKey<FormState>();
  final _grams = TextEditingController(text: '100');
  final _customGrams = TextEditingController();
  final _name = TextEditingController();
  final _calories = TextEditingController();
  final _protein = TextEditingController(text: '0');
  final _carbs = TextEditingController(text: '0');
  final _fat = TextEditingController(text: '0');
  late MealSlot _meal = mealSlotFor(DateTime.now());

  /// Typing a food in starts out only when there is nothing to pick from.
  bool get _canPick =>
      widget.foods.isNotEmpty || !(widget.variants?.isEmpty ?? true);
  late bool _custom = !_canPick;
  Map<String, dynamic>? _food;

  /// Bumped when a variant is picked, so the search field shows its name.
  int _fieldVersion = 0;

  Future<void> _pickVariant(String group) async {
    final l10n = context.l10n;
    final language = Localizations.localeOf(context).languageCode;
    final variant = await pickFoodVariant(context,
        variants: widget.variants!, group: group);
    if (variant == null || !mounted) return;
    setState(() {
      _food = variant.toFoodMap(language, skinNamer(l10n));
      // One egg or one bowl if it has a unit; otherwise the grams typed.
      if (variant.unitGrams != null) {
        _grams.text = context.formatMeasurement(variant.unitGrams!);
      }
      _fieldVersion++;
    });
  }

  @override
  void dispose() {
    for (final controller in [
      _grams,
      _customGrams,
      _name,
      _calories,
      _protein,
      _carbs,
      _fat,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _parse(TextEditingController controller) =>
      parseDecimal(controller.text);

  String? _range(String? value, double max, String error,
      {bool optional = false, bool allowZero = true}) {
    final text = value?.trim() ?? '';
    if (optional && text.isEmpty) return null;
    final number = parseDecimal(text);
    if (number == null ||
        number > max ||
        (allowZero ? number < 0 : number <= 0)) {
      return error;
    }
    return null;
  }

  FoodLogEntry? _entry() {
    if (_custom) {
      final calories = _parse(_calories);
      if (_name.text.trim().isEmpty || calories == null) return null;
      return FoodLogEntry(
        date: widget.date,
        meal: _meal,
        name: _name.text.trim(),
        grams: _customGrams.text.trim().isEmpty ? null : _parse(_customGrams),
        calories: calories,
        protein: _parse(_protein) ?? 0,
        carbs: _parse(_carbs) ?? 0,
        fat: _parse(_fat) ?? 0,
      );
    }
    final food = _food;
    final grams = _parse(_grams);
    if (food == null || grams == null || grams <= 0) return null;
    return FoodLogEntry.fromFood(food,
        grams: grams, date: widget.date, meal: _meal);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final entry = _entry();
    if (entry != null) Navigator.pop(context, entry);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final preview = _entry();
    return Padding(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 18,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 18,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.diaryAddTitle,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              DropdownButtonFormField<MealSlot>(
                key: const ValueKey('diary-meal'),
                initialValue: _meal,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.diaryMealSlot),
                items: [
                  for (final meal in MealSlot.values)
                    DropdownMenuItem(
                        value: meal, child: Text(l10n.mealSlotLabel(meal))),
                ],
                onChanged: (value) => setState(() => _meal = value!),
              ),
              const SizedBox(height: 12),
              ..._quickFoods(l10n),
              if (_canPick) ...[
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                        value: false, label: Text(l10n.diaryFromDataset)),
                    ButtonSegment(value: true, label: Text(l10n.diaryCustom)),
                  ],
                  selected: {_custom},
                  onSelectionChanged: (value) => setState(() {
                    _custom = value.single;
                    // The search field comes back empty, so the earlier
                    // pick must not be saved unseen.
                    _food = null;
                  }),
                ),
                const SizedBox(height: 12),
              ],
              if (_custom) ..._customFields(l10n) else ..._datasetFields(l10n),
              const SizedBox(height: 12),
              if (preview != null)
                Text(
                  l10n.diaryPreview(
                    context.formatNumber(preview.calories),
                    context.formatNumber(preview.protein, decimals: 1),
                  ),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              const SizedBox(height: 14),
              FilledButton.icon(
                key: const ValueKey('diary-save'),
                onPressed: _submit,
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.diarySave),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Favorites, then recent foods not already among them.
  List<Widget> _quickFoods(AppLocalizations l10n) {
    final starred = {for (final food in widget.favorites) food.name};
    final recent = [
      for (final food in widget.recent)
        if (!starred.contains(food.name)) food,
    ];
    if (widget.favorites.isEmpty && recent.isEmpty) return const [];
    Widget row(String title, IconData icon, List<FoodLogEntry> foods,
            String keyPrefix) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 16, color: CyberColors.muted),
              const SizedBox(width: 6),
              Text(title, style: Theme.of(context).textTheme.labelLarge),
            ]),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final food in foods)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        key: ValueKey('$keyPrefix-${food.name}'),
                        label: Text(l10n.diaryQuickChip(
                            food.name, context.formatNumber(food.calories))),
                        onPressed: () => Navigator.pop(
                            context, food.copyTo(widget.date, _meal)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        );
    return [
      if (widget.favorites.isNotEmpty)
        row(l10n.diaryFavorites, Icons.star_rounded, widget.favorites,
            'diary-favorite'),
      if (recent.isNotEmpty)
        row(l10n.diaryRecent, Icons.history_rounded, recent, 'diary-recent'),
      Text(l10n.diaryQuickHint,
          style: TextStyle(color: CyberColors.muted, fontSize: 12)),
      const Divider(height: 24),
    ];
  }

  List<Widget> _datasetFields(AppLocalizations l10n) => [
        if (widget.variants != null && !widget.variants!.isEmpty) ...[
          Text(l10n.variantPickHint,
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final group in variantGroups)
                if (widget.variants!.inGroup(group).isNotEmpty)
                  ActionChip(
                    key: ValueKey('diary-variant-$group'),
                    avatar: Icon(variantGroupIcon(group), size: 18),
                    label: Text(variantGroupName(l10n, group)),
                    onPressed: () => _pickVariant(group),
                  ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Autocomplete<Map<String, dynamic>>(
          key: ValueKey('diary-food-field-$_fieldVersion'),
          initialValue: TextEditingValue(text: '${_food?['name'] ?? ''}'),
          displayStringForOption: (food) => '${food['name']}',
          optionsBuilder: (value) {
            if (value.text.trim().isEmpty) return const [];
            return widget.foods.where((food) => matchesSearch(
                value.text, ['${food['name']}', '${food['search'] ?? ''}']));
          },
          onSelected: (food) => setState(() {
            _food = food;
            // Start at one natural unit (a bowl of rice, one egg) if known.
            final unit = food['unit_grams'];
            if (unit is num) {
              _grams.text = context.formatMeasurement(unit.toDouble());
            }
          }),
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) =>
              TextFormField(
            key: const ValueKey('diary-food'),
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(
              labelText: l10n.diaryFoodSearch,
              prefixIcon: const Icon(Icons.search_rounded),
            ),
            onChanged: (text) {
              // Typing after a selection invalidates it until a new pick.
              if (_food != null && text != '${_food!['name']}') {
                setState(() => _food = null);
              }
            },
            validator: (_) => _food == null ? l10n.diaryFoodRequired : null,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const ValueKey('diary-grams'),
          controller: _grams,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: l10n.diaryGrams),
          onChanged: (_) => setState(() {}),
          validator: (value) =>
              _range(value, 5000, l10n.diaryGramsError, allowZero: false),
        ),
      ];

  List<Widget> _customFields(AppLocalizations l10n) {
    Widget macro(Key key, TextEditingController controller, String label) =>
        TextFormField(
          key: key,
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label),
          onChanged: (_) => setState(() {}),
          validator: (value) => _range(value, 1000, l10n.diaryMacroError),
        );

    return [
      TextFormField(
        key: const ValueKey('diary-custom-name'),
        controller: _name,
        decoration: InputDecoration(labelText: l10n.diaryCustomName),
        onChanged: (_) => setState(() {}),
        validator: (value) =>
            (value?.trim().isEmpty ?? true) ? l10n.diaryCustomNameError : null,
      ),
      const SizedBox(height: 12),
      TextFormField(
        key: const ValueKey('diary-custom-calories'),
        controller: _calories,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: l10n.diaryCustomCalories),
        onChanged: (_) => setState(() {}),
        validator: (value) =>
            _range(value, 10000, l10n.diaryCustomCaloriesError),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
              child: macro(const ValueKey('diary-custom-protein'), _protein,
                  l10n.proteinLabel)),
          const SizedBox(width: 8),
          Expanded(
              child: macro(const ValueKey('diary-custom-carbs'), _carbs,
                  l10n.diaryCarbsLabel)),
          const SizedBox(width: 8),
          Expanded(
              child: macro(const ValueKey('diary-custom-fat'), _fat,
                  l10n.diaryFatLabel)),
        ],
      ),
      const SizedBox(height: 12),
      TextFormField(
        key: const ValueKey('diary-custom-grams'),
        controller: _customGrams,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: l10n.diaryOptionalGrams),
        validator: (value) => _range(value, 5000, l10n.diaryGramsError,
            optional: true, allowZero: false),
      ),
    ];
  }
}
