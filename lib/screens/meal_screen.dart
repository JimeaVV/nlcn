import 'package:flutter/material.dart';

import '../core/cyber_theme.dart';
import '../engine/nutrition_targets.dart';
import '../l10n/l10n.dart';
import '../models/food_log_entry.dart';
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
    this.onDiaryChanged,
    this.onPlanSaved,
  });

  final RecommendationService recommendations;
  final DatabaseService? database;
  final VoidCallback? onOpenProfile;

  /// Called after the current plan is written to today's diary.
  final VoidCallback? onDiaryChanged;

  /// Called after the current plan is added to the saved meal plans.
  final VoidCallback? onPlanSaved;

  @override
  State<MealScreen> createState() => MealScreenState();
}

class MealScreenState extends State<MealScreen> {
  DatabaseService get _database => widget.database ?? DatabaseService.instance;
  UserProfile? _profile;
  Map<String, dynamic>? _targets;
  DietRecommendation? _result;

  /// Built at paint time so a language switch also translates the message.
  String Function(AppLocalizations)? _error;
  bool _loadingProfile = true;
  bool _generating = false;
  bool _saving = false;
  bool _logging = false;

  /// The plan already written to the diary, so it is not logged twice.
  DietRecommendation? _loggedResult;

  /// The plan already saved, so a second tap cannot store a duplicate.
  DietRecommendation? _savedResult;
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
      String Function(AppLocalizations)? validationError;
      if (profile != null) {
        try {
          targets = calculateNutritionTargets(profile);
        } on NutritionTargetError catch (error) {
          validationError = (l10n) => l10n.targetError(error.issue);
        } on ArgumentError {
          validationError = (l10n) => l10n.targetError(null);
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
        _error = (l10n) => l10n.profileLoadFailed;
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
        setState(() => _error = (l10n) => l10n.recommendationError(error));
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _generating = false);
      }
    }
  }

  Future<void> _save() async {
    final result = _result;
    if (result == null || _saving || identical(result, _savedResult)) return;
    setState(() => _saving = true);
    try {
      await _database.saveMealPlan(result);
      if (mounted) setState(() => _savedResult = result);
      widget.onPlanSaved?.call();
      if (mounted) _message(context.l10n.mealSaved);
    } catch (_) {
      if (mounted) _message(context.l10n.mealSaveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _canLog(DietRecommendation result) => result.plan.meals.values
      .every((meal) => meal.items.every((item) => item.hasNutrition));

  Future<void> _logPlan() async {
    final result = _result;
    if (result == null || _logging || identical(result, _loggedResult)) return;
    final today = DateTime.now();
    final entries = [
      for (final meal in result.plan.meals.entries)
        for (final item in meal.value.items)
          FoodLogEntry(
            date: today,
            meal: switch (meal.key) {
              'Breakfast' => MealSlot.breakfast,
              'Lunch' => MealSlot.lunch,
              'Dinner' => MealSlot.dinner,
              _ => MealSlot.snack,
            },
            name: item.name,
            grams: item.grams,
            calories: item.calories!,
            protein: item.protein!,
            carbs: item.carbs ?? 0,
            fat: item.fat ?? 0,
            source: FoodLogSource.mealPlan,
          ),
    ];
    setState(() => _logging = true);
    try {
      await _database.addFoodLogEntries(entries);
      if (!mounted) return;
      setState(() => _loggedResult = result);
      _message(context.l10n.mealPlanLogged);
      widget.onDiaryChanged?.call();
    } catch (_) {
      if (mounted) _message(context.l10n.diarySaveFailed);
    } finally {
      if (mounted) setState(() => _logging = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final targets = _targets;
    final l10n = context.l10n;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          Text(l10n.mealSubtitle, style: TextStyle(color: CyberColors.muted)),
          const SizedBox(height: 18),
          if (_loadingProfile)
            const Center(child: CircularProgressIndicator())
          else if (profile == null)
            CyberCard(
              title: l10n.mealProfileRequiredTitle,
              icon: Icons.person_outline_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.mealProfileRequiredBody),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: widget.onOpenProfile,
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: Text(l10n.mealOpenProfile),
                  ),
                ],
              ),
            )
          else
            CyberCard(
              title: l10n.goalLabel(profile.goal),
              icon: Icons.flag_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.mealProfileSummary(
                    context.formatNumber(profile.weight, decimals: 1),
                    context.formatNumber(profile.height),
                    '${profile.age}',
                  )),
                  if (targets != null) ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                          child: MetricTile(
                              label: l10n.caloriesPerDay,
                              value: context.formatNumber(
                                  targets['target_calories'] as num),
                              unit: 'kcal')),
                      const SizedBox(width: 8),
                      Expanded(
                          child: MetricTile(
                              label: l10n.proteinPerDay,
                              value: context.formatNumber(
                                  targets['protein_target'] as num,
                                  decimals: 1),
                              unit: 'g')),
                    ]),
                    const SizedBox(height: 10),
                    Text(
                        l10n.targetSources(
                          targets['calorie_source'] == 'manual'
                              ? l10n.sourceManual
                              : l10n.sourceEstimated,
                          targets['protein_source'] == 'manual'
                              ? l10n.sourceManual
                              : l10n.sourceEstimated,
                        ),
                        style: TextStyle(color: CyberColors.muted)),
                  ],
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: widget.onOpenProfile,
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(l10n.mealEditProfile),
                  ),
                  const SizedBox(height: 6),
                  NeonButton(
                    label: l10n.mealGenerate,
                    icon: Icons.restaurant_menu_rounded,
                    loading: _generating,
                    onPressed: targets == null || _saving ? null : _generate,
                  ),
                ],
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            ErrorBox(message: _error!(l10n)),
            if (profile == null)
              TextButton(onPressed: refreshProfile, child: Text(l10n.retry)),
          ],
          if (_result != null) ...[
            const SizedBox(height: 16),
            MealResult(recommendation: _result!),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const ValueKey('meal-save-plan'),
              onPressed:
                  _saving || identical(_result, _savedResult) ? null : _save,
              icon: Icon(identical(_result, _savedResult)
                  ? Icons.check_rounded
                  : Icons.bookmark_add_outlined),
              label: Text(identical(_result, _savedResult)
                  ? l10n.planAlreadySaved
                  : _saving
                      ? l10n.savingButton
                      : l10n.mealSave),
            ),
            if (_canLog(_result!)) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const ValueKey('meal-log-plan'),
                onPressed: _logging || identical(_result, _loggedResult)
                    ? null
                    : _logPlan,
                icon: Icon(identical(_result, _loggedResult)
                    ? Icons.check_rounded
                    : Icons.menu_book_rounded),
                label: Text(identical(_result, _loggedResult)
                    ? l10n.mealPlanAlreadyLogged
                    : l10n.mealLogPlan),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
