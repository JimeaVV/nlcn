import 'package:flutter/material.dart';

import '../core/cyber_theme.dart';
import '../core/locale_controller.dart';
import '../l10n/l10n.dart';
import '../services/dataset_repository.dart';
import '../services/food_recognizer.dart';
import '../services/recommendation_service.dart';
import '../services/reminder_service.dart';
import '../services/tflite_food_recognizer.dart';
import '../widgets/optifit_bottom_bar.dart';
import '../widgets/section_tabs.dart';
import 'diary_screen.dart';
import 'history_screen.dart';
import 'meal_screen.dart';
import 'profile_screen.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';
import 'today_screen.dart';
import 'workout_screen.dart';

/// Bottom-navigation sections, in display order. Scan sits between
/// [food] and [workout] but is an action, not a section.
enum _Section { today, food, workout, profile }

/// Top tabs inside the Food section.
enum _FoodTab { diary, mealPlan, saved }

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.themeController,
    required this.localeController,
    this.reminders,
  });

  final ThemeController themeController;
  final LocaleController localeController;

  /// Meal reminders; Settings hides them when null (tests).
  final ReminderController? reminders;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  _Section section = _Section.today;
  final todayKey = GlobalKey<TodayScreenState>();
  final foodTabsKey = GlobalKey<SectionTabsState>();
  final diaryKey = GlobalKey<DiaryScreenState>();
  final mealKey = GlobalKey<MealScreenState>();
  final savedMealsKey = GlobalKey<HistoryScreenState>();
  final workoutHistoryKey = GlobalKey<HistoryScreenState>();
  final profileKey = GlobalKey<ProfileScreenState>();
  // One cached copy of the packaged dataset serves every screen.
  final datasets = DatasetRepository();
  late final recommendations = RecommendationService(datasets: datasets);
  // Checks once whether a food model is bundled; its interpreter opens on
  // the first photo.
  late final Future<FoodRecognizer> recognizer = loadFoodRecognizer();

  /// Set while Scan is open, so a double tap cannot open a second camera.
  bool _scanning = false;

  void _select(_Section value) {
    setState(() => section = value);
    switch (value) {
      case _Section.today:
        todayKey.currentState?.refresh();
      case _Section.food:
        diaryKey.currentState?.refresh();
        mealKey.currentState?.refreshProfile();
      case _Section.workout:
        workoutHistoryKey.currentState?.refresh();
      case _Section.profile:
        break;
    }
  }

  void _openFoodTab(_FoodTab tab) {
    _select(_Section.food);
    foodTabsKey.currentState?.show(tab.index);
  }

  void _onFoodTabChanged(int index) {
    switch (_FoodTab.values[index]) {
      case _FoodTab.diary:
        diaryKey.currentState?.refresh();
      case _FoodTab.mealPlan:
        mealKey.currentState?.refreshProfile();
      case _FoodTab.saved:
        savedMealsKey.currentState?.refresh();
    }
  }

  Future<void> _scan() async {
    if (_scanning) return;
    _scanning = true;
    final bool? logged;
    try {
      final model = await recognizer;
      if (!mounted) return;
      logged = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => ScanScreen(datasets: datasets, recognizer: model),
      ));
    } finally {
      _scanning = false;
    }
    if (logged != true || !mounted) return;
    _openFoodTab(_FoodTab.diary);
    diaryKey.currentState?.refresh();
    todayKey.currentState?.refresh();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.l10n.diaryAdded)));
  }

  void _openSettings() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(),
        body: SettingsScreen(
          themeController: widget.themeController,
          localeController: widget.localeController,
          reminders: widget.reminders,
          onHistoryCleared: () {
            savedMealsKey.currentState?.refresh();
            workoutHistoryKey.currentState?.refresh();
            todayKey.currentState?.refresh();
          },
          onDataRestored: () {
            savedMealsKey.currentState?.refresh();
            workoutHistoryKey.currentState?.refresh();
            todayKey.currentState?.refresh();
            diaryKey.currentState?.refresh();
            profileKey.currentState?.refresh();
            mealKey.currentState?.refreshProfile();
          },
        ),
      ),
    ));
  }

  void _onProfileChanged() {
    mealKey.currentState?.refreshProfile();
    diaryKey.currentState?.refresh();
    todayKey.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pages = [
      TodayScreen(
        key: todayKey,
        onOpenDiary: () => _openFoodTab(_FoodTab.diary),
        onOpenWorkout: () => _select(_Section.workout),
        onOpenProfile: () => _select(_Section.profile),
        onScan: _scan,
      ),
      SectionTabs(
        key: foodTabsKey,
        labels: [l10n.navDiary, l10n.tabMealPlan, l10n.tabSaved],
        onChanged: _onFoodTabChanged,
        children: [
          DiaryScreen(key: diaryKey, datasets: datasets),
          MealScreen(
            key: mealKey,
            recommendations: recommendations,
            onOpenProfile: () => _select(_Section.profile),
            onDiaryChanged: () {
              diaryKey.currentState?.refresh();
              todayKey.currentState?.refresh();
            },
            onPlanSaved: () => savedMealsKey.currentState?.refresh(),
          ),
          HistoryScreen(key: savedMealsKey, section: HistorySection.meals),
        ],
      ),
      SectionTabs(
        labels: [l10n.tabWorkoutPlan, l10n.navHistory],
        onChanged: (index) {
          if (index == 1) workoutHistoryKey.currentState?.refresh();
        },
        children: [
          WorkoutScreen(
            recommendations: recommendations,
            onHistoryChanged: () {
              workoutHistoryKey.currentState?.refresh();
              todayKey.currentState?.refresh();
            },
          ),
          HistoryScreen(
              key: workoutHistoryKey, section: HistorySection.workouts),
        ],
      ),
      ProfileScreen(key: profileKey, onProfileChanged: _onProfileChanged),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Image.asset('assets/brand/logo.png',
                  width: 30, height: 30, filterQuality: FilterQuality.medium),
            ),
            const SizedBox(width: 10),
            Text(
              'MACRORUNNER',
              style: TextStyle(
                color: CyberColors.text,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const ValueKey('open-settings'),
            tooltip: l10n.navSettings,
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_rounded),
          ),
        ],
      ),
      body: IndexedStack(index: section.index, children: pages),
      bottomNavigationBar: OptiFitBottomBar(
        selectedIndex: section.index,
        onSelected: (index) => _select(_Section.values[index]),
        scanLabel: l10n.navScan,
        onScan: _scan,
        items: [
          BottomBarItem(
            icon: Icons.today_outlined,
            selectedIcon: Icons.today_rounded,
            label: l10n.navToday,
          ),
          BottomBarItem(
            icon: Icons.restaurant_menu_outlined,
            selectedIcon: Icons.restaurant_menu_rounded,
            label: l10n.navFood,
          ),
          BottomBarItem(
            icon: Icons.fitness_center_outlined,
            selectedIcon: Icons.fitness_center_rounded,
            label: l10n.navWorkout,
          ),
          BottomBarItem(
            icon: Icons.person_outline_rounded,
            selectedIcon: Icons.person_rounded,
            label: l10n.navProfile,
          ),
        ],
      ),
    );
  }
}
