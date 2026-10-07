import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'database/local_database.dart';
import 'services/notification_service.dart';
import 'services/sms_service.dart';
import 'services/auth_service.dart';
import 'models/user_model.dart';
import 'screens/auth/login_screen.dart';
import 'screens/worker/worker_dashboard.dart';
import 'screens/supervisor/supervisor_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Local Notifications & Emergency SMS Service (offline capable)
  try {
    await NotificationService.instance.initialize();
    await SmsService.instance.initialize();
  } catch (_) {}

  // Initialize Firebase with cloud credentials (fail-safe for offline environments)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await AuthService.instance.initializeFirebase();
    debugPrint("[Firebase] Successfully initialized with project: ${Firebase.app().options.projectId}");
  } catch (e) {
    debugPrint("[Firebase] Init note: $e - running with local SQLite buffer fallback.");
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
      builder: (context, child) {
        return Stack(
          alignment: Alignment.bottomCenter,
          children: [
            ?child,
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: IgnorePointer(
                    child: Material(
                      color: Colors.transparent,
                      child: Text(
                        "CSE_C",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2.2,
                          color: Colors.white.withValues(alpha: 0.24),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
