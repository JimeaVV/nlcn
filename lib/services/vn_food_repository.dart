import 'package:flutter/services.dart';

import '../models/vn_food.dart';

/// Loads the packaged Vietnamese dish and nutrition tables once.
class VnFoodRepository {
  VnFoodRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const _folder = 'assets/data/vn_food';
  final AssetBundle _bundle;
  Future<VnFoodData>? _loaded;

  Future<VnFoodData> load() => _loaded ??= _load();

  Future<VnFoodData> _load() async {
    try {
      final files = await Future.wait([
        for (final name in ['components', 'dishes', 'dish_names'])
          _bundle.loadString('$_folder/$name.csv', cache: false),
      ]);
      return parseVnFoodData(
        componentsCsv: files[0],
        dishesCsv: files[1],
        dishNamesCsv: files[2],
      );
    } catch (_) {
      _loaded = null;
      rethrow;
    }
  }
}
