import 'package:flutter/material.dart';

import '../../repositories/supervisor_repository.dart';
import '../../models/alert_model.dart';
import '../../widgets/alert_card.dart';
import '../../core/theme/app_theme.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  String _severityFilter = 'ALL'; // 'ALL', 'EMERGENCY', 'DANGER', 'WARNING'

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppTheme.textPrimary(context);
    final textSub = AppTheme.textSub(context);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      appBar: AppBar(title: const Text("Fleet Incident Log")),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _buildFilterChip(
                  'ALL',
                  'All Incidents',
                  Icons.view_list_rounded,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'EMERGENCY',
                  'Emergency',
                  Icons.emergency_rounded,
                ),
                const SizedBox(width: 8),
                _buildFilterChip('DANGER', 'Danger', Icons.dangerous_rounded),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'WARNING',
                  'Warning',
                  Icons.warning_amber_rounded,
                ),
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
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.safeGreen.withAlpha(25),
                            ),
                            child: const Icon(
                              Icons.verified_user_rounded,
                              color: AppTheme.safeGreen,
                              size: 34,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            "Fleet Sector Clear",
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "No active incidents matching this filter category.",
                            style: TextStyle(color: textSub, fontSize: 12.5),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: alerts.length,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  itemBuilder: (context, index) {
                    final alert = alerts[index];
                    return AlertCard(
                      alert: alert,
                      onAcknowledge: alert.acknowledged
                          ? null
                          : () async {
                              await SupervisorRepository.instance
                                  .acknowledgeAlert(alert.id);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "Incident for ${alert.workerName} marked acknowledged.",
                                  ),
                                  backgroundColor: AppTheme.safeGreen,
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
    final isDark = AppTheme.isDark(context);

    final Color activeColor = val == 'EMERGENCY'
        ? AppTheme.dangerRed
        : val == 'DANGER'
        ? AppTheme.dangerRed
        : val == 'WARNING'
        ? AppTheme.warningAmber
        : AppTheme.primary;

    return InkWell(
      onTap: () => setState(() => _severityFilter = val),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withAlpha(isDark ? 40 : 25)
              : AppTheme.cardBg(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeColor : AppTheme.border(context),
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? activeColor : AppTheme.textSub(context),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? activeColor : AppTheme.textSub(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
