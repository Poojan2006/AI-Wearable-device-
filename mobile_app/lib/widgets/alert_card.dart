import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/alert_model.dart';
import '../models/prediction_result.dart';
import '../core/theme/app_theme.dart';

class AlertCard extends StatelessWidget {
  final AlertItem alert;
  final VoidCallback? onAcknowledge;

  const AlertCard({super.key, required this.alert, this.onAcknowledge});

  @override
  Widget build(BuildContext context) {
    final status = SafetyStatus.fromString(alert.severity);
    final color = status.color;
    final isDark = AppTheme.isDark(context);
    final cardBg = AppTheme.cardBg(context);
    final borderColor = alert.acknowledged
        ? AppTheme.border(context)
        : color.withAlpha(isDark ? 140 : 100);
    final timeStr = DateFormat('MMM d, hh:mm a')
        .format(DateTime.fromMillisecondsSinceEpoch(alert.timestamp));

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: alert.acknowledged ? 1 : 1.4,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withAlpha(4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Severity Tag, Type, Timestamp
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withAlpha(isDark ? 36 : 22),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        alert.severity,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w900,
                          fontSize: 9.5,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        alert.type,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.textPrimary(context),
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                timeStr,
                style: TextStyle(
                  color: AppTheme.textSubMuted(context),
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Message
          Text(
            alert.message,
            style: TextStyle(
              color: AppTheme.textPrimary(context),
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),

          // Footer: Worker ID + Acknowledge Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.badge_outlined,
                      size: 13,
                      color: AppTheme.textSub(context),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        "${alert.workerName} (${alert.workerId})",
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.textSub(context),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (alert.acknowledged)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppTheme.safeGreen,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "ACKNOWLEDGED",
                      style: TextStyle(
                        color: AppTheme.safeGreen,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                )
              else if (onAcknowledge != null)
                TextButton.icon(
                  onPressed: onAcknowledge,
                  icon: const Icon(Icons.done_all_rounded, size: 14),
                  label: const Text(
                    "ACKNOWLEDGE",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: color,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
