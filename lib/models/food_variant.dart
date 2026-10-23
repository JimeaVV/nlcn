import 'vn_food.dart';

/// Food groups whose nutrition depends a lot on the part and the cooking,
/// in the order the app shows them.
const variantGroups = ['ga', 'heo', 'bo', 'trung', 'ca', 'tinh_bot'];

/// One food by part, skin and cooking style, e.g. chicken breast, skinless,
/// boiled (assets/data/vn_food/food_variants.csv). Values per 100 g.
class FoodVariant {
  const FoodVariant({
    required this.group,
    required this.part,
    required this.partVi,
    required this.partEn,
    required this.skin,
    required this.style,
    required this.styleVi,
    required this.styleEn,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.unitNameVi,
    this.unitGrams,
  });

  final String group;
  final String part;
  final String partVi;
  final String partEn;

  /// '' when the skin does not apply, otherwise 'bo_da' or 'ca_da'.
  final String skin;
  final String style;
  final String styleVi;
  final String styleEn;
  final double kcal;
  final double protein;
  final double carbs;
  final double fat;
  final String? unitNameVi;
  final double? unitGrams;

  /// "part|skin|style", unique within a group.
  String get key => '$part|$skin|$style';

  /// "Ức gà, bỏ da, luộc / hầm"; a food with one way of serving (cooked
  /// rice) is just its name. [skinName] gives "bỏ da" or "cả da".
  String label(String languageCode, String Function(String skin) skinName) {
    final vi = languageCode == 'vi';
    return [
      vi ? partVi : partEn,
      if (skin.isNotEmpty) skinName(skin),
      if (style != 'chin') (vi ? styleVi : styleEn).toLowerCase(),
    ].join(', ');
  }

  /// As a food the diary logs by weight, searchable by both languages.
  Map<String, dynamic> toFoodMap(
          String languageCode, String Function(String skin) skinName) =>
      {
        'name': label(languageCode, skinName),
        'search': '$partVi $partEn $styleVi $styleEn ${skinName(skin)}',
        'calories_per_100g': kcal,
        'protein_g': protein,
        'carb_g': carbs,
        'fat_g': fat,
        if (unitGrams != null) 'unit_grams': unitGrams,
        'variant': '$group|$key',
      };

  /// This variant standing in for [original] on a scanned plate: the same
  /// code, so the plate and its photo label stay the same.
  VnComponent asComponent(VnComponent original, String nameVi, String nameEn) =>
      VnComponent(
        code: original.code,
        nameVi: nameVi,
        nameEn: nameEn,
        kcalPer100g: kcal,
        proteinPer100g: protein,
        carbPer100g: carbs,
        fatPer100g: fat,
        unitNameVi: unitNameVi,
        unitGrams: unitGrams,
      );
}

/// Every variant, by group.
class FoodVariants {
  FoodVariants(List<FoodVariant> all)
      : _byGroup = {
          for (final group in variantGroups)
            group: [
              for (final variant in all)
                if (variant.group == group) variant
            ],
        };

  static final empty = FoodVariants(const []);

  final Map<String, List<FoodVariant>> _byGroup;

  List<FoodVariant> inGroup(String group) => _byGroup[group] ?? const [];

  Iterable<FoodVariant> get all => _byGroup.values.expand((list) => list);

  bool get isEmpty => all.isEmpty;

  FoodVariant? find(String group, String key) {
    for (final variant in inGroup(group)) {
      if (variant.key == key) return variant;
    }
    return null;
  }
}

FoodVariants parseFoodVariants(String csv) {
  double number(String? text) => double.parse((text ?? '').trim());
  double? optional(String? text) =>
      (text ?? '').trim().isEmpty ? null : double.parse(text!.trim());
  return FoodVariants([
    for (final row in parseCsv(csv))
      FoodVariant(
        group: row['group']!,
        part: row['part']!,
        partVi: row['part_vi']!,
        partEn: row['part_en']!,
        skin: row['skin'] ?? '',
        style: row['style']!,
        styleVi: row['style_vi']!,
        styleEn: row['style_en']!,
        kcal: number(row['kcal_per_100g']),
        protein: number(row['protein_g']),
        carbs: number(row['carb_g']),
        fat: number(row['fat_g']),
        unitNameVi:
            (row['unit_name_vi'] ?? '').isEmpty ? null : row['unit_name_vi'],
        unitGrams: optional(row['unit_grams']),
      ),
  ]);
}

/// Which group a scanned component belongs to, and the variant closest to
/// what its nutrition row assumes, so the picker opens there.
const componentVariants = <String, (String group, String key)>{
  'ga': ('ga', 'ma_dui|bo_da|luoc'),
  'ga_chien': ('ga', 'ma_dui|bo_da|chien'),
  '_base_uc_ga': ('ga', 'uc|bo_da|nuong'),
  'bo': ('bo', 'bap||luoc'),
  '_base_bo_bit_tet': ('bo', 'than||nuong'),
  'ca': ('ca', 'ro_phi||nuong'),
  '_base_ca_hoi': ('ca', 'ca_hoi||nuong'),
  'trung_kho': ('trung', 'ca_qua||luoc'),
  'trung_op_la': ('trung', 'ca_qua||op_la'),
  '_base_trung_chien': ('trung', 'ca_qua||bac'),
  'com': ('tinh_bot', 'com_trang||chin'),
  'thit_kho': ('heo', 'nac_mo||luoc'),
  'thit_nuong': ('heo', 'cot_let||nuong'),
  'suon_nuong': ('heo', 'cot_let||nuong'),
};
