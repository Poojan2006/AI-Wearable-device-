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
          // Filter Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('ALL', 'All Incidents'),
                const SizedBox(width: 8),
                _buildFilterChip('EMERGENCY', 'Emergency'),
                const SizedBox(width: 8),
                _buildFilterChip('DANGER', 'Danger'),
                const SizedBox(width: 8),
                _buildFilterChip('WARNING', 'Warning'),
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
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 48),
                        SizedBox(height: 12),
                        Text(
                          "No active incidents in this category.",
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: alerts.length,
                  padding: const EdgeInsets.symmetric(vertical: 4),
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

  Widget _buildFilterChip(String val, String label) {
    final isSelected = _severityFilter == val;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _severityFilter = val);
      },
    );
  }
}
