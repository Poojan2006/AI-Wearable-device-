import 'package:flutter/material.dart';

class ConnectionStatusWidget extends StatelessWidget {
  final bool isBleConnected;
  final bool isOnline;
  final int pendingSyncCount;
  final VoidCallback? onBleTap;

  const ConnectionStatusWidget({
    super.key,
    required this.isBleConnected,
    required this.isOnline,
    required this.pendingSyncCount,
    this.onBleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. Bluetooth Status
          InkWell(
            onTap: onBleTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: _buildIndicator(
                icon: Icons.bluetooth_rounded,
                label: 'Bluetooth',
                status: isBleConnected ? 'CONNECTED' : 'DISCONNECTED',
                isPositive: isBleConnected,
              ),
            ),
          ),
          Container(width: 1, height: 28, color: const Color(0xFF334155)),

          // 2. Internet Status
          _buildIndicator(
            icon: isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
            label: 'Internet',
            status: isOnline ? 'ONLINE' : 'OFFLINE',
            isPositive: isOnline,
          ),
          Container(width: 1, height: 28, color: const Color(0xFF334155)),

          // 3. Cloud Sync Queue Status
          _buildIndicator(
            icon: Icons.cloud_sync_rounded,
            label: 'Cloud Sync',
            status: pendingSyncCount == 0 ? 'SYNCED' : '$pendingSyncCount PENDING',
            isPositive: pendingSyncCount == 0,
            customWarning: pendingSyncCount > 0,
          ),
        ],
      ),
    );
  }

  Widget _buildIndicator({
    required IconData icon,
    required String label,
    required String status,
    required bool isPositive,
    bool customWarning = false,
  }) {
    final Color dotColor = isPositive
        ? const Color(0xFF10B981) // Green
        : (customWarning ? const Color(0xFFF59E0B) : const Color(0xFFEF4444)); // Amber or Red

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white70),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF94A3B8),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: dotColor.withAlpha(128),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 5),
            Text(
              status,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: dotColor,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
