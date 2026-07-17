import 'package:flutter/material.dart';

import 'core/cyber_theme.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const OptiFitApp());
}

class OptiFitApp extends StatelessWidget {
  const OptiFitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OptiFit',
      theme: CyberTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
