import 'package:flutter/material.dart';

import 'theme/app_tokens.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const ApLiveTrackerApp());
}

class ApLiveTrackerApp extends StatelessWidget {
  const ApLiveTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ap Live Tracker',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(isDark: false),
      darkTheme: buildAppTheme(isDark: true),
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
    );
  }
}
