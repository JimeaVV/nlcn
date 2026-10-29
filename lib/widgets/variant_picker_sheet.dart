import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/cyber_theme.dart';
import '../l10n/l10n.dart';
import '../models/food_variant.dart';

/// "Gà", "Heo"… for a variant group.
String variantGroupName(AppLocalizations l10n, String group) => switch (group) {
      'ga' => l10n.variantGroupChicken,
      'heo' => l10n.variantGroupPork,
      'bo' => l10n.variantGroupBeef,
      'trung' => l10n.variantGroupEggs,
      'ca' => l10n.variantGroupFish,
      _ => l10n.variantGroupStarch,
    };

IconData variantGroupIcon(String group) => switch (group) {
      'ga' => Icons.kebab_dining_outlined,
      'heo' => Icons.bento_outlined,
      'bo' => Icons.outdoor_grill_outlined,
      'trung' => Icons.egg_outlined,
      'ca' => Icons.set_meal_outlined,
      _ => Icons.rice_bowl_outlined,
    };

/// "bỏ da" / "cả da", lower case for use inside a name.
String Function(String) skinNamer(AppLocalizations l10n) =>
    (skin) => switch (skin) {
          'bo_da' => l10n.variantSkinOff.toLowerCase(),
          'ca_da' => l10n.variantSkinOn.toLowerCase(),
          _ => '',
        };

/// Opens the picker for [group]. It starts at [initialKey] when given,
/// otherwise at the last choice for the group, and remembers the pick.
Future<FoodVariant?> pickFoodVariant(
  BuildContext context, {
  required FoodVariants variants,
  required String group,
  String? initialKey,
}) async {
  final prefKey = 'food_variant_$group';
  String? remembered;
  try {
    remembered = (await SharedPreferences.getInstance()).getString(prefKey);
  } catch (_) {}
  if (!context.mounted) return null;
  final options = variants.inGroup(group);
  if (options.isEmpty) return null;
  final start = variants.find(group, initialKey ?? '') ??
      variants.find(group, remembered ?? '') ??
      options.first;
  final picked = await showModalBottomSheet<FoodVariant>(
    context: context,
    isScrollControlled: true,
    backgroundColor: CyberColors.surface,
    showDragHandle: true,
    builder: (_) => VariantPickerSheet(options: options, initial: start),
  );
  if (picked != null) {
    try {
      await (await SharedPreferences.getInstance())
          .setString(prefKey, picked.key);
    } catch (_) {}
  }
  return picked;
}

/// Part, skin and cooking as rows of chips; only combinations the data has
/// can be chosen. The values per 100 g follow each tap.
class VariantPickerSheet extends StatefulWidget {
  const VariantPickerSheet(
      {super.key, required this.options, required this.initial});

  final List<FoodVariant> options;
  final FoodVariant initial;

  @override
  State<VariantPickerSheet> createState() => _VariantPickerSheetState();
}

class _VariantPickerSheetState extends State<VariantPickerSheet> {
  late String _part = widget.initial.part;
  late String _skin = widget.initial.skin;
  late String _style = widget.initial.style;

  Iterable<FoodVariant> get _ofPart =>
      widget.options.where((v) => v.part == _part);

  FoodVariant? get _chosen {
    for (final v in widget.options) {
      if (v.part == _part && v.skin == _skin && v.style == _style) return v;
    }
    return null;
  }

  /// After a part or skin change, keep the style if that part has it,
  /// otherwise take the first one it has.
  void _settle() {
    final skins = {for (final v in _ofPart) v.skin};
    if (!skins.contains(_skin)) _skin = skins.first;
    final styles = [
      for (final v in _ofPart)
        if (v.skin == _skin) v.style
    ];
    if (!styles.contains(_style)) _style = styles.first;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final vi = Localizations.localeOf(context).languageCode == 'vi';
    final group = widget.initial.group;
    final parts = <String, String>{
      for (final v in widget.options) v.part: vi ? v.partVi : v.partEn,
    };
    final skins = [
      for (final skin in {for (final v in _ofPart) v.skin})
        if (skin.isNotEmpty) skin
    ];
    final styles = <String, String>{
      for (final v in widget.options) v.style: vi ? v.styleVi : v.styleEn,
    };
    final available = {
      for (final v in _ofPart)
        if (v.skin == _skin) v.style
    };
    final chosen = _chosen;
    final number = context.formatNumber;

    Widget chips<T>(String keyPrefix, Map<T, String> labels, T selected,
            bool Function(T) enabled, ValueChanged<T> onSelect) =>
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final MapEntry(key: value, value: label) in labels.entries)
              ChoiceChip(
                key: ValueKey('$keyPrefix-$value'),
                label: Text(label),
                selected: value == selected,
                onSelected: enabled(value)
                    ? (_) => setState(() => onSelect(value))
                    : null,
              ),
          ],
        );
    Widget heading(String text) => Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 8),
          child: Text(text,
              style: TextStyle(
                  color: CyberColors.muted, fontWeight: FontWeight.w700)),
        );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(variantGroupIcon(group), color: CyberColors.cyan),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l10n.variantTitle(variantGroupName(l10n, group)),
                    style: Theme.of(context).textTheme.titleLarge),
              ),
            ]),
            heading(l10n.variantPart),
            chips('variant-part', parts, _part, (_) => true, (part) {
              _part = part;
              _settle();
            }),
            if (skins.isNotEmpty) ...[
              heading(l10n.variantSkin),
              chips(
                  'variant-skin',
                  {
                    for (final skin in skins)
                      skin: skin == 'bo_da'
                          ? l10n.variantSkinOff
                          : l10n.variantSkinOn
                  },
                  _skin,
                  (_) => true, (skin) {
                _skin = skin;
                _settle();
              }),
            ],
            // A food served one way only (cooked rice) skips the cooking row.
            if (styles.length > 1 || !styles.containsKey('chin')) ...[
              heading(l10n.variantStyle),
              chips('variant-style', styles, _style, available.contains,
                  (style) => _style = style),
            ],
            const SizedBox(height: 18),
            if (chosen != null)
              Text(
                l10n.variantPer100g(
                    number(chosen.kcal), number(chosen.protein, decimals: 1)),
                key: const ValueKey('variant-values'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const ValueKey('variant-choose'),
              onPressed:
                  chosen == null ? null : () => Navigator.pop(context, chosen),
              icon: const Icon(Icons.check_rounded),
              label: Text(l10n.variantChoose),
            ),
          ],
        ),
      ),
    );
  }
}
