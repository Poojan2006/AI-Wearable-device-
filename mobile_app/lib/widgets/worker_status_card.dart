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
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(14),
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
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
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
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              worker.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              "ID: ${worker.workerId} • ${worker.deviceId}",
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                SafetyStatusWidget(status: status),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(color: Color(0xFF334155), height: 1),
            const SizedBox(height: 8),

            // Bottom Row: Battery, Location, Last Updated
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                BatteryIndicator(percentage: worker.battery),
                const SizedBox(width: 4),
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          "${worker.latitude.toStringAsFixed(2)}, ${worker.longitude.toStringAsFixed(2)}",
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  timeStr,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
