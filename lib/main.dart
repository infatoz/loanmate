import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'core/app_theme.dart';
import 'providers/theme_provider.dart';
import 'services/notification_service.dart';
import 'screens/splash_screen.dart';

Future<void> _requestPermissions() async {
  // Request notification permission (Android 13+)
  await Permission.notification.request();
  // Request schedule exact alarm (for precise notification timing)
  await Permission.scheduleExactAlarm.request();
  // Storage permission for PDF export
  await Permission.storage.request();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Shared Preferences
  final prefs = await SharedPreferences.getInstance();

  // Initialize notifications
  await NotificationService().init();

  // Request permissions on first run
  await _requestPermissions();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const LoanMateApp(),
    ),
  );
}

class LoanMateApp extends ConsumerWidget {
  const LoanMateApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'LoanMate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const SplashScreen(),
    );
  }
}
