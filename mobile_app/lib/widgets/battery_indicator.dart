import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

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
    Color color = AppTheme.safeGreen;
    IconData icon = Icons.battery_full_rounded;

    if (percentage <= 20) {
      color = AppTheme.dangerRed;
      icon = Icons.battery_alert_rounded;
    } else if (percentage <= 50) {
      color = AppTheme.warningAmber;
      icon = Icons.battery_3_bar_rounded;
    } else if (percentage <= 80) {
      icon = Icons.battery_5_bar_rounded;
    }

    final isDark = AppTheme.isDark(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(isDark ? 30 : 20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(isDark ? 80 : 60), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              "$percentage%",
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 10.5,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
