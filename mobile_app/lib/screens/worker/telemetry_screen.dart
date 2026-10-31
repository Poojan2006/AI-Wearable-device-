import 'package:flutter/material.dart';

import '../../services/ble_service.dart';
import '../../models/telemetry_model.dart';
import '../../widgets/telemetry_card.dart';
import '../../core/theme/app_theme.dart';

class TelemetryScreen extends StatelessWidget {
  const TelemetryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final cardBg = AppTheme.cardBg(context);
    final borderColor = AppTheme.border(context);
    final textPrimary = AppTheme.textPrimary(context);
    final textSub = AppTheme.textSub(context);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      appBar: AppBar(title: const Text("Live Sensor Telemetry")),
      body: StreamBuilder<Telemetry>(
        stream: BleService.instance.telemetryStream,
        builder: (context, snapshot) {
          final t = snapshot.data;
          final hasData = t != null;
          final deviceId =
              BleService.instance.connectedDeviceId ??
              (hasData ? t.deviceId : 'ESP32_NOT_CONNECTED');

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // Device Info Header Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "HARDWARE WEARABLE NODE",
                          style: TextStyle(
                            fontSize: 10,
                            color: textSub,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          deviceId,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (hasData
                                    ? AppTheme.safeGreen
                                    : AppTheme.warningAmber)
                                .withAlpha(isDark ? 30 : 20),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              (hasData
                                      ? AppTheme.safeGreen
                                      : AppTheme.warningAmber)
                                  .withAlpha(isDark ? 80 : 50),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            hasData
                                ? Icons.speed_rounded
                                : Icons.bluetooth_searching_rounded,
                            color: hasData
                                ? AppTheme.safeGreen
                                : AppTheme.warningAmber,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            hasData ? "2.0 Hz Live" : "Waiting BLE",
                            style: TextStyle(
                              color: hasData
                                  ? AppTheme.safeGreen
                                  : AppTheme.warningAmber,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Sensor Grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.05,
                children: [
                  TelemetryCard(
                    title: "Heart Rate",
                    value: hasData && t.heartRate > 0
                        ? "${t.heartRate}"
                        : (hasData ? "${t.heartRate}" : "--"),
                    unit: "BPM",
                    icon: Icons.favorite_rounded,
                    accentColor: const Color(0xFFE11D48),
                    statusLabel: hasData
                        ? (t.heartRate > 110
                              ? "TACHYCARDIA"
                              : (t.heartRate < 50 ? "BRADYCARDIA" : "NORMAL"))
                        : "WAITING",
                    progressPercent: hasData && t.heartRate > 0
                        ? (t.heartRate / 160.0).clamp(0.0, 1.0)
                        : 0.0,
                  ),
                  TelemetryCard(
                    title: "SpO2 Oxygen",
                    value: hasData && t.spo2 > 0
                        ? "${t.spo2}"
                        : (hasData ? "${t.spo2}" : "--"),
                    unit: "%",
                    icon: Icons.water_drop_rounded,
                    accentColor: const Color(0xFF0284C7),
                    statusLabel: hasData
                        ? (t.spo2 < 90
                              ? "HYPOXIA"
                              : (t.spo2 < 95 ? "LOW" : "OPTIMAL"))
                        : "WAITING",
                    progressPercent: hasData && t.spo2 > 0
                        ? (t.spo2 / 100.0).clamp(0.0, 1.0)
                        : 0.0,
                  ),
                  TelemetryCard(
                    title: "Ambient Temp",
                    value: hasData && t.temperature > 0
                        ? t.temperature.toStringAsFixed(1)
                        : "--",
                    unit: "°C",
                    icon: Icons.thermostat_rounded,
                    accentColor: hasData && t.temperature > 37.5
                        ? AppTheme.warningAmber
                        : AppTheme.safeGreen,
                    statusLabel: hasData
                        ? (t.temperature > 0
                              ? (t.temperature > 37.5
                                    ? "HIGH HEAT"
                                    : "DHT22 OK")
                              : "NO SENSOR")
                        : "WAITING",
                    progressPercent: hasData && t.temperature > 0
                        ? ((t.temperature - 15.0) / 30.0).clamp(0.0, 1.0)
                        : 0.0,
                  ),
                  TelemetryCard(
                    title: "Toxic Gas PPM",
                    value: hasData ? "${t.gasLevel}" : "--",
                    unit: "PPM",
                    icon: Icons.air_rounded,
                    accentColor: hasData && t.gasLevel > 300
                        ? AppTheme.dangerRed
                        : (hasData && t.gasLevel > 180
                              ? AppTheme.warningAmber
                              : AppTheme.safeGreen),
                    statusLabel: hasData
                        ? (t.gasLevel > 300
                              ? "HAZARDOUS"
                              : (t.gasLevel > 180 ? "ELEVATED" : "SAFE"))
                        : "WAITING",
                    progressPercent: hasData
                        ? (t.gasLevel / 500.0).clamp(0.0, 1.0)
                        : 0.0,
                  ),
                  TelemetryCard(
                    title: "Humidity",
                    value: hasData && t.humidity > 0
                        ? t.humidity.toStringAsFixed(1)
                        : "--",
                    unit: "% RH",
                    icon: Icons.water_rounded,
                    accentColor: const Color(0xFF0D9488),
                    statusLabel: hasData
                        ? (t.humidity > 0
                              ? (t.humidity > 70 ? "HIGH" : "DHT22 OK")
                              : "NO SENSOR")
                        : "WAITING",
                    progressPercent: hasData && t.humidity > 0
                        ? (t.humidity / 100).clamp(0.0, 1.0)
                        : 0.0,
                  ),
                  TelemetryCard(
                    title: "Battery Level",
                    value: hasData ? "${t.battery}" : "--",
                    unit: "%",
                    icon: Icons.battery_charging_full_rounded,
                    accentColor: hasData && t.battery < 20
                        ? AppTheme.dangerRed
                        : AppTheme.safeGreen,
                    statusLabel: hasData
                        ? (t.battery < 20 ? "LOW" : "ACTIVE")
                        : "WAITING",
                    progressPercent: hasData
                        ? (t.battery / 100).clamp(0.0, 1.0)
                        : 0.0,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Posture & Kinetic Safety Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "KINETIC POSTURE & FALL ANALYSIS (MPU6050)",
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: textSub,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatusTile(
                          context: context,
                          icon: Icons.directions_walk_rounded,
                          label: "Motion State",
                          value: hasData ? t.motionStatus : "WAITING",
                          color: AppTheme.infoBlue,
                        ),
                        Container(width: 1, height: 36, color: borderColor),
                        _buildStatusTile(
                          context: context,
                          icon: Icons.personal_injury_rounded,
                          label: "Fall Detection",
                          value: hasData
                              ? (t.fallDetected ? "FALL CONFIRMED" : "CLEAR")
                              : "--",
                          color: hasData && t.fallDetected
                              ? AppTheme.dangerRed
                              : AppTheme.safeGreen,
                        ),
                        Container(width: 1, height: 36, color: borderColor),
                        _buildStatusTile(
                          context: context,
                          icon: Icons.sos_rounded,
                          label: "SOS Switch",
                          value: hasData ? (t.sos ? "TRIGGERED" : "OFF") : "--",
                          color: hasData && t.sos
                              ? AppTheme.dangerRed
                              : AppTheme.safeGreen,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final isDark = AppTheme.isDark(context);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withAlpha(isDark ? 30 : 20),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 0.2,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppTheme.textSub(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
