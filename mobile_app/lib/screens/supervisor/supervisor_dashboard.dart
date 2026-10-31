import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import '../../repositories/supervisor_repository.dart';
import '../../models/alert_model.dart';
import '../../models/prediction_result.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/worker_status_card.dart';
import '../../widgets/alert_card.dart';
import '../../widgets/theme_selector_dialog.dart';
import '../auth/login_screen.dart';
import 'workers_screen.dart';
import 'worker_map_screen.dart';
import 'alerts_screen.dart';
import 'worker_details_screen.dart';

class SupervisorDashboard extends StatefulWidget {
  const SupervisorDashboard({super.key});

  @override
  State<SupervisorDashboard> createState() => _SupervisorDashboardState();
}

class _SupervisorDashboardState extends State<SupervisorDashboard> {
  final SupervisorRepository _repo = SupervisorRepository.instance;
  final AuthService _auth = AuthService.instance;

  int _navIndex = 0;

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Sign Out Confirmation"),
        content: const Text(
          "Are you sure you want to exit the supervisor command console?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerRed,
            ),
            child: const Text("SIGN OUT"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _auth.logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppTheme.textPrimary(context);
    final textSub = AppTheme.textSub(context);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.secondary.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.security_rounded,
                color: AppTheme.secondary,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "FLEET MONITOR",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "${_auth.currentUser?.name ?? 'Supervisor'} • Active Ops",
                    style: TextStyle(
                      fontSize: 10.5,
                      color: textSub,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: "Theme",
            icon: Icon(
              AppTheme.isDark(context)
                  ? Icons.dark_mode_rounded
                  : Icons.light_mode_rounded,
              size: 20,
            ),
            onPressed: () => ThemeSelectorDialog.show(context),
          ),
          IconButton(
            tooltip: "Sign Out",
            icon: const Icon(Icons.logout_rounded, size: 20),
            onPressed: _logout,
          ),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _navIndex,
          children: [
            _buildOverviewTab(),
            const WorkersScreen(),
            const AlertsScreen(),
            const WorkerMapScreen(),
            _buildSettingsTab(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (idx) => setState(() => _navIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: "Dashboard",
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded),
            label: "Workers",
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications_active_rounded),
            label: "Alerts",
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded),
            label: "Map",
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: "Settings",
          ),
        ],
      ),
    );
  }

  // --- TAB 0: OVERVIEW ---
  Widget _buildOverviewTab() {
    final textSub = AppTheme.textSub(context);

    return StreamBuilder<List<FleetWorker>>(
      stream: _repo.workersStream,
      initialData: _repo.currentWorkers,
      builder: (context, workerSnapshot) {
        final workers = workerSnapshot.data ?? [];

        final int totalWorkers = workers.length;
        final int safeCount = workers
            .where(
              (w) => SafetyStatus.fromString(w.status) == SafetyStatus.safe,
            )
            .length;
        final int warningCount = workers
            .where(
              (w) => SafetyStatus.fromString(w.status) == SafetyStatus.warning,
            )
            .length;
        final int dangerCount = workers
            .where(
              (w) => SafetyStatus.fromString(w.status) == SafetyStatus.danger,
            )
            .length;
        final int emergencyCount = workers
            .where(
              (w) =>
                  SafetyStatus.fromString(w.status) == SafetyStatus.emergency,
            )
            .length;

        return StreamBuilder<List<AlertItem>>(
          stream: _repo.alertsStream,
          initialData: _repo.currentAlerts,
          builder: (context, alertSnapshot) {
            final alerts = alertSnapshot.data ?? [];
            final unacknowledged = alerts
                .where((a) => !a.acknowledged)
                .toList();

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // Critical Emergency Alert Banner
                if (emergencyCount > 0 ||
                    unacknowledged.any((a) => a.severity == 'EMERGENCY')) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFDC2626).withAlpha(80),
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(40),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "CRITICAL DISTRESS ACTIVE",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                "Immediate worker assistance required.",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => setState(() => _navIndex = 2),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF991B1B),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            "VIEW",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // 4 Metric Counters Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        "TOTAL",
                        "$totalWorkers",
                        AppTheme.primary,
                        Icons.groups_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricTile(
                        "SAFE",
                        "$safeCount",
                        AppTheme.safeGreen,
                        Icons.check_circle_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricTile(
                        "WARNING",
                        "$warningCount",
                        AppTheme.warningAmber,
                        Icons.warning_amber_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricTile(
                        "ALERT",
                        "${dangerCount + emergencyCount}",
                        AppTheme.dangerRed,
                        Icons.dangerous_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Active Worker Fleet Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "ACTIVE WORKER FLEET",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: textSub,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _navIndex = 1),
                      child: const Text(
                        "VIEW ALL →",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (workers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        "No workers registered in database.",
                        style: TextStyle(color: textSub),
                      ),
                    ),
                  )
                else
                  ...workers
                      .take(4)
                      .map(
                        (w) => WorkerStatusCard(
                          worker: w,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => WorkerDetailsScreen(worker: w),
                              ),
                            );
                          },
                        ),
                      ),

                const SizedBox(height: 18),

                // Recent Incidents Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "RECENT SAFETY INCIDENTS",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: textSub,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _navIndex = 2),
                      child: const Text(
                        "ALL ALERTS →",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (alerts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                        "No recent incidents logged.",
                        style: TextStyle(color: textSub),
                      ),
                    ),
                  )
                else
                  ...alerts
                      .take(3)
                      .map(
                        (a) => AlertCard(
                          alert: a,
                          onAcknowledge: a.acknowledged
                              ? null
                              : () => _repo.acknowledgeAlert(a.id),
                        ),
                      ),

                const SizedBox(height: 20),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMetricTile(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    final isDark = AppTheme.isDark(context);
    final cardBg = AppTheme.cardBg(context);
    final borderColor = AppTheme.border(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withAlpha(4),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withAlpha(isDark ? 30 : 20),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSub(context),
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 4: SUPERVISOR SETTINGS ---
  Widget _buildSettingsTab() {
    final isDark = AppTheme.isDark(context);
    final cardBg = AppTheme.cardBg(context);
    final borderColor = AppTheme.border(context);
    final textPrimary = AppTheme.textPrimary(context);
    final textSub = AppTheme.textSub(context);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withAlpha(25),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.secondary.withAlpha(60),
                    width: 1.5,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.admin_panel_settings_rounded,
                    color: AppTheme.secondary,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _auth.currentUser?.name ?? 'Supervisor Commander',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${_auth.currentUser?.email ?? 'supervisor@safeguard.io'} • Fleet Supervisor",
                      style: TextStyle(fontSize: 12, color: textSub),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Text(
          "CONSOLE SETTINGS",
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: textSub,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),

        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  color: AppTheme.primary,
                ),
                title: Text(
                  "Visual Theme Mode",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: textPrimary,
                  ),
                ),
                subtitle: Text(
                  ThemeService.instance.themeMode == ThemeMode.light
                      ? "Light Mode (Default)"
                      : (ThemeService.instance.themeMode == ThemeMode.dark
                            ? "Dark Mode"
                            : "System Default"),
                  style: TextStyle(fontSize: 11, color: textSub),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => ThemeSelectorDialog.show(context),
              ),
              Divider(color: borderColor, height: 1),
              ListTile(
                leading: const Icon(
                  Icons.map_rounded,
                  color: AppTheme.infoBlue,
                ),
                title: Text(
                  "Fleet Map View",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: textPrimary,
                  ),
                ),
                subtitle: Text(
                  "Live GPS coordinates tracking",
                  style: TextStyle(fontSize: 11, color: textSub),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => setState(() => _navIndex = 3),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        OutlinedButton.icon(
          onPressed: _logout,
          icon: const Icon(
            Icons.logout_rounded,
            size: 16,
            color: AppTheme.dangerRed,
          ),
          label: const Text(
            "SIGN OUT OF CONSOLE",
            style: TextStyle(
              color: AppTheme.dangerRed,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: AppTheme.dangerRed.withAlpha(120),
              width: 1.2,
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }
}
