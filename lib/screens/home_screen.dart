import 'package:flutter/material.dart';

import '../core/cyber_theme.dart';
import '../core/locale_controller.dart';
import '../l10n/l10n.dart';
import '../services/recommendation_service.dart';
import 'history_screen.dart';
import 'meal_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'workout_screen.dart';

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
  int index = 0;
  final historyKey = GlobalKey<HistoryScreenState>();
  final mealKey = GlobalKey<MealScreenState>();
  late final RecommendationService recommendations;
  late final List<Widget> pages;

  @override
  void initState() {
    super.initState();
    recommendations = RecommendationService();
    pages = [
      MealScreen(
          key: mealKey,
          recommendations: recommendations,
          onOpenProfile: () => _selectPage(3)),
      WorkoutScreen(recommendations: recommendations),
      HistoryScreen(key: historyKey),
      ProfileScreen(
          onProfileChanged: () => mealKey.currentState?.refreshProfile()),
      SettingsScreen(
        themeController: widget.themeController,
        localeController: widget.localeController,
      ),
    ];
  }

  void _selectPage(int value) {
    setState(() => index = value);
    if (value == 0) mealKey.currentState?.refreshProfile();
    if (value == 2) historyKey.currentState?.refresh();
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
      ),
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: _selectPage,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.restaurant_menu_rounded),
            label: l10n.navMeal,
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
          NavigationDestination(
            icon: const Icon(Icons.settings_rounded),
            label: l10n.navSettings,
          ),
        ],
      ),
    );
  }
}
