# OptiFit — offline Android app

OptiFit generates meal plans, workout routines and Progressive Overload targets
entirely on the device. The Android APK includes its food and exercise datasets.
No server, API address, Python installation or internet connection is required
to use the installed app.

Version 1.2 adds a separate Vietnamese profile screen with lose/maintain/gain
goals, independent calorie/protein overrides, daily weight history and a chart.
Save the profile first, then generate a meal plan from the Meal tab. Profile
and weight changes invalidate outdated meal recommendations.

## Run and build

Install Flutter and the Android SDK on the development computer, then run:

```powershell
flutter pub get
flutter run
```

Build an installable Android APK:

```powershell
flutter build apk --release
```

The output is `build/app/outputs/flutter-apk/app-release.apk`. Copy it to your
Android phone and install it. Initial dependency downloads during development
may require internet; the installed application works offline, including on its
first launch. The release manifest has no INTERNET permission. Debug/profile
builds retain the permission used by Flutter's development tools.

The application ID is unchanged. SQLite version 3 adds goal settings and daily
weight measurements without deleting existing profiles or saved histories;
the old current weight becomes one baseline on its original saved date.
Earlier profiles retain a lose-weight goal and use the updated estimate until
the user chooses a different goal or sets a manual target. Saved plans keep
their original targets. Android also requires matching signing keys to update
an existing installation. The current release build uses the
project's debug signing configuration for personal installation; configure a
private release key before publishing to a store.

## Project structure

- `lib/engine/`: pure Dart calorie calculations, meal search, workout ranking and
  Progressive Overload rules, ported from the original Python backend.
- `lib/engine/nutrition_targets.dart`: goal-based starting estimates and manual
  targets, shared by the profile preview and background meal planner.
- `lib/screens/profile_screen.dart`: profile, daily weigh-ins and local chart.
- `lib/services/recommendation_service.dart`: local asynchronous recommendations;
  CPU work is delegated to a worker isolate so Android UI animations stay responsive.
- `lib/services/dataset_repository.dart`: validates and caches the packaged data.
- `assets/data/recommendations.json`: 160 foods and 96 exercises included in the APK.
- `lib/services/database_service.dart`: SQLite profile, saved plans and workout logs.
- `test/`: engine, packaged-asset, worker-service, model and widget regression tests.
- `backend/`: original Python implementation retained as an algorithm reference;
  the app does not execute it or communicate with FastAPI.
- `tool/generate_recommendation_assets.py`: optional maintainer tool to refresh the
  checked-in JSON from `backend/data/`. Python is only needed when using this tool.

## Verification

```powershell
flutter analyze
flutter test
flutter build apk --release
```

Install the release APK, enable airplane mode, save the profile and generate a
meal. Check workout generation, exercise logging, a new/backdated weigh-in,
and persisted profile/weight/plan histories after restarting.

## Dataset maintenance

To regenerate the bundled data after editing the source CSV files:

```powershell
python tool/generate_recommendation_assets.py
```

Commit the regenerated asset and rebuild the APK. Existing installations receive
the new dataset with the app update; no network download is used at runtime.

## Algorithm scope

Nutrition targets use the existing Mifflin-St Jeor BMR and activity factors.
The app's initial goal estimates are 90%/100%/110% of TDEE for lose/maintain/gain;
these are editable product defaults, not clinically validated prescriptions.
Protein starts at the existing 1.8 g/kg and can be overridden independently.
The new flow supports adults 18–100; the calorie input floor of 1000 kcal is
a guardrail, not a statement that this intake suits every person. The adult
scope and lower-bound rationale are documented by
[NIDDK](https://www.niddk.nih.gov/bwp). The protein starting value lies within
the range discussed for athletes by
[NIH ODS](https://ods.od.nih.gov/factsheets/ExerciseAndAthleticPerformance-HealthProfessional/).
The user's manually entered target is kept when weight or goal changes; clear
that target to return to the estimate. Weight is recorded once per calendar
day; editing the same day replaces its value. Backdated entries do not replace
the latest current weight. Deleting all recommendation archives preserves the
profile and weight history.

Meal search uses a sampled candidate pool and a 1.5-second budget per meal, so it
does not guarantee a global optimum or attainment of every daily target. The
result shows signed calorie/protein differences and flags plans outside ±5%
calories or ±10% protein. These tolerances describe the recommendation's match
to the saved target, not nutritional safety, and are not an intake log. Dart's
seeded RNG is repeatable within Dart, but does not select the same foods as
Python's RNG. Workout data still has limited Beginner coverage and no Pro rows;
the UI explicitly reports when it uses another level.

Camera recognition is a future feature. To preserve offline operation it will
need an on-device model bundled with the app, plus user-confirmed portions and a
separate prepared-dish nutrition dataset.
