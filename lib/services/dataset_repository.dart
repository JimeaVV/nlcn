import 'dart:convert';

import 'package:flutter/services.dart';

class RecommendationData {
  const RecommendationData({required this.foods, required this.exercises});

  final List<Map<String, dynamic>> foods;
  final List<Map<String, dynamic>> exercises;

  factory RecommendationData.fromJson(dynamic json) {
    if (json is! Map || json['schema_version'] != 1) {
      throw const FormatException('Unsupported recommendation dataset.');
    }
    final foods = _rows(json['foods'], 'foods');
    final exercises = _rows(json['exercises'], 'exercises');
    for (final food in foods) {
      for (final field in [
        'name',
        'category',
        'macro_group',
        'suggested_prep'
      ]) {
        _requireText(food, field);
      }
      if (!const {'starch', 'meat', 'dairyegg', 'veggie', 'fruit', 'fat'}
          .contains((food['macro_group'] as String).toLowerCase())) {
        throw const FormatException('Unknown food group.');
      }
      for (final field in [
        'calories_per_100g',
        'protein_g',
        'carb_g',
        'fat_g',
        'max_amount_g'
      ]) {
        final value = food[field];
        if (value is! num ||
            !value.isFinite ||
            value < 0 ||
            ((field == 'calories_per_100g' || field == 'max_amount_g') &&
                value == 0)) {
          throw FormatException('Invalid food field: $field.');
        }
      }
    }
    for (final exercise in exercises) {
      for (final field in ['name', 'muscle_group', 'equipment', 'level']) {
        _requireText(exercise, field);
      }
    }
    return RecommendationData(foods: foods, exercises: exercises);
  }

  static List<Map<String, dynamic>> _rows(dynamic value, String name) {
    if (value is! List || value.isEmpty) {
      throw FormatException('The $name dataset is empty.');
    }
    return List<Map<String, dynamic>>.unmodifiable(value.map((row) {
      if (row is! Map) throw FormatException('Invalid $name row.');
      return Map<String, dynamic>.unmodifiable(Map<String, dynamic>.from(row));
    }));
  }

  static void _requireText(Map<String, dynamic> row, String field) {
    final value = row[field];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Invalid dataset field: $field.');
    }
  }
}

/// Loads the dataset packaged in the APK once, without any network access.
class DatasetRepository {
  DatasetRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const assetPath = 'assets/data/recommendations.json';
  final AssetBundle _bundle;
  Future<RecommendationData>? _loaded;

  Future<RecommendationData> load() => _loaded ??= _load();

  Future<RecommendationData> _load() async {
    try {
      final source = await _bundle.loadString(assetPath, cache: false);
      return RecommendationData.fromJson(jsonDecode(source));
    } catch (_) {
      _loaded = null;
      rethrow;
    }
  }
}
