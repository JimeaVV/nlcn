import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../engine/nutrition_targets.dart';
import '../models/food_log_entry.dart';
import '../models/user_profile.dart';
import '../services/recommendation_service.dart';
import 'app_localizations.dart';

export 'app_localizations.dart';

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// Groups thousands and picks the decimal mark for the current language,
  /// for example 1.800,5 in Vietnamese and 1,800.5 in English.
  String formatNumber(num value, {int decimals = 0}) =>
      NumberFormat.decimalPatternDigits(
        locale: Localizations.localeOf(this).languageCode,
        decimalDigits: decimals,
      ).format(value);

  /// Whole numbers without decimals, otherwise one decimal place.
  String formatMeasurement(double value) =>
      formatNumber(value, decimals: value == value.roundToDouble() ? 0 : 1);

  String formatSigned(num value, {int decimals = 0}) =>
      '${value > 0 ? '+' : ''}${formatNumber(value, decimals: decimals)}';
}

String formatDate(DateTime value) => '${_pad(value.day)}/${_pad(value.month)}/'
    '${value.year}';

String formatDateTime(DateTime value) {
  final date = value.toLocal();
  return '${formatDate(date)} ${_pad(date.hour)}:${_pad(date.minute)}';
}

String _pad(int value) => value.toString().padLeft(2, '0');

extension AppLocalizationsLabels on AppLocalizations {
  String goalLabel(NutritionGoal goal) => switch (goal) {
        NutritionGoal.lose => goalLose,
        NutritionGoal.maintain => goalMaintain,
        NutritionGoal.gain => goalGain,
      };

  /// Fits a three-way goal selector; [goalLabel] is used everywhere else.
  String goalShortLabel(NutritionGoal goal) => switch (goal) {
        NutritionGoal.lose => goalLoseShort,
        NutritionGoal.maintain => goalMaintainShort,
        NutritionGoal.gain => goalGainShort,
      };

  String mealLabel(String meal) => switch (meal) {
        'Breakfast' => breakfast,
        'Lunch' => lunch,
        'Dinner' => dinner,
        _ => meal,
      };

  String mealSlotLabel(MealSlot meal) => switch (meal) {
        MealSlot.breakfast => breakfast,
        MealSlot.lunch => lunch,
        MealSlot.dinner => dinner,
        MealSlot.snack => mealSnack,
      };

  String levelLabel(String level) => switch (level.trim().toLowerCase()) {
        'beginner' => levelBeginner,
        'intermediate' => levelIntermediate,
        'pro' || 'expert' => levelPro,
        _ => level,
      };

  String difficultyLabel(String difficulty) => switch (difficulty) {
        'Easy' => difficultyEasy,
        'Moderate' => difficultyModerate,
        'Hard' => difficultyHard,
        'Failure' => difficultyFailure,
        _ => difficulty,
      };

  /// Dataset muscle groups; values outside the bundled set are shown as-is.
  String muscleLabel(String muscle) => switch (muscle.trim().toLowerCase()) {
        'abdominals' => muscleAbdominals,
        'abductors' => muscleAbductors,
        'adductors' => muscleAdductors,
        'biceps' => muscleBiceps,
        'calves' => muscleCalves,
        'chest' => muscleChest,
        'forearms' => muscleForearms,
        'glutes' => muscleGlutes,
        'hamstrings' => muscleHamstrings,
        'lats' => muscleLats,
        'lower back' => muscleLowerBack,
        'middle back' => muscleMiddleBack,
        'quadriceps' => muscleQuadriceps,
        'shoulders' => muscleShoulders,
        'traps' => muscleTraps,
        'triceps' => muscleTriceps,
        _ => muscle,
      };

  String equipmentLabel(String equipment) =>
      switch (equipment.trim().toLowerCase()) {
        'barbell' => equipmentBarbell,
        'body only' => equipmentBodyOnly,
        'cable' => equipmentCable,
        'dumbbell' => equipmentDumbbell,
        'e-z curl bar' => equipmentEzCurlBar,
        'kettlebells' => equipmentKettlebells,
        'machine' => equipmentMachine,
        'other' => equipmentOther,
        _ => equipment,
      };

  /// Explains a Progressive Overload action. Older logs without a known
  /// action keep the message stored when they were created.
  String overloadMessage(String action, String fallback) => switch (action) {
        'increase_weight' => overloadIncreaseWeight,
        'maintain_weight' => overloadMaintainWeight,
        'decrease_weight' => overloadDecreaseWeight,
        'increase_reps' => overloadIncreaseReps,
        _ => fallback,
      };

  String targetError(NutritionTargetIssue? issue) => switch (issue) {
        NutritionTargetIssue.proteinExceedsCalories => targetErrorProteinEnergy,
        NutritionTargetIssue.calorieRange => targetErrorCalorieRange,
        NutritionTargetIssue.proteinRange => targetErrorProteinRange,
        null => targetErrorGeneric,
      };

  String recommendationError(RecommendationException error) =>
      switch (error.code) {
        RecommendationErrorCode.dataUnavailable => errorDataUnavailable,
        RecommendationErrorCode.calorieTargetOutOfRange =>
          targetErrorCalorieRange,
        RecommendationErrorCode.proteinTargetOutOfRange =>
          targetErrorProteinRange,
        RecommendationErrorCode.proteinExceedsCalories =>
          targetErrorProteinEnergy,
        RecommendationErrorCode.mealNotFound => errorMealNotFound,
        RecommendationErrorCode.workoutNotFound => errorWorkoutNotFound,
        RecommendationErrorCode.invalidInput => errorInvalidInput,
        RecommendationErrorCode.unknown => errorUnknown,
      };
}
