import 'package:flutter/material.dart';

import 'core/cyber_theme.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeController = ThemeController();
  await themeController.load();
  runApp(OptiFitApp(themeController: themeController));
}

class OptiFitApp extends StatelessWidget {
  const OptiFitApp({super.key, required this.themeController});

  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'OptiFit',
          theme: themeController.theme,
          home: HomeScreen(themeController: themeController),
        );
      },
    );
  }
}
