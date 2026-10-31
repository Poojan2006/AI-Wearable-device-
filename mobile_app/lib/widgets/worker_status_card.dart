import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../repositories/supervisor_repository.dart';
import '../models/prediction_result.dart';
import '../core/theme/app_theme.dart';
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
    final isDark = AppTheme.isDark(context);
    final cardBg = AppTheme.cardBg(context);
    final borderColor = status == SafetyStatus.safe
        ? AppTheme.border(context)
        : status.color.withAlpha(isDark ? 120 : 80);
    final timeStr = DateFormat('hh:mm a')
        .format(DateTime.fromMillisecondsSinceEpoch(worker.lastUpdated));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: status == SafetyStatus.safe ? 1 : 1.4,
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withAlpha(5),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Column(
          children: [
            // Top Row: Avatar + Name + Safety Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: status.color.withAlpha(isDark ? 36 : 22),
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
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              worker.name,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppTheme.textPrimary(context),
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                            ),
                            Text(
                              "ID: ${worker.workerId} • ${worker.deviceId}",
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppTheme.textSub(context),
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SafetyStatusWidget(status: status),
              ],
            ),
            const SizedBox(height: 10),
            Divider(color: AppTheme.border(context), height: 1),
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
                      Icon(
                        Icons.location_on_outlined,
                        size: 12,
                        color: AppTheme.textSub(context),
                      ),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          "${worker.latitude.toStringAsFixed(3)}, ${worker.longitude.toStringAsFixed(3)}",
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.textSub(context),
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 11,
                      color: AppTheme.textSubMuted(context),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      timeStr,
                      style: TextStyle(
                        color: AppTheme.textSubMuted(context),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
