import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'database/local_database.dart';
import 'services/notification_service.dart';
import 'services/auth_service.dart';
import 'models/user_model.dart';
import 'screens/auth/login_screen.dart';
import 'screens/worker/worker_dashboard.dart';
import 'screens/supervisor/supervisor_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Local Notifications (offline capable)
  try {
    await NotificationService.instance.initialize();
  } catch (_) {}

  // Initialize Firebase (fail-safe for offline or unconfigured environments)
  try {
    await Firebase.initializeApp();
    await AuthService.instance.initializeFirebase();
  } catch (_) {
    // Graceful offline fallback: The app works 100% standalone without Firebase
  }

  // Pre-load local SQLite session
  AppUser? cachedUser;
  try {
    cachedUser = await LocalDatabase.instance.getCachedUser();
  } catch (_) {}

  runApp(WorkerSafetyApp(initialUser: cachedUser));
}

class WorkerSafetyApp extends StatelessWidget {
  final AppUser? initialUser;

  const WorkerSafetyApp({super.key, this.initialUser});

  @override
  Widget build(BuildContext context) {
    Widget initialScreen;
    if (initialUser != null) {
      if (initialUser!.role == UserRole.worker) {
        initialScreen = const WorkerDashboard();
      } else {
        initialScreen = const SupervisorDashboard();
      }
    } else {
      initialScreen = const LoginScreen();
    }

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark, // Default to sleek industrial dark mode
      home: initialScreen,
    );
  }
}
