import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../repositories/supervisor_repository.dart';
import '../../models/alert_model.dart';
import '../../models/prediction_result.dart';
import '../../widgets/worker_status_card.dart';
import '../../widgets/alert_card.dart';
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

  Future<void> _logout() async {
    await _auth.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFFF97316), size: 24),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("SUPERVISOR OPS", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                Text(
                  _auth.currentUser?.name ?? "Command Center",
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: "Live Fleet Map",
            icon: const Icon(Icons.map_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WorkerMapScreen()),
            ),
          ),
          IconButton(
            tooltip: "Alert Incidents",
            icon: const Icon(Icons.notifications_active_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AlertsScreen()),
            ),
          ),
          IconButton(
            tooltip: "Sign Out",
            icon: const Icon(Icons.logout_rounded),
            onPressed: _logout,
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<FleetWorker>>(
          stream: _repo.workersStream,
          initialData: _repo.currentWorkers,
          builder: (context, workerSnapshot) {
            final workers = workerSnapshot.data ?? [];

            final int totalWorkers = workers.length;
            final int safeCount = workers
                .where((w) => SafetyStatus.fromString(w.status) == SafetyStatus.safe)
                .length;
            final int warningCount = workers
                .where((w) => SafetyStatus.fromString(w.status) == SafetyStatus.warning)
                .length;
            final int dangerCount = workers
                .where((w) => SafetyStatus.fromString(w.status) == SafetyStatus.danger)
                .length;
            final int emergencyCount = workers
                .where((w) => SafetyStatus.fromString(w.status) == SafetyStatus.emergency)
                .length;

            return StreamBuilder<List<AlertItem>>(
              stream: _repo.alertsStream,
              initialData: _repo.currentAlerts,
              builder: (context, alertSnapshot) {
                final alerts = alertSnapshot.data ?? [];
                final unacknowledged = alerts.where((a) => !a.acknowledged).toList();

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  children: [
                    // Emergency Banner if unacknowledged emergency alerts exist
                    if (emergencyCount > 0 || unacknowledged.any((a) => a.severity == 'EMERGENCY')) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withAlpha(102),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.emergency_rounded, color: Colors.white, size: 28),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "CRITICAL EMERGENCY ALERT",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    "One or more workers have activated SOS or are in acute danger.",
                                    style: TextStyle(color: Colors.white, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const AlertsScreen()),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFFDC2626),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              child: const Text("VIEW", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Metric Counters Dashboard (Section 15)
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricTile(
                            "Total Workers",
                            "$totalWorkers",
                            const Color(0xFF38BDF8),
                            Icons.groups_rounded,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMetricTile(
                            "Safe",
                            "$safeCount",
                            const Color(0xFF10B981),
                            Icons.check_circle_rounded,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMetricTile(
                            "Warning",
                            "$warningCount",
                            const Color(0xFFF59E0B),
                            Icons.warning_amber_rounded,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMetricTile(
                            "Danger/SOS",
                            "${dangerCount + emergencyCount}",
                            const Color(0xFFEF4444),
                            Icons.dangerous_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Quick Operations Strip
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const WorkerMapScreen()),
                            ),
                            icon: const Icon(Icons.map_rounded, size: 16),
                            label: const Text("Live Fleet Map", style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF06B6D4),
                              side: const BorderSide(color: Color(0xFF334155)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const WorkersScreen()),
                            ),
                            icon: const Icon(Icons.people_outline_rounded, size: 16),
                            label: const Text("Full Roster", style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFF97316),
                              side: const BorderSide(color: Color(0xFF334155)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Live Fleet Status Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "ACTIVE WORKER FLEET",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const WorkersScreen()),
                          ),
                          child: const Text(
                            "VIEW ALL →",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFF97316),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    ...workers.map((w) => WorkerStatusCard(
                          worker: w,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => WorkerDetailsScreen(worker: w),
                              ),
                            );
                          },
                        )),

                    const SizedBox(height: 16),

                    // Recent Fleet Incidents Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "RECENT SAFETY INCIDENTS",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AlertsScreen()),
                          ),
                          child: const Text(
                            "ALL ALERTS →",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFF97316),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    if (alerts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: Text(
                            "No recent incidents logged.",
                            style: TextStyle(color: Color(0xFF94A3B8)),
                          ),
                        ),
                      )
                    else
                      ...alerts.take(3).map((a) => AlertCard(
                            alert: a,
                            onAcknowledge: a.acknowledged
                                ? null
                                : () => _repo.acknowledgeAlert(a.id),
                          )),

                    const SizedBox(height: 20),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}
