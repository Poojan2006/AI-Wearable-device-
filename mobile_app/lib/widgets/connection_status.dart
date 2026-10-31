import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class ConnectionStatusWidget extends StatelessWidget {
  final bool isBleConnected;
  final bool isOnline;
  final int pendingSyncCount;
  final VoidCallback? onBleTap;
  final VoidCallback? onSyncTap;

  const ConnectionStatusWidget({
    super.key,
    required this.isBleConnected,
    required this.isOnline,
    required this.pendingSyncCount,
    this.onBleTap,
    this.onSyncTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final cardBg = AppTheme.cardBg(context);
    final borderColor = AppTheme.border(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withAlpha(5),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Row(
        children: [
          // 1. Bluetooth Status
          Expanded(
            child: InkWell(
              onTap: onBleTap,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: _buildIndicator(
                  context: context,
                  icon: isBleConnected
                      ? Icons.bluetooth_connected_rounded
                      : Icons.bluetooth_disabled_rounded,
                  label: 'BLE LINK',
                  status: isBleConnected ? 'CONNECTED' : 'DISCONNECTED',
                  isPositive: isBleConnected,
                ),
              ),
            ),
          ),
          Container(width: 1, height: 26, color: borderColor),

          // 2. Internet Status
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: _buildIndicator(
                context: context,
                icon: isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                label: 'NETWORK',
                status: isOnline ? 'ONLINE' : 'LOCAL ONLY',
                isPositive: isOnline,
              ),
            ),
          ),
          Container(width: 1, height: 26, color: borderColor),

          // 3. Cloud Sync Queue Status
          Expanded(
            child: InkWell(
              onTap: onSyncTap,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: _buildIndicator(
                  context: context,
                  icon: Icons.cloud_sync_rounded,
                  label: 'CLOUD SYNC',
                  status: pendingSyncCount == 0
                      ? 'SYNCED'
                      : '$pendingSyncCount QUEUED',
                  isPositive: pendingSyncCount == 0,
                  customWarning: pendingSyncCount > 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicator({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String status,
    required bool isPositive,
    bool customWarning = false,
  }) {
    final Color dotColor = isPositive
        ? AppTheme.safeGreen
        : (customWarning ? AppTheme.warningAmber : AppTheme.dangerRed);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppTheme.textSub(context)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSub(context),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: dotColor.withAlpha(128), blurRadius: 4),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: dotColor,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
