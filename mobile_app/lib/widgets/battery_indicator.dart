import 'package:flutter/material.dart';

class BatteryIndicator extends StatelessWidget {
  final int percentage;
  final bool showLabel;

  const BatteryIndicator({
    super.key,
    required this.percentage,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    Color color = const Color(0xFF10B981);
    IconData icon = Icons.battery_full_rounded;

    if (percentage <= 20) {
      color = const Color(0xFFEF4444);
      icon = Icons.battery_alert_rounded;
    } else if (percentage <= 50) {
      color = const Color(0xFFF59E0B);
      icon = Icons.battery_3_bar_rounded;
    } else if (percentage <= 80) {
      icon = Icons.battery_5_bar_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(60), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              "$percentage%",
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
