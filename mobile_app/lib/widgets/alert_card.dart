import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/alert_model.dart';
import '../models/prediction_result.dart';

class AlertCard extends StatelessWidget {
  final AlertItem alert;
  final VoidCallback? onAcknowledge;

  const AlertCard({
    super.key,
    required this.alert,
    this.onAcknowledge,
  });

  @override
  Widget build(BuildContext context) {
    final status = SafetyStatus.fromString(alert.severity);
    final color = status.color;
    final timeStr = DateFormat('MMM d, hh:mm:ss a').format(
      DateTime.fromMillisecondsSinceEpoch(alert.timestamp),
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: alert.acknowledged ? const Color(0xFF334155) : color.withAlpha(180),
          width: alert.acknowledged ? 1 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Severity Tag, Type, Timestamp
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withAlpha(38),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      alert.severity,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    alert.type,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Text(
                timeStr,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Message & Worker
          Text(
            alert.message,
            style: const TextStyle(color: Color(0xFFF8FAFC), fontSize: 13, height: 1.3),
          ),
          const SizedBox(height: 8),

          // Footer: Worker ID + Acknowledge Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Worker: ${alert.workerName} (${alert.workerId})",
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (alert.acknowledged)
                const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 14),
                    SizedBox(width: 4),
                    Text(
                      "ACKNOWLEDGED",
                      style: TextStyle(
                        color: Color(0xFF10B981),
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
                  label: const Text("ACKNOWLEDGE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                  style: TextButton.styleFrom(
                    foregroundColor: color,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
