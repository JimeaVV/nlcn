import 'package:flutter/material.dart';

import '../core/cyber_theme.dart';
import '../core/locale_controller.dart';
import '../l10n/l10n.dart';
import '../services/dataset_repository.dart';
import '../services/recommendation_service.dart';
import 'diary_screen.dart';
import 'history_screen.dart';
import 'meal_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'workout_screen.dart';

/// Bottom-navigation tabs, in display order.
enum _Tab { meal, diary, workout, history, profile }

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.themeController,
    required this.localeController,
  });

  final ThemeController themeController;
  final LocaleController localeController;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  _Tab tab = _Tab.meal;
  final historyKey = GlobalKey<HistoryScreenState>();
  final mealKey = GlobalKey<MealScreenState>();
  final diaryKey = GlobalKey<DiaryScreenState>();
  late final List<Widget> pages;

  @override
  void initState() {
    super.initState();
    // One cached copy of the packaged dataset serves every screen.
    final datasets = DatasetRepository();
    final recommendations = RecommendationService(datasets: datasets);
    pages = [
      MealScreen(
        key: mealKey,
        recommendations: recommendations,
        onOpenProfile: () => _select(_Tab.profile),
        onDiaryChanged: () => diaryKey.currentState?.refresh(),
      ),
      DiaryScreen(key: diaryKey, datasets: datasets),
      WorkoutScreen(recommendations: recommendations),
      HistoryScreen(key: historyKey),
      ProfileScreen(onProfileChanged: () {
        mealKey.currentState?.refreshProfile();
        diaryKey.currentState?.refresh();
      }),
    ];
  }

  void _select(_Tab value) {
    setState(() => tab = value);
    switch (value) {
      case _Tab.meal:
        mealKey.currentState?.refreshProfile();
      case _Tab.diary:
        diaryKey.currentState?.refresh();
      case _Tab.history:
        historyKey.currentState?.refresh();
      case _Tab.workout:
      case _Tab.profile:
        break;
    }
  }

  void _openSettings() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(),
        body: SettingsScreen(
          themeController: widget.themeController,
          localeController: widget.localeController,
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.bolt_rounded, color: CyberColors.lime),
            const SizedBox(width: 8),
            Text(
              'OPTIFIT',
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
      body: IndexedStack(index: tab.index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab.index,
        onDestinationSelected: (value) => _select(_Tab.values[value]),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.restaurant_menu_rounded),
            label: l10n.navMeal,
          ),
          NavigationDestination(
            icon: const Icon(Icons.menu_book_rounded),
            label: l10n.navDiary,
          ),
          NavigationDestination(
            icon: const Icon(Icons.fitness_center_rounded),
            label: l10n.navWorkout,
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_rounded),
            label: l10n.navHistory,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded),
            label: l10n.navProfile,
          ),
        ],
      ),
    );
  }
}
