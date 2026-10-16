import 'package:flutter/material.dart';

import '../core/cyber_theme.dart';
import '../engine/nutrition_targets.dart';
import '../models/recommendation_models.dart';
import '../models/user_profile.dart';
import '../services/database_service.dart';
import '../services/recommendation_service.dart';
import '../widgets/cyber_card.dart';
import '../widgets/error_box.dart';
import '../widgets/meal_result.dart';
import '../widgets/metric_tile.dart';
import '../widgets/neon_button.dart';

class MealScreen extends StatefulWidget {
  const MealScreen({
    super.key,
    required this.recommendations,
    this.database,
    this.onOpenProfile,
  });

  final RecommendationService recommendations;
  final DatabaseService? database;
  final VoidCallback? onOpenProfile;

  @override
  State<MealScreen> createState() => MealScreenState();
}

class MealScreenState extends State<MealScreen> {
  DatabaseService get _database => widget.database ?? DatabaseService.instance;
  UserProfile? _profile;
  Map<String, dynamic>? _targets;
  DietRecommendation? _result;
  String? _error;
  bool _loadingProfile = true;
  bool _generating = false;
  bool _saving = false;
  int _loadVersion = 0;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    refreshProfile();
  }

  Object? _fingerprint(UserProfile? profile) => profile == null
      ? null
      : (
          profile.age,
          profile.gender,
          profile.height,
          profile.weight,
          profile.activityLevel,
          profile.goal,
          profile.calorieOverride,
          profile.proteinOverride,
        );

  Future<void> refreshProfile() async {
    final version = ++_loadVersion;
    try {
      final row = await _database.getProfile();
      if (!mounted || version != _loadVersion) return;
      final profile = row == null ? null : UserProfile.fromMap(row);
      Map<String, dynamic>? targets;
      String? validationError;
      if (profile != null) {
        try {
          targets = calculateNutritionTargets(profile);
        } on ArgumentError catch (error) {
          validationError = '${error.message}';
        }
      }
      setState(() {
        if (_fingerprint(profile) != _fingerprint(_profile)) {
          _generation++;
          _generating = false;
          _result = null;
        }
        _profile = profile;
        _targets = targets;
        _error = validationError;
        _loadingProfile = false;
      });
    } catch (_) {
      if (!mounted || version != _loadVersion) return;
      setState(() {
        _loadingProfile = false;
        _error = 'Không tải được hồ sơ đã lưu. Hãy thử lại.';
      });
    }
  }

  Future<void> _generate() async {
    final profile = _profile;
    if (profile == null || _targets == null || _generating || _saving) return;
    final generation = ++_generation;
    setState(() {
      _generating = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await widget.recommendations.recommendDiet(
        age: profile.age,
        gender: profile.gender,
        weight: profile.weight,
        height: profile.height,
        activityLevel: profile.activityLevel,
        goal: profile.goal,
        calorieOverride: profile.calorieOverride,
        proteinOverride: profile.proteinOverride,
      );
      if (mounted && generation == _generation) {
        setState(() => _result = result);
      }
    } on RecommendationException catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _generating = false);
      }
    }
  }

  Future<void> _save() async {
    final result = _result;
    if (result == null || _saving) return;
    setState(() => _saving = true);
    try {
      await _database.saveMealPlan(result);
      if (mounted) _message('Đã lưu thực đơn.');
    } catch (_) {
      if (mounted) _message('Không lưu được thực đơn. Hãy thử lại.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final targets = _targets;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          Text('THỰC ĐƠN', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text('Tạo thực đơn từ hồ sơ và mục tiêu đã lưu trên máy.',
              style: TextStyle(color: CyberColors.muted)),
          const SizedBox(height: 18),
          if (_loadingProfile)
            const Center(child: CircularProgressIndicator())
          else if (profile == null)
            CyberCard(
              title: 'Thiết lập hồ sơ trước',
              icon: Icons.person_outline_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                      'Chọn mục tiêu và lưu thông tin cơ thể trong tab Hồ sơ.'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: widget.onOpenProfile,
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('MỞ HỒ SƠ'),
                  ),
                ],
              ),
            )
          else
            CyberCard(
              title: profile.goal.label,
              icon: Icons.flag_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${profile.weight.toStringAsFixed(1)} kg • '
                      '${profile.height.toStringAsFixed(0)} cm • ${profile.age} tuổi'),
                  if (targets != null) ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                          child: MetricTile(
                              label: 'Calo/ngày',
                              value: (targets['target_calories'] as num)
                                  .toStringAsFixed(0),
                              unit: 'kcal')),
                      const SizedBox(width: 8),
                      Expanded(
                          child: MetricTile(
                              label: 'Protein/ngày',
                              value: (targets['protein_target'] as num)
                                  .toStringAsFixed(1),
                              unit: 'g')),
                    ]),
                    const SizedBox(height: 10),
                    Text(
                        'Calo: ${targets['calorie_source'] == 'manual' ? 'tự đặt' : 'ước tính'} • '
                        'Protein: ${targets['protein_source'] == 'manual' ? 'tự đặt' : 'ước tính'}',
                        style: TextStyle(color: CyberColors.muted)),
                  ],
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: widget.onOpenProfile,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Sửa hồ sơ và mục tiêu'),
                  ),
                  const SizedBox(height: 6),
                  NeonButton(
                    label: 'TẠO THỰC ĐƠN',
                    icon: Icons.restaurant_menu_rounded,
                    loading: _generating,
                    onPressed: targets == null || _saving ? null : _generate,
                  ),
                ],
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            ErrorBox(message: _error!),
            if (profile == null)
              TextButton(
                  onPressed: refreshProfile, child: const Text('Thử lại')),
          ],
          if (_result != null) ...[
            const SizedBox(height: 16),
            MealResult(recommendation: _result!),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.bookmark_add_outlined),
              label: Text(_saving ? 'ĐANG LƯU...' : 'LƯU THỰC ĐƠN'),
            ),
          ],
        ],
      ),
    );
  }
}
