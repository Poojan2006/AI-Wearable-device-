import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../repositories/supervisor_repository.dart';
import '../models/prediction_result.dart';
import 'safety_status_widget.dart';
import 'battery_indicator.dart';

class WorkerStatusCard extends StatelessWidget {
  final FleetWorker worker;
  final VoidCallback onTap;

  const WorkerStatusCard({
    super.key,
    required this.worker,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = SafetyStatus.fromString(worker.status);
    final timeStr = DateFormat('hh:mm:ss a').format(
      DateTime.fromMillisecondsSinceEpoch(worker.lastUpdated),
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: status == SafetyStatus.safe
                ? const Color(0xFF334155)
                : status.color.withAlpha(128),
            width: status == SafetyStatus.safe ? 1 : 1.5,
          ),
        ),
        child: Column(
          children: [
            // Top Row: Name + Safety Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: status.color.withAlpha(38),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          worker.workerId.replaceFirst('W-', ''),
                          style: TextStyle(
                            color: status.color,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          worker.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          "ID: ${worker.workerId}  •  ${worker.deviceId}",
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SafetyStatusWidget(status: status),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Color(0xFF334155), height: 1),
            const SizedBox(height: 10),

            // Bottom Row: Battery, Location, Last Updated
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                BatteryIndicator(percentage: worker.battery),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 3),
                    Text(
                      "${worker.latitude.toStringAsFixed(3)}, ${worker.longitude.toStringAsFixed(3)}",
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                    ),
                  ],
                ),
                Text(
                  "Updated: $timeStr",
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
