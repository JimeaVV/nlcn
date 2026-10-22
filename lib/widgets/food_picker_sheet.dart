import 'package:flutter/material.dart';

import '../core/cyber_theme.dart';
import '../core/text_search.dart';
import '../l10n/l10n.dart';
import '../models/vn_food.dart';

/// What the user picked: a whole dish, or one component eaten on its own
/// (plain rice, a boiled egg).
sealed class FoodPick {
  const FoodPick();
}

class DishPick extends FoodPick {
  const DishPick(this.code);

  final String code;
}

class ComponentPick extends FoodPick {
  const ComponentPick(this.component);

  final VnComponent component;
}

/// A searchable list of dishes and components. Typing filters both lists,
/// with or without Vietnamese diacritics ("uc ga" finds "Ức gà").
class FoodPickerSheet extends StatefulWidget {
  const FoodPickerSheet({
    super.key,
    required this.title,
    required this.dishes,
    required this.components,
    required this.scrollController,
  });

  final String title;

  /// Empty when only components can be picked, e.g. adding one to a plate.
  final List<VnDish> dishes;
  final List<VnComponent> components;
  final ScrollController scrollController;

  @override
  State<FoodPickerSheet> createState() => _FoodPickerSheetState();
}

class _FoodPickerSheetState extends State<FoodPickerSheet> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// Items matching every word come first, then those where any word of
  /// the query starts a word of the name: "uc ga" finds "Thịt gà" although
  /// no food is called "ức gà".
  List<T> _search<T>(
      List<T> items, String Function(T) vi, String Function(T) en) {
    final query = _query.text.trim();
    if (query.isEmpty) return items;
    final strict = [
      for (final item in items)
        if (matchesSearch(query, [vi(item), en(item)])) item,
    ];
    final words = foldForSearch(query).split(RegExp(r'\s+'))
      ..removeWhere((word) => word.length < 2);
    bool startsAWord(T item) => foldForSearch('${vi(item)} ${en(item)}')
        .split(RegExp(r'[^a-z0-9]+'))
        .any((part) => words.any(part.startsWith));
    return [
      ...strict,
      for (final item in items)
        if (!strict.contains(item) && startsAWord(item)) item,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final language = Localizations.localeOf(context).languageCode;
    return _list(
      context,
      l10n,
      language,
      _search(widget.dishes, (d) => d.nameVi, (d) => d.nameEn),
      _search(widget.components, (c) => c.nameVi, (c) => c.nameEn),
    );
  }

  Widget _list(BuildContext context, AppLocalizations l10n, String language,
      List<VnDish> dishes, List<VnComponent> components) {
    Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Text(text,
              style: TextStyle(
                  color: CyberColors.muted, fontWeight: FontWeight.w700)),
        );
    return ListView(
      controller: widget.scrollController,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child:
              Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            key: const ValueKey('food-picker-search'),
            controller: _query,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: widget.dishes.isEmpty
                  ? l10n.pickerSearchComponents
                  : l10n.pickerSearch,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: l10n.pickerClear,
                      onPressed: () => setState(_query.clear),
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
        ),
        if (dishes.isEmpty && components.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.pickerNoMatch,
                style: TextStyle(color: CyberColors.muted)),
          ),
        if (dishes.isNotEmpty) ...[
          header(l10n.pickerDishes),
          for (final dish in dishes)
            ListTile(
              key: ValueKey('dish-${dish.code}'),
              title: Text(dish.name(language)),
              onTap: () => Navigator.pop(context, DishPick(dish.code)),
            ),
        ],
        if (components.isNotEmpty) ...[
          if (widget.dishes.isNotEmpty) header(l10n.pickerSingle),
          for (final component in components)
            ListTile(
              key: ValueKey('single-${component.code}'),
              title: Text(component.name(language)),
              subtitle: component.kcalPer100g == null
                  ? null
                  : Text(l10n.pickerPer100g(
                      context.formatNumber(component.kcalPer100g!))),
              onTap: () => Navigator.pop(context, ComponentPick(component)),
            ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}
