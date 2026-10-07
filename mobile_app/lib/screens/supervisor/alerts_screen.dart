import 'package:flutter/material.dart';
import '../../repositories/supervisor_repository.dart';
import '../../models/alert_model.dart';
import '../../widgets/alert_card.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  String _severityFilter = 'ALL'; // 'ALL', 'EMERGENCY', 'DANGER', 'WARNING'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Fleet Alerts & Incident Log"),
      ),
      body: Column(
        children: [
          // Filter Chips (Scrollable to prevent narrow-screen overflow)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                _buildFilterChip('ALL', 'All Incidents', Icons.view_list_rounded),
                const SizedBox(width: 8),
                _buildFilterChip('EMERGENCY', 'Emergency', Icons.emergency_rounded),
                const SizedBox(width: 8),
                _buildFilterChip('DANGER', 'Danger', Icons.dangerous_rounded),
                const SizedBox(width: 8),
                _buildFilterChip('WARNING', 'Warning', Icons.warning_amber_rounded),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<List<AlertItem>>(
              stream: SupervisorRepository.instance.alertsStream,
              initialData: SupervisorRepository.instance.currentAlerts,
              builder: (context, snapshot) {
                final allAlerts = snapshot.data ?? [];
                final alerts = allAlerts.where((a) {
                  if (_severityFilter == 'ALL') return true;
                  return a.severity == _severityFilter;
                }).toList();

                if (alerts.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF10B981).withAlpha(25),
                              border: Border.all(color: const Color(0xFF10B981).withAlpha(60), width: 1.5),
                            ),
                            child: const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 36),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Fleet Sector Clear",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "No active alerts matching this filter category.",
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: alerts.length,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  itemBuilder: (context, index) {
                    final alert = alerts[index];
                    return AlertCard(
                      alert: alert,
                      onAcknowledge: alert.acknowledged
                          ? null
                          : () async {
                              await SupervisorRepository.instance.acknowledgeAlert(alert.id);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Incident for ${alert.workerName} marked acknowledged."),
                                  backgroundColor: const Color(0xFF10B981),
                                ),
                              );
                            },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String val, String label, IconData icon) {
    final isSelected = _severityFilter == val;
    final Color activeColor = val == 'EMERGENCY'
        ? const Color(0xFFF43F5E)
        : val == 'DANGER'
            ? const Color(0xFFEF4444)
            : val == 'WARNING'
                ? const Color(0xFFF59E0B)
                : const Color(0xFF6366F1);

    return InkWell(
      onTap: () => setState(() => _severityFilter = val),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withAlpha(40) : const Color(0xFF131D33),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFF243350),
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? activeColor : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
