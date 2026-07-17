import 'package:flutter/material.dart';
import '../core/cyber_theme.dart';
import '../services/api_service.dart';
import 'history_screen.dart';
import 'meal_screen.dart';
import 'workout_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int index = 0;
  final api = ApiService();
  final historyKey = GlobalKey<HistoryScreenState>();

  @override
  Widget build(BuildContext context) {
    final pages = [
      MealScreen(api: api),
      WorkoutScreen(api: api),
      HistoryScreen(key: historyKey),
    ];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: CyberColors.background,
        title: const Row(children: [
          Icon(Icons.bolt_rounded,color: CyberColors.lime),
          SizedBox(width: 8),
          Text('OPTIFIT',style: TextStyle(fontWeight: FontWeight.w900,letterSpacing: 2)),
        ]),
      ),
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) {
          setState(() => index = value);
          if (value == 2) historyKey.currentState?.refresh();
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.restaurant_menu_rounded),label: 'Meal'),
          NavigationDestination(icon: Icon(Icons.fitness_center_rounded),label: 'Workout'),
          NavigationDestination(icon: Icon(Icons.history_rounded),label: 'History'),
        ],
      ),
    );
  }
}
