import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'services/storage_service.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force dark status bar
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppTheme.black,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Initialize storage
  final storage = await StorageService.getInstance();
  final isFirstLaunch = storage.isFirstLaunch;

  runApp(ChronoApp(isFirstLaunch: isFirstLaunch));
}

class ChronoApp extends StatelessWidget {
  final bool isFirstLaunch;

  const ChronoApp({super.key, required this.isFirstLaunch});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CHRONO',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: isFirstLaunch ? const OnboardingScreen() : const HomeScreen(),
    );
  }
}
