import 'package:flutter/material.dart';

import '../core/cyber_theme.dart';
import '../services/api_service.dart';
import 'history_screen.dart';
import 'meal_screen.dart';
import 'settings_screen.dart';
import 'workout_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.themeController});

  final ThemeController themeController;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int index = 0;
  final historyKey = GlobalKey<HistoryScreenState>();
  late final ApiService api;
  late final List<Widget> pages;

  @override
  void initState() {
    super.initState();
    api = ApiService();
    pages = [
      MealScreen(api: api),
      WorkoutScreen(api: api),
      HistoryScreen(key: historyKey),
      SettingsScreen(themeController: widget.themeController),
    ];
  }

  @override
  void dispose() {
    api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        onDestinationSelected: (value) {
          setState(() => index = value);
          if (value == 2) historyKey.currentState?.refresh();
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu_rounded),
            label: 'Meal',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center_rounded),
            label: 'Workout',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
