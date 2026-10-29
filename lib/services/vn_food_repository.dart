import 'package:flutter/services.dart';

import '../models/vn_food.dart';

/// Loads the packaged Vietnamese dish and nutrition tables once.
class VnFoodRepository {
  VnFoodRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const _folder = 'assets/data/vn_food';
  final AssetBundle _bundle;
  Future<VnFoodData>? _loaded;
  Future<Map<String, String>>? _tables;

  Future<VnFoodData> load() => _loaded ??= _load();

  /// The raw CSV text of every table, keyed by file name without `.csv`.
  /// Text crosses to the planner's isolate, which parses it there.
  Future<Map<String, String>> loadTables() => _tables ??= _loadTables();

  Future<Map<String, String>> _loadTables() async {
    try {
      const names = ['components', 'dishes', 'dish_names', 'meal_plan'];
      final files = await Future.wait([
        for (final name in names)
          _bundle.loadString('$_folder/$name.csv', cache: false),
      ]);
      return {for (var i = 0; i < names.length; i++) names[i]: files[i]};
    } catch (_) {
      _tables = null;
      rethrow;
    }
  }

  Future<VnFoodData> _load() async {
    try {
      final files = await Future.wait([
        for (final name in ['components', 'dishes', 'dish_names'])
          _bundle.loadString('$_folder/$name.csv', cache: false),
      ]);
      // Optional: without it the app still logs dishes, only without the
      // part and cooking picker.
      var variants = '';
      try {
        variants = await _bundle.loadString('$_folder/food_variants.csv',
            cache: false);
      } catch (_) {}
      return parseVnFoodData(
        componentsCsv: files[0],
        dishesCsv: files[1],
        dishNamesCsv: files[2],
        variantsCsv: variants,
      );
    } catch (_) {
      _loaded = null;
      rethrow;
    }
  }
}
