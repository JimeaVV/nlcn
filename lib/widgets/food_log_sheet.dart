import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/food_log_entry.dart';

/// Picks a dataset food by weight, or takes a custom dish by its nutrition,
/// and returns the resulting [FoodLogEntry] without saving it.
class FoodLogSheet extends StatefulWidget {
  const FoodLogSheet({super.key, required this.foods, required this.date});

  final List<Map<String, dynamic>> foods;
  final DateTime date;

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
  late bool _custom = widget.foods.isEmpty;
  Map<String, dynamic>? _food;

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
      double.tryParse(controller.text.trim().replaceAll(',', '.'));

  String? _range(String? value, double max, String error,
      {bool optional = false, bool allowZero = true}) {
    final text = value?.trim() ?? '';
    if (optional && text.isEmpty) return null;
    final number = double.tryParse(text.replaceAll(',', '.'));
    if (number == null ||
        !number.isFinite ||
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
              if (widget.foods.isNotEmpty) ...[
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                        value: false, label: Text(l10n.diaryFromDataset)),
                    ButtonSegment(value: true, label: Text(l10n.diaryCustom)),
                  ],
                  selected: {_custom},
                  onSelectionChanged: (value) =>
                      setState(() => _custom = value.single),
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

  List<Widget> _datasetFields(AppLocalizations l10n) => [
        Autocomplete<Map<String, dynamic>>(
          displayStringForOption: (food) => '${food['name']}',
          optionsBuilder: (value) {
            final query = value.text.trim().toLowerCase();
            if (query.isEmpty) return const [];
            return widget.foods.where(
                (food) => '${food['name']}'.toLowerCase().contains(query));
          },
          onSelected: (food) => setState(() => _food = food),
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
