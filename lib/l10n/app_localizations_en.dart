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
    return '$weight kg • $height cm • $age years old';
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
    return 'Difference $difference $unit ($percent%)';
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
    return '$weight kg • 3 sets • target $reps reps';
  }

  @override
  String get overloadIncreaseWeight =>
      'Completed 3x12 with manageable difficulty. Increase the load by 2.5 kg next session and restart within the 8–12 rep range.';

  @override
  String get overloadMaintainWeight =>
      'Completed 3x12, but effort was high. Keep the same load for one more session before increasing it.';

  @override
  String get overloadDecreaseWeight =>
      'Performance fell below the target rep range. Reduce the load by 2.5 kg and prioritize controlled technique.';

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
  String get currentLoadError => 'Use a weight from 0 to 1000 kg.';

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
    return '$calories kcal • $protein g protein';
  }

  @override
  String workoutHistorySubtitle(String minutes, String date) {
    return '$minutes min • $date';
  }

  @override
  String exerciseLogSubtitle(String weight, String reps, String nextWeight,
      String nextReps, String date) {
    return '$weight kg • $reps reps\nNext: $nextWeight kg • target $nextReps reps\n$date';
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
    return 'Sedentary · ×$factor';
  }

  @override
  String activityLight(String factor) {
    return 'Light · ×$factor';
  }

  @override
  String activityModerate(String factor) {
    return 'Moderate · ×$factor';
  }

  @override
  String activityActive(String factor) {
    return 'Active · ×$factor';
  }

  @override
  String activityVeryActive(String factor) {
    return 'Very active · ×$factor';
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
      'Estimate: BMR by Mifflin–St Jeor; TDEE = BMR × activity factor. Calories to lose/maintain/gain = 90%/100%/110% of TDEE. Protein = 1.8 g × body weight (kg).';

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
      'Enter valid details and goals to see the estimate. Protein energy (4 kcal/g) cannot exceed total calories.';

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
      'Protein energy (4 kcal/g) cannot exceed total calories. Adjust the calorie or protein target.';

  @override
  String get targetErrorCalorieRange =>
      'The calorie target is outside the supported range (1,000–10,000 kcal). Review your profile or enter a suitable manual target.';

  @override
  String get targetErrorProteinRange =>
      'The protein target must be greater than 0 and at most 500 g. Review your profile or enter a manual target.';

  @override
  String get targetErrorGeneric =>
      'These details do not give a valid estimate. Check age, height, weight and goal.';

  @override
  String get weightTracking => 'Weight tracking';

  @override
  String get noWeights => 'No weigh-ins yet. Save your profile to start.';

  @override
  String latestWeight(String weight, String date) {
    return 'Latest: $weight kg · $date';
  }

  @override
  String weightChange(String change, String from, String to) {
    return 'Change: $change kg from $from to $to';
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
      'Enter a weight greater than 0 and at most 500 kg.';

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
    return 'Chart of $count weigh-ins. From $firstDate: $firstWeight kg to $lastDate: $lastWeight kg. The values are listed below.';
  }

  @override
  String get settingsTitle => 'SETTINGS';

  @override
  String get settingsSubtitle =>
      'Choose a language and visual style. Your selection is saved on this device.';

  @override
  String get offlineModeTitle => 'Offline mode';

  @override
  String get offlineModeBody =>
      'Meal plans, workouts and next-session suggestions run on this device. Your profile and history are saved locally.';

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
    return '$eaten / $target kcal';
  }

  @override
  String diaryProteinProgress(String eaten, String target) {
    return '$eaten / $target g protein';
  }

  @override
  String diaryRemaining(String value) {
    return '$value kcal left for your target';
  }

  @override
  String diaryOver(String value) {
    return '$value kcal over your target';
  }

  @override
  String get diaryNoTarget =>
      'Save your profile to compare with calorie and protein targets.';

  @override
  String diaryMacros(String carbs, String fat) {
    return 'Carbs $carbs g • Fat $fat g';
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
      'Enter an amount greater than 0 and at most 5000 g.';

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
  String get diaryMacroError => '0 to 1000 g.';

  @override
  String diaryPreview(String calories, String protein) {
    return 'Estimate: $calories kcal • $protein g protein';
  }

  @override
  String get diarySave => 'Add to diary';

  @override
  String diaryEntryDetails(String grams, String calories, String protein) {
    return '$grams g • $calories kcal • $protein g protein';
  }

  @override
  String diaryEntryDetailsNoGrams(String calories, String protein) {
    return '$calories kcal • $protein g protein';
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
  String todayWeightWeek(String change) {
    return '7-day change: $change kg';
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
    return 'Total: $calories kcal • $protein g protein';
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
      'OptiFit is not allowed to use the camera. Grant access in the phone settings, or choose an existing photo.';

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
    return '$value g protein';
  }

  @override
  String kcalProteinLine(String kcal, String protein) {
    return '$kcal kcal • P $protein g';
  }

  @override
  String mealMacroLine(String kcal, String protein, String carbs, String fat) {
    return '$kcal kcal • P $protein g • C $carbs g • F $fat g';
  }

  @override
  String get repsRange => 'Enter 0 to 30';

  @override
  String get overloadConfirmIncrease =>
      'First comfortable 3×12 at this load. Repeat it once more; if it is comfortable again, add 2.5 kg.';

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
    return 'Protein $protein g · Carbs $carbs g · Fat $fat g';
  }
}
