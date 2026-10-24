// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navWorkout => 'Workout';

  @override
  String get navHistory => 'History';

  @override
  String get navProfile => 'Profile';

  @override
  String get navSettings => 'Settings';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get ok => 'OK';

  @override
  String get retry => 'Retry';

  @override
  String get choose => 'Select';

  @override
  String get minutesUnit => 'min';

  @override
  String get savingButton => 'SAVING...';

  @override
  String get sourceManual => 'manual';

  @override
  String get sourceEstimated => 'estimated';

  @override
  String get mealSubtitle =>
      'Create a meal plan from the profile and goals saved on this device.';

  @override
  String get mealProfileRequiredTitle => 'Set up your profile first';

  @override
  String get mealProfileRequiredBody =>
      'Choose a goal and save your body details in the Profile tab.';

  @override
  String get mealOpenProfile => 'OPEN PROFILE';

  @override
  String mealProfileSummary(String weight, String height, String age) {
    return '$weight kg • $height cm • $age years old';
  }

  @override
  String get caloriesPerDay => 'Calories/day';

  @override
  String get proteinPerDay => 'Protein/day';

  @override
  String targetSources(String calories, String protein) {
    return 'Calories: $calories • Protein: $protein';
  }

  @override
  String get mealEditProfile => 'Edit profile and goals';

  @override
  String get mealGenerate => 'GENERATE MEAL PLAN';

  @override
  String get mealSave => 'SAVE MEAL PLAN';

  @override
  String get mealSaved => 'Meal plan saved.';

  @override
  String get mealSaveFailed =>
      'Could not save the meal plan. Please try again.';

  @override
  String get profileLoadFailed =>
      'Could not load the saved profile. Please try again.';

  @override
  String get mealTargetsTitle => 'Plan targets';

  @override
  String get targetLabel => 'Target';

  @override
  String get mealComparisonTitle => 'Plan vs. target';

  @override
  String get mealWithinTarget => 'Within the target range';

  @override
  String get mealOutsideTarget => 'Outside the target range';

  @override
  String get caloriesLabel => 'Calories';

  @override
  String get proteinLabel => 'Protein';

  @override
  String comparisonDifference(String difference, String unit, String percent) {
    return 'Difference $difference $unit ($percent%)';
  }

  @override
  String get mealToleranceNote =>
      'Tolerance: calories ±5%, protein −10% to +20%. A suggested plan is not a record of what you ate.';

  @override
  String get mealsTitle => 'Meals';

  @override
  String get breakfast => 'Breakfast';

  @override
  String get lunch => 'Lunch';

  @override
  String get dinner => 'Dinner';

  @override
  String get workoutSubtitle =>
      'Exercise suggestions by split, experience level and available time.';

  @override
  String get trainingSetup => 'Training setup';

  @override
  String get workoutSplit => 'Workout split';

  @override
  String get splitPush => 'Push · Chest, shoulders, triceps';

  @override
  String get splitPull => 'Pull · Back, lats, biceps';

  @override
  String get splitLegs => 'Legs · Quads, hamstrings, glutes, calves';

  @override
  String get splitCore => 'Core · Abdominals';

  @override
  String get experienceLevel => 'Experience level';

  @override
  String get levelBeginner => 'Beginner';

  @override
  String get levelIntermediate => 'Intermediate';

  @override
  String get levelPro => 'Pro';

  @override
  String levelOption(String level, String count) {
    return '$level • max $count exercises';
  }

  @override
  String get availableTime => 'Available time (minutes)';

  @override
  String get availableTimeError => 'Use 15–180 minutes.';

  @override
  String get workoutGenerate => 'GENERATE WORKOUT';

  @override
  String get workoutSave => 'SAVE WORKOUT PLAN';

  @override
  String get workoutSaved => 'Workout plan saved.';

  @override
  String get workoutSaveFailed => 'Could not save the workout plan.';

  @override
  String get exerciseLogSaveFailed => 'Could not save the exercise result.';

  @override
  String get nextSessionTitle => 'Next-session recommendation';

  @override
  String nextSessionSummary(String weight, String reps) {
    return '$weight kg • 3 sets • target $reps reps';
  }

  @override
  String get overloadIncreaseWeight =>
      'Completed 3x12 with manageable difficulty. Increase the load by 2.5 kg next session and restart within the 8–12 rep range.';

  @override
  String get overloadMaintainWeight =>
      'Completed 3x12, but effort was high. Keep the same load for one more session before increasing it.';

  @override
  String get overloadDecreaseWeight =>
      'Performance fell below the target rep range. Reduce the load by 2.5 kg and prioritize controlled technique.';

  @override
  String get overloadIncreaseReps =>
      'Keep the same load and try to add reps until all three sets reach 12 reps.';

  @override
  String get sessionSummary => 'Session summary';

  @override
  String get estimatedLabel => 'Estimated';

  @override
  String get exercisesLabel => 'Exercises';

  @override
  String remainingTimeNote(String minutes) {
    return '$minutes min remain for warm-up, rest between sets, cool-down or cardio.';
  }

  @override
  String levelFallbackNote(String requested, String used) {
    return 'Limited exercises for $requested. This plan includes: $used.';
  }

  @override
  String get exerciseSequence => 'Exercise sequence';

  @override
  String get noExerciseData => 'No exercise data returned.';

  @override
  String exerciseDetails(String muscle, String equipment, String minutes) {
    return '$muscle • $equipment • $minutes min';
  }

  @override
  String get logResult => 'Log result';

  @override
  String get savingResult => 'Saving result';

  @override
  String logExerciseTitle(String name) {
    return 'Log $name';
  }

  @override
  String get progressionModel =>
      'Progression model: 3 sets in the 8–12 rep range.';

  @override
  String get currentLoadKg => 'Current weight (kg)';

  @override
  String get currentLoadError => 'Use a weight from 0 to 1000 kg.';

  @override
  String setLabel(String number) {
    return 'Set $number';
  }

  @override
  String get difficulty => 'Difficulty';

  @override
  String get difficultyEasy => 'Easy';

  @override
  String get difficultyModerate => 'Moderate';

  @override
  String get difficultyHard => 'Hard';

  @override
  String get difficultyFailure => 'Failure';

  @override
  String get calculate => 'Calculate';

  @override
  String get historyLoadFailed => 'Could not load local history.';

  @override
  String get clearAllHistory => 'Clear all history';

  @override
  String get clearAllTitle => 'Clear all history?';

  @override
  String get clearAllBody =>
      'All saved meal plans, workout plans and Progressive Overload logs will be deleted. Your profile and weight history will be preserved.';

  @override
  String get clearAllFailed => 'Could not clear local history.';

  @override
  String get historyMealPlans => 'MEAL PLANS';

  @override
  String get historyWorkoutPlans => 'WORKOUT PLANS';

  @override
  String get historyOverloadLogs => 'PROGRESSIVE OVERLOAD LOGS';

  @override
  String get savedMealPlan => 'SAVED MEAL PLAN';

  @override
  String get savedWorkout => 'SAVED WORKOUT';

  @override
  String get savedMealCorrupted =>
      'This saved meal plan is incomplete or corrupted.';

  @override
  String get savedWorkoutCorrupted =>
      'This saved workout plan is incomplete or corrupted.';

  @override
  String get noMealPlans => 'No saved meal plans yet.';

  @override
  String get noWorkoutPlans => 'No saved workout plans yet.';

  @override
  String get noExerciseLogs => 'No exercise logs yet.';

  @override
  String deleteRecordTitle(String record) {
    return 'Delete $record?';
  }

  @override
  String get deleteRecordBody =>
      'This record cannot be recovered after deletion.';

  @override
  String get deleteRecordFailed => 'Could not delete the selected record.';

  @override
  String get recordMealPlan => 'meal plan';

  @override
  String get recordWorkoutPlan => 'workout plan';

  @override
  String get recordExerciseLog => 'exercise log';

  @override
  String get deleteMealPlan => 'Delete meal plan';

  @override
  String get deleteWorkoutPlan => 'Delete workout plan';

  @override
  String get deleteExerciseLog => 'Delete exercise log';

  @override
  String mealHistoryTitle(String calories, String protein) {
    return '$calories kcal • $protein g protein';
  }

  @override
  String workoutHistorySubtitle(String minutes, String date) {
    return '$minutes min • $date';
  }

  @override
  String exerciseLogSubtitle(String weight, String reps, String nextWeight,
      String nextReps, String date) {
    return '$weight kg • $reps reps\nNext: $nextWeight kg • target $nextReps reps\n$date';
  }

  @override
  String get profileDisclaimer =>
      'Estimates are for adults aged 18 and over. Actual needs may differ; this is not medical advice.';

  @override
  String get personalInfo => 'Personal details';

  @override
  String get age => 'Age';

  @override
  String get ageError => 'Enter an age from 18 to 100.';

  @override
  String get male => 'Male';

  @override
  String get female => 'Female';

  @override
  String get heightName => 'Height';

  @override
  String get weightName => 'Weight';

  @override
  String get activityLevel => 'Activity level';

  @override
  String activitySedentary(String factor) {
    return 'Little or no exercise · ×$factor';
  }

  @override
  String activityLight(String factor) {
    return 'Exercise 1–3 times a week · ×$factor';
  }

  @override
  String activityModerate(String factor) {
    return 'Exercise 3–5 times a week · ×$factor';
  }

  @override
  String activityActive(String factor) {
    return 'Exercise 6–7 times a week · ×$factor';
  }

  @override
  String activityVeryActive(String factor) {
    return 'Twice a day, or a physical job · ×$factor';
  }

  @override
  String get goal => 'Goal';

  @override
  String get goalLose => 'Lose fat';

  @override
  String get goalMaintain => 'Maintain weight';

  @override
  String get goalGain => 'Gain weight';

  @override
  String get estimateFormula =>
      'Estimate: BMR by Mifflin–St Jeor; TDEE = BMR × activity factor. Calories to lose/maintain/gain = 90%/100%/110% of TDEE. Protein = 1.8 g × body weight (kg).';

  @override
  String get manualCalories => 'Manual calories (kcal/day)';

  @override
  String get manualProtein => 'Manual protein (g/day)';

  @override
  String numberInvalid(String name) {
    return 'Enter a valid value for $name.';
  }

  @override
  String numberPositiveMax(String name, String max) {
    return '$name must be greater than 0 and at most $max.';
  }

  @override
  String numberRange(String name, String min, String max) {
    return '$name must be between $min and $max.';
  }

  @override
  String get targetsInvalidHint =>
      'Enter valid details and goals to see the estimate. Protein energy (4 kcal/g) cannot exceed total calories.';

  @override
  String get estimatedCalories => 'Estimated calories';

  @override
  String get estimatedProtein => 'Estimated protein';

  @override
  String get saveProfile => 'Save profile';

  @override
  String get savingProfile => 'Saving...';

  @override
  String get profileSaved => 'Profile and goals saved.';

  @override
  String get profileSaveFailed =>
      'Could not save the profile. Please try again.';

  @override
  String get targetErrorProteinEnergy =>
      'Protein energy (4 kcal/g) cannot exceed total calories. Adjust the calorie or protein target.';

  @override
  String get targetErrorCalorieRange =>
      'The calorie target is outside the supported range (1,000–10,000 kcal). Review your profile or enter a suitable manual target.';

  @override
  String get targetErrorProteinRange =>
      'The protein target must be greater than 0 and at most 500 g. Review your profile or enter a manual target.';

  @override
  String get targetErrorGeneric =>
      'These details do not give a valid estimate. Check age, height, weight and goal.';

  @override
  String get weightTracking => 'Weight tracking';

  @override
  String get noWeights => 'No weigh-ins yet. Save your profile to start.';

  @override
  String latestWeight(String weight, String date) {
    return 'Latest: $weight kg · $date';
  }

  @override
  String weightChange(String change, String from, String to) {
    return 'Change: $change kg from $from to $to';
  }

  @override
  String get logWeight => 'Log weight';

  @override
  String get weightHistoryNote =>
      'One value is kept per day; logging again on the same day updates it. The chart shows up to the 90 most recent weigh-ins.';

  @override
  String editWeightTooltip(String date) {
    return 'Edit weight for $date';
  }

  @override
  String deleteWeightTooltip(String date) {
    return 'Delete weight for $date';
  }

  @override
  String weightSaved(String date) {
    return 'Weight saved for $date.';
  }

  @override
  String get weightSaveFailed => 'Could not save the weight. Please try again.';

  @override
  String get deleteWeightTitle => 'Delete this weigh-in?';

  @override
  String get weightDeleted => 'Weigh-in deleted.';

  @override
  String get weightDeleteFailed =>
      'Could not delete the weight. Please try again.';

  @override
  String get editWeight => 'Edit weight';

  @override
  String get weightKg => 'Weight (kg)';

  @override
  String get weightValueError =>
      'Enter a weight greater than 0 and at most 500 kg.';

  @override
  String get weighInDateField => 'Weigh-in date (dd/mm/yyyy)';

  @override
  String get weighInDate => 'Weigh-in date';

  @override
  String get chooseWeighInDate => 'Choose the weigh-in date';

  @override
  String get datePickerFuture => 'Choose a date no later than today.';

  @override
  String get datePickerInvalid => 'Enter a valid date.';

  @override
  String get dateFormatError => 'Enter the date as dd/mm/yyyy.';

  @override
  String get dateAfterToday => 'The weigh-in date cannot be after today.';

  @override
  String get saveWeight => 'Save weight';

  @override
  String weightChartSemantics(String count, String firstDate,
      String firstWeight, String lastDate, String lastWeight) {
    return 'Chart of $count weigh-ins. From $firstDate: $firstWeight kg to $lastDate: $lastWeight kg. The values are listed below.';
  }

  @override
  String get settingsTitle => 'SETTINGS';

  @override
  String get languageTitle => 'Language';

  @override
  String get interfaceStyle => 'Interface style';

  @override
  String get styleCyberpunkDescription => 'Neon cyan, magenta and deep navy.';

  @override
  String get styleMinimalLightDescription => 'Bright, clean and easy to read.';

  @override
  String get styleForestDescription =>
      'Calm green palette for a natural fitness look.';

  @override
  String get styleSunsetDescription => 'Warm orange and violet accents.';

  @override
  String get errorDataUnavailable =>
      'Could not read the food and exercise data packaged with the app.';

  @override
  String get errorMealNotFound =>
      'No suitable meal plan was found for the current target. Try again or adjust the target.';

  @override
  String get errorWorkoutNotFound =>
      'No exercises fit this selection. Try a longer time or a different split.';

  @override
  String get errorInvalidInput =>
      'The entered data is not valid. Please check it.';

  @override
  String get errorUnknown =>
      'Could not generate a recommendation on this device. Please try again.';

  @override
  String get muscleAbdominals => 'Abdominals';

  @override
  String get muscleAbductors => 'Abductors';

  @override
  String get muscleAdductors => 'Adductors';

  @override
  String get muscleBiceps => 'Biceps';

  @override
  String get muscleCalves => 'Calves';

  @override
  String get muscleChest => 'Chest';

  @override
  String get muscleForearms => 'Forearms';

  @override
  String get muscleGlutes => 'Glutes';

  @override
  String get muscleHamstrings => 'Hamstrings';

  @override
  String get muscleLats => 'Lats';

  @override
  String get muscleLowerBack => 'Lower back';

  @override
  String get muscleMiddleBack => 'Middle back';

  @override
  String get muscleQuadriceps => 'Quadriceps';

  @override
  String get muscleShoulders => 'Shoulders';

  @override
  String get muscleTraps => 'Traps';

  @override
  String get muscleTriceps => 'Triceps';

  @override
  String get equipmentBarbell => 'Barbell';

  @override
  String get equipmentBodyOnly => 'Body only';

  @override
  String get equipmentCable => 'Cable';

  @override
  String get equipmentDumbbell => 'Dumbbell';

  @override
  String get equipmentEzCurlBar => 'E-Z curl bar';

  @override
  String get equipmentKettlebells => 'Kettlebells';

  @override
  String get equipmentMachine => 'Machine';

  @override
  String get equipmentOther => 'Other';

  @override
  String get navDiary => 'Diary';

  @override
  String get mealSnack => 'Snack';

  @override
  String get diarySubtitle =>
      'Record what you ate and compare it with your profile targets.';

  @override
  String get diaryToday => 'Today';

  @override
  String get diaryPreviousDay => 'Previous day';

  @override
  String get diaryNextDay => 'Next day';

  @override
  String get diaryEaten => 'Eaten';

  @override
  String diaryCaloriesProgress(String eaten, String target) {
    return '$eaten / $target kcal';
  }

  @override
  String diaryProteinProgress(String eaten, String target) {
    return '$eaten / $target g protein';
  }

  @override
  String diaryRemaining(String value) {
    return '$value kcal left for your target';
  }

  @override
  String diaryOver(String value) {
    return '$value kcal over your target';
  }

  @override
  String get diaryNoTarget =>
      'Save your profile to compare with calorie and protein targets.';

  @override
  String diaryMacros(String carbs, String fat) {
    return 'Carbs $carbs g • Fat $fat g';
  }

  @override
  String get diaryEmptyMeal => 'Nothing logged yet.';

  @override
  String get diaryAddFood => 'ADD FOOD';

  @override
  String get diaryAddTitle => 'Add food to the diary';

  @override
  String get diaryMealSlot => 'Meal';

  @override
  String get diaryFromDataset => 'From dataset';

  @override
  String get diaryCustom => 'Custom';

  @override
  String get diaryFoodSearch => 'Search foods';

  @override
  String get diaryFoodRequired => 'Choose a food from the list.';

  @override
  String get diaryGrams => 'Amount (g)';

  @override
  String get diaryGramsError =>
      'Enter an amount greater than 0 and at most 5000 g.';

  @override
  String get diaryOptionalGrams => 'Amount (g, optional)';

  @override
  String get diaryCustomName => 'Food name';

  @override
  String get diaryCustomNameError => 'Enter a food name.';

  @override
  String get diaryCustomCalories => 'Calories (kcal)';

  @override
  String get diaryCustomCaloriesError => 'Enter calories from 0 to 10000.';

  @override
  String get diaryCarbsLabel => 'Carbs (g)';

  @override
  String get diaryFatLabel => 'Fat (g)';

  @override
  String get diaryMacroError => '0 to 1000 g.';

  @override
  String diaryPreview(String calories, String protein) {
    return 'Estimate: $calories kcal • $protein g protein';
  }

  @override
  String get diarySave => 'Add to diary';

  @override
  String diaryEntryDetails(String grams, String calories, String protein) {
    return '$grams g • $calories kcal • $protein g protein';
  }

  @override
  String diaryEntryDetailsNoGrams(String calories, String protein) {
    return '$calories kcal • $protein g protein';
  }

  @override
  String get diaryAdded => 'Added to the diary.';

  @override
  String get diaryDeleted => 'Food removed from the diary.';

  @override
  String get diaryUndo => 'Undo';

  @override
  String get diaryDeleteEntry => 'Remove food';

  @override
  String get diaryLoadFailed => 'Could not load the diary. Please try again.';

  @override
  String get diarySaveFailed => 'Could not save the diary. Please try again.';

  @override
  String get mealLogPlan => 'LOG TO TODAY\'S DIARY';

  @override
  String get mealPlanLogged => 'Meal plan logged to today\'s diary.';

  @override
  String get mealPlanAlreadyLogged => 'LOGGED TO DIARY';

  @override
  String get navToday => 'Today';

  @override
  String get navFood => 'Food';

  @override
  String get navScan => 'Scan';

  @override
  String get tabMealPlan => 'Meal plan';

  @override
  String get tabSaved => 'Saved';

  @override
  String get tabWorkoutPlan => 'Session';

  @override
  String get todayTitle => 'TODAY';

  @override
  String get todayLoadFailed =>
      'Could not load today\'s data. Pull down to try again.';

  @override
  String get todayOpenDiary => 'Open diary';

  @override
  String todayWeightWeek(String change, String date) {
    return 'Change since $date: $change kg';
  }

  @override
  String get todayNoExercise => 'No exercises logged today.';

  @override
  String todayExercisesLogged(String count) {
    return '$count exercises logged today';
  }

  @override
  String todayLastWorkout(String plan, String date) {
    return 'Last workout: $plan · $date';
  }

  @override
  String get scanTitle => 'Scan food';

  @override
  String get scanManual => 'Log food manually';

  @override
  String get dataTitle => 'Data';

  @override
  String get historyCleared => 'Meal plan and workout history cleared.';

  @override
  String get scanModelPending =>
      'Automatic recognition is still being trained. For now, choose the dish after taking the photo.';

  @override
  String get scanTakePhoto => 'Take photo';

  @override
  String get scanPickGallery => 'Choose from gallery';

  @override
  String get scanPickFailed => 'Could not open the camera or photo library.';

  @override
  String get scanDataFailed =>
      'Could not read the Vietnamese food data packaged with the app.';

  @override
  String get scanResultTitle => 'Scan result';

  @override
  String get scanDishTitle => 'Dish';

  @override
  String get scanChooseDish => 'Choose dish';

  @override
  String get scanOtherDish => 'Other dish';

  @override
  String get scanNoGuess =>
      'The dish was not recognized; choose the one in the photo.';

  @override
  String get scanLowConfidence => 'The model is not sure; pick the right dish.';

  @override
  String get scanComponentsTitle => 'Components';

  @override
  String get scanMaybe => 'Maybe';

  @override
  String get scanAddComponent => 'Add component';

  @override
  String get scanNoNutrition => 'no data yet';

  @override
  String get scanUnitFallback => 'pc';

  @override
  String get scanDecrease => 'Decrease';

  @override
  String get scanIncrease => 'Increase';

  @override
  String scanMissingNutrition(String names) {
    return 'No nutrition data yet for: $names. Untick them or add the data to log this plate.';
  }

  @override
  String scanTotal(String calories, String protein) {
    return 'Total: $calories kcal • $protein g protein';
  }

  @override
  String get scanNothingSelected => 'Select at least one component.';

  @override
  String get scanSave => 'Log to diary';

  @override
  String get scanFrameHint => 'Fit the plate or bowl inside the frame';

  @override
  String get scanClose => 'Close';

  @override
  String get scanTorchOn => 'Turn on light';

  @override
  String get scanTorchOff => 'Turn off light';

  @override
  String get scanGalleryShort => 'Gallery';

  @override
  String get scanManualShort => 'Log food';

  @override
  String get scanCaptureFailed => 'Could not take the photo. Please try again.';

  @override
  String get scanCameraDenied =>
      'MacroRunner is not allowed to use the camera. Grant access in the phone settings, or choose an existing photo.';

  @override
  String get scanNoCamera =>
      'The camera could not be opened. You can still choose a photo or log food manually.';

  @override
  String get scanRetryCamera => 'Try the camera again';

  @override
  String get dailyTargetsTitle => 'Daily targets';

  @override
  String get howCalculated => 'How it is calculated';

  @override
  String get customCalories => 'Set calories myself';

  @override
  String get customProtein => 'Set protein myself';

  @override
  String get heightShort => 'Height (cm)';

  @override
  String get weightShort => 'Weight (kg)';

  @override
  String get genderShort => 'Sex';

  @override
  String showAllWeights(String count) {
    return 'Show all ($count)';
  }

  @override
  String get showFewerWeights => 'Show less';

  @override
  String get goalLoseShort => 'Lose';

  @override
  String get goalMaintainShort => 'Maintain';

  @override
  String get goalGainShort => 'Gain';

  @override
  String get processingButton => 'PROCESSING...';

  @override
  String get planAlreadySaved => 'SAVED';

  @override
  String proteinGrams(String value) {
    return '$value g protein';
  }

  @override
  String kcalProteinLine(String kcal, String protein) {
    return '$kcal kcal • P $protein g';
  }

  @override
  String mealMacroLine(String kcal, String protein, String carbs, String fat) {
    return '$kcal kcal • P $protein g • C $carbs g • F $fat g';
  }

  @override
  String get repsRange => 'Enter 0 to 30';

  @override
  String get overloadConfirmIncrease =>
      'First comfortable 3×12 at this load. Repeat it once more; if it is comfortable again, add 2.5 kg.';

  @override
  String get overloadBodyweightReps =>
      'You completed 3×12 without added load. Next session add 2 reps per set, or move to a harder variation.';

  @override
  String get overloadBodyweightDecrease =>
      'Reps fell below the target range. Aim for 8 clean reps per set, or use an easier variation.';

  @override
  String get scanNotInApp =>
      'This dish may not be in the app yet. Pick the closest dish, or log it by hand in the diary.';

  @override
  String get scanRecognizing => 'Recognizing the dish…';

  @override
  String get scanPortion => 'Whole-dish portion';

  @override
  String scanSuggestions(int count) {
    return 'Might also be there ($count)';
  }

  @override
  String scanSuggestionsChosen(int count, int chosen) {
    return 'Might also be there ($count) · $chosen chosen';
  }

  @override
  String scanMacroGrams(String protein, String carbs, String fat) {
    return 'Protein $protein g · Carbs $carbs g · Fat $fat g';
  }

  @override
  String scanTiming(String total, String photo, String model) {
    return 'Recognized in $total s (photo $photo s · model $model s)';
  }

  @override
  String get diaryFavorites => 'Favorites';

  @override
  String get diaryRecent => 'Recent';

  @override
  String get diaryQuickHint =>
      'Tap a food to add it to the chosen meal right away.';

  @override
  String diaryQuickChip(String name, String calories) {
    return '$name · $calories kcal';
  }

  @override
  String get diaryFavoriteAdd => 'Add to favorites';

  @override
  String get diaryFavoriteRemove => 'Remove from favorites';

  @override
  String diaryFavoriteAdded(String name) {
    return '$name added to favorites.';
  }

  @override
  String diaryFavoriteRemoved(String name) {
    return '$name removed from favorites.';
  }

  @override
  String get diaryCopyToToday => 'Copy this meal to today';

  @override
  String diaryRepeatYesterday(String count, String calories) {
    return 'Same as yesterday ($count foods · $calories kcal)';
  }

  @override
  String diaryCopied(String count) {
    return 'Copied $count foods.';
  }

  @override
  String lastSessionLine(String date, String weight, String reps) {
    return 'Last time ($date): $weight kg × $reps';
  }

  @override
  String lastSessionSuggestion(String weight, String reps) {
    return 'Today\'s suggestion: $weight kg × $reps reps';
  }

  @override
  String get restTimerStart => 'Start rest timer';

  @override
  String restTimerLabel(String time) {
    return 'Rest $time';
  }

  @override
  String get restTimerDone => 'Rest over, next set!';

  @override
  String get restTimerMore => 'Add 15 seconds';

  @override
  String get restTimerLess => 'Take off 15 seconds';

  @override
  String get restTimerStop => 'Stop the timer';

  @override
  String get adaptiveTdeeTitle => 'TDEE from your data';

  @override
  String adaptiveTdeeValue(String tdee) {
    return '$tdee kcal/day';
  }

  @override
  String adaptiveTdeeDetails(
      String days, String intake, String weighIns, String trend) {
    return 'From $days logged days (average $intake kcal) and $weighIns weigh-ins over the last 4 weeks: weight $trend kg/week.';
  }

  @override
  String adaptiveTdeeCompare(String formula) {
    return 'The Mifflin-St Jeor formula estimates $formula kcal.';
  }

  @override
  String adaptiveTdeeUse(String calories) {
    return 'Use as target ($calories kcal)';
  }

  @override
  String adaptiveTdeeUsed(String calories) {
    return 'Calorie target set to $calories kcal. Save the profile to apply it.';
  }

  @override
  String adaptiveTdeeNeedMore(String days, String weighIns, String span,
      String haveDays, String haveWeighIns) {
    return 'More data needed from the last 4 weeks: food logged on at least $days days and at least $weighIns weigh-ins, the first and last $span or more days apart. So far: $haveDays logged days, $haveWeighIns weigh-ins.';
  }

  @override
  String adaptiveTdeeUnsure(String tdee, String formula) {
    return 'This is far from the formula ($tdee vs $formula kcal), maybe because some days were not logged in full. Better not use it as a target yet.';
  }

  @override
  String get adaptiveTdeeInfo =>
      'Real TDEE ≈ average calories eaten − daily weight change × 7700 kcal/kg. The weight change is the best-fit straight line through the weigh-ins of the last 4 weeks. 7700 kcal per kg is a common approximation, not exact for everyone. Days logged under 500 kcal count as incomplete and are left out. This is an estimate, not medical advice.';

  @override
  String get waterTitle => 'Water';

  @override
  String waterProgress(String drunk, String target) {
    return '$drunk / $target ml';
  }

  @override
  String waterGlasses(String count, String glass) {
    return '$count glasses of $glass ml';
  }

  @override
  String get waterAdd => 'Add a glass';

  @override
  String get waterRemove => 'Remove a glass';

  @override
  String get waterNote =>
      'A common reference of 2 litres a day; more in hot weather or hard training.';

  @override
  String streakDays(String count) {
    return '$count-day logging streak';
  }

  @override
  String get streakKeep => 'Log a meal today to keep it going.';

  @override
  String get streakNone => 'Log a meal today to start a streak.';

  @override
  String get weekTitle => 'Last 7 days';

  @override
  String weekLogged(String days) {
    return 'Food logged on $days of 7 days';
  }

  @override
  String weekAverage(String calories, String protein) {
    return 'Per logged day: $calories kcal • $protein g protein on average';
  }

  @override
  String weekVsTarget(String target, String diff) {
    return 'Against the $target kcal target: $diff kcal/day';
  }

  @override
  String weekTraining(String days) {
    return 'Trained on $days days';
  }

  @override
  String weekWeight(String change, String date) {
    return 'Weight $change kg since $date';
  }

  @override
  String get weekEmpty => 'Nothing logged in the last 7 days.';

  @override
  String get remindersTitle => 'Meal reminders';

  @override
  String get remindersBody =>
      'Notifications from the phone itself, no internet needed. They may come a few minutes late.';

  @override
  String get remindersSwitch => 'Turn on reminders';

  @override
  String get remindersDenied =>
      'Notifications are not allowed. Turn them on in Android settings.';

  @override
  String remindersChangeTime(String meal) {
    return 'Change the $meal reminder time';
  }

  @override
  String reminderNotificationTitle(String meal) {
    return '$meal: logged it yet?';
  }

  @override
  String get reminderNotificationBody =>
      'Open MacroRunner to log it, it takes a few seconds.';

  @override
  String get reminderChannel => 'Meal reminders';

  @override
  String get backupTitle => 'Backup';

  @override
  String get backupBody =>
      'Save the profile, food diary, water, weights and training history to one JSON file to keep or move to another phone.';

  @override
  String get backupExport => 'Export a backup file';

  @override
  String get backupImport => 'Restore from a file';

  @override
  String get backupImportTitle => 'Restore data?';

  @override
  String get backupImportBody =>
      'All data on this phone will be replaced by the data in the file. This cannot be undone.';

  @override
  String get backupRestore => 'Restore';

  @override
  String get backupRestored => 'Data restored.';

  @override
  String get backupInvalid => 'This file is not a valid MacroRunner backup.';

  @override
  String get backupFailed => 'Could not create the backup file. Try again.';

  @override
  String get widgetTitle => 'MacroRunner today';

  @override
  String widgetWater(String drunk, String target) {
    return 'Water $drunk / $target L';
  }

  @override
  String widgetStreak(String count) {
    return '$count-day streak';
  }

  @override
  String get pickerSearch => 'Search dishes or single foods';

  @override
  String get pickerSearchComponents => 'Search components';

  @override
  String get pickerClear => 'Clear search';

  @override
  String get pickerNoMatch =>
      'Nothing found. Try another word, such as \"chicken\" or \"rice\".';

  @override
  String get pickerDishes => 'Dishes';

  @override
  String get pickerSingle => 'A single food';

  @override
  String pickerPer100g(String kcal) {
    return '$kcal kcal / 100 g';
  }

  @override
  String get pickerNewFood => 'Food not in the list…';

  @override
  String get pickerNewFoodHint =>
      'Type its name and nutrition. When photos are being kept, this one helps teach the model the new food later.';

  @override
  String get collectTitle => 'Keep photos to teach the model';

  @override
  String get collectBody =>
      'When on, every scanned meal you log keeps its photo (shrunk) with the dish you confirmed. Photos stay on this phone; to train with them, export the zip and put it on Drive.';

  @override
  String get collectSwitch => 'Keep photos of logged scans';

  @override
  String collectStats(String photos, String size) {
    return '$photos photos kept · $size MB';
  }

  @override
  String get collectEmpty => 'No photos yet.';

  @override
  String get collectExport => 'Export photos (zip)';

  @override
  String get collectExportFailed => 'Could not export the photos. Try again.';

  @override
  String get collectDelete => 'Delete kept photos';

  @override
  String get collectDeleteTitle => 'Delete all kept photos?';

  @override
  String get collectDeleteBody =>
      'Deleted photos cannot be recovered. The food diary is not affected.';

  @override
  String get collectDeleted => 'Kept photos deleted.';

  @override
  String get waterRemindersTitle => 'Water reminders';

  @override
  String waterRemindersBody(String goal) {
    return 'Each reminder is one of five messages at random. Once you have drunk $goal in a day, the rest of that day stays quiet. Open the app at least once a week so the reminders keep coming.';
  }

  @override
  String get waterRemindersSwitch => 'Remind me to drink water';

  @override
  String get waterRemindersEvery => 'Remind every';

  @override
  String waterRemindersHours(String hours) {
    return '$hours h';
  }

  @override
  String get waterRemindersFrom => 'From';

  @override
  String get waterRemindersTo => 'Until';

  @override
  String get waterRemindersBadWindow =>
      'The end time must be after the start time.';

  @override
  String get waterReminderChannel => 'Water reminders';

  @override
  String get waterReminder1Title => 'Time for some water 💧';

  @override
  String get waterReminder1Body => 'A glass now helps you stay sharp.';

  @override
  String get waterReminder2Title => 'Had enough water today?';

  @override
  String get waterReminder2Body =>
      'Open MacroRunner to log the glass you just drank.';

  @override
  String get waterReminder3Title => 'Top up';

  @override
  String get waterReminder3Body =>
      'Training goes better when you are hydrated.';

  @override
  String get waterReminder4Title => 'Don\'t wait until you\'re thirsty';

  @override
  String get waterReminder4Body =>
      'Thirst means your body is already a little short.';

  @override
  String get waterReminder5Title => 'One glass of water';

  @override
  String get waterReminder5Body =>
      'Stand up, pour a glass, then get back to it.';

  @override
  String get infoTooltip => 'More info';

  @override
  String diaryDishSummary(String count, String calories, String protein) {
    return '$count items • $calories kcal • $protein g protein';
  }

  @override
  String get gaugeLeftLabel => 'kcal left';

  @override
  String get gaugeOverLabel => 'kcal over target';

  @override
  String get gaugeEatenLabel => 'kcal eaten';

  @override
  String get macroCarbs => 'Carbs';

  @override
  String get macroProtein => 'Protein';

  @override
  String get macroFat => 'Fat';

  @override
  String streakBadge(String days) {
    return '$days days';
  }

  @override
  String get macroInfoTitle => 'Carb and fat targets';

  @override
  String get macroInfo =>
      'Calorie and protein targets come from your profile. Carb and fat targets are estimates: fat gets 30% of the calories (9 kcal per gram), carbs what is left after protein and fat (4 kcal per gram). 30% sits in the middle of the adult range of 20–35% fat and 45–65% carbs (Institute of Medicine, Dietary Reference Intakes, 2005). The C/P/F chips show where the eaten energy came from.';

  @override
  String waterGlassSemantics(String n, String total) {
    return 'Glass $n of $total';
  }

  @override
  String get variantGroupChicken => 'Chicken';

  @override
  String get variantGroupPork => 'Pork';

  @override
  String get variantGroupBeef => 'Beef';

  @override
  String get variantGroupEggs => 'Eggs';

  @override
  String get variantGroupFish => 'Fish';

  @override
  String get variantGroupStarch => 'Rice & starches';

  @override
  String get variantSkinOff => 'Skinless';

  @override
  String get variantSkinOn => 'With skin';

  @override
  String get variantPart => 'Part';

  @override
  String get variantSkin => 'Skin';

  @override
  String get variantStyle => 'Cooking';

  @override
  String get variantChoose => 'Choose';

  @override
  String variantTitle(String group) {
    return '$group: part and cooking';
  }

  @override
  String variantPer100g(String kcal, String protein) {
    return '$kcal kcal • $protein g protein per 100 g';
  }

  @override
  String get variantPickHint => 'Pick by part and cooking';

  @override
  String get scanRefine => 'Pick the part and cooking';

  @override
  String scanDetectedPlate(int count) {
    return '$count foods on the plate';
  }

  @override
  String get scanDetectedHint => 'One row below for each food on the plate.';

  @override
  String scanBoxesLabel(String foods) {
    return 'Photo with a box around each food found: $foods';
  }

  @override
  String detectorClassName(String code) {
    String _temp0 = intl.Intl.selectLogic(
      code,
      {
        'com': 'Rice',
        'bun': 'Vermicelli',
        'mi': 'Noodles',
        'banh_mi_o': 'Bread',
        'ga': 'Chicken',
        'thit_kho': 'Braised pork',
        'thit_nuong': 'Grilled pork',
        'heo': 'Pork',
        'bo': 'Beef',
        'ca': 'Fish',
        'tom': 'Shrimp',
        'muc': 'Squid',
        'trung': 'Egg',
        'dau_hu': 'Tofu',
        'cha': 'Pork roll',
        'cha_gio': 'Spring roll',
        'rau': 'Greens',
        'dua_leo_ca_chua': 'Cucumber, tomato',
        'do_chua': 'Pickles',
        'khoai_tay_chien': 'Fries',
        'canh': 'Soup',
        'other': 'Food',
      },
    );
    return '$_temp0';
  }
}
