/// Vietnamese dishes and their components, read from assets/data/vn_food.
/// The format is defined in docs/MODEL_CONTRACT.md.
library;

/// One component (or a dish "base" such as broth) with nutrition per 100 g.
/// Values stay null until they are filled from a cited source.
class VnComponent {
  const VnComponent({
    required this.code,
    required this.nameVi,
    required this.nameEn,
    this.kcalPer100g,
    this.proteinPer100g,
    this.carbPer100g,
    this.fatPer100g,
    this.unitNameVi,
    this.unitGrams,
  });

  final String code;
  final String nameVi;
  final String nameEn;
  final double? kcalPer100g;
  final double? proteinPer100g;
  final double? carbPer100g;
  final double? fatPer100g;

  /// A natural unit such as "quả" for eggs, and its weight in grams.
  final String? unitNameVi;
  final double? unitGrams;

  /// Broth, sauce or wrapper that belongs to one dish and is not recognized
  /// on its own.
  bool get isBase => code.startsWith('_base_');

  bool get hasNutrition =>
      kcalPer100g != null &&
      proteinPer100g != null &&
      carbPer100g != null &&
      fatPer100g != null;

  String name(String languageCode) => languageCode == 'vi' ? nameVi : nameEn;
}

/// The usual amount of one component in a dish: grams or natural units.
class VnDishPart {
  const VnDishPart({
    required this.component,
    this.defaultGrams,
    this.defaultUnits,
  });

  final String component;
  final double? defaultGrams;
  final double? defaultUnits;
}

class VnDish {
  const VnDish({
    required this.code,
    required this.nameVi,
    required this.nameEn,
    required this.parts,
  });

  final String code;
  final String nameVi;
  final String nameEn;
  final List<VnDishPart> parts;

  String name(String languageCode) => languageCode == 'vi' ? nameVi : nameEn;
}

class VnFoodData {
  VnFoodData({required this.components, required this.dishes})
      : _dishes = {for (final dish in dishes) dish.code: dish};

  final Map<String, VnComponent> components;

  /// In contract order, which is also the model's output order.
  final List<VnDish> dishes;
  final Map<String, VnDish> _dishes;

  VnDish? dish(String code) => _dishes[code];

  /// Components that can be added to any dish (bases excluded).
  List<VnComponent> get addableComponents => [
        for (final component in components.values)
          if (!component.isBase) component,
      ];
}

/// Parses comma-separated text with a header row. Quoted cells may contain
/// commas, line breaks and doubled quotes, as spreadsheet programs write them.
List<Map<String, String>> parseCsv(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  final source = text.startsWith('﻿') ? text.substring(1) : text;
  for (var i = 0; i < source.length; i++) {
    final char = source[i];
    if (quoted) {
      if (char == '"') {
        if (i + 1 < source.length && source[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        cell.write(char);
      }
    } else if (char == '"') {
      quoted = true;
    } else if (char == ',') {
      row.add(cell.toString());
      cell.clear();
    } else if (char == '\n' || char == '\r') {
      if (char == '\r' && i + 1 < source.length && source[i + 1] == '\n') i++;
      row.add(cell.toString());
      cell.clear();
      if (row.any((value) => value.isNotEmpty)) rows.add(row);
      row = <String>[];
    } else {
      cell.write(char);
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString());
    if (row.any((value) => value.isNotEmpty)) rows.add(row);
  }
  if (rows.isEmpty) return const [];
  final header = rows.first.map((name) => name.trim()).toList();
  return [
    for (final values in rows.skip(1))
      {
        for (var column = 0; column < header.length; column++)
          header[column]: column < values.length ? values[column].trim() : '',
      },
  ];
}

double? _number(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  final number = double.tryParse(text);
  if (number == null || !number.isFinite || number < 0) {
    throw FormatException('Invalid number in Vietnamese food data: $text');
  }
  return number;
}

VnFoodData parseVnFoodData({
  required String componentsCsv,
  required String dishesCsv,
  required String dishNamesCsv,
}) {
  final components = <String, VnComponent>{
    for (final row in parseCsv(componentsCsv))
      row['code']!: VnComponent(
        code: row['code']!,
        nameVi: row['name_vi'] ?? row['code']!,
        nameEn: row['name_en'] ?? row['code']!,
        kcalPer100g: _number(row['kcal_per_100g']),
        proteinPer100g: _number(row['protein_g']),
        carbPer100g: _number(row['carb_g']),
        fatPer100g: _number(row['fat_g']),
        unitNameVi:
            (row['unit_name_vi'] ?? '').isEmpty ? null : row['unit_name_vi'],
        unitGrams: _number(row['unit_grams']),
      ),
  };
  final parts = <String, List<VnDishPart>>{};
  for (final row in parseCsv(dishesCsv)) {
    final component = row['component']!;
    if (!components.containsKey(component)) {
      throw FormatException('Unknown component in dishes.csv: $component');
    }
    parts.putIfAbsent(row['dish']!, () => []).add(VnDishPart(
          component: component,
          defaultGrams: _number(row['default_grams']),
          defaultUnits: _number(row['default_units']),
        ));
  }
  final dishes = [
    for (final row in parseCsv(dishNamesCsv))
      VnDish(
        code: row['code']!,
        nameVi: row['name_vi']!,
        nameEn: row['name_en']!,
        parts: List.unmodifiable(parts[row['code']] ?? const []),
      ),
  ];
  return VnFoodData(components: components, dishes: dishes);
}
