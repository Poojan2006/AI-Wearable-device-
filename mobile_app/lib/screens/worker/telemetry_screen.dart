import 'package:flutter/material.dart';
import '../../services/ble_service.dart';
import '../../models/telemetry_model.dart';
import '../../widgets/telemetry_card.dart';

class TelemetryScreen extends StatelessWidget {
  const TelemetryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Live Sensor Telemetry"),
      ),
      body: StreamBuilder<Telemetry>(
        stream: BleService.instance.telemetryStream,
        builder: (context, snapshot) {
          final t = snapshot.data ??
              Telemetry(
                deviceId: BleService.instance.connectedDeviceId ?? 'ESP32_SAFE_01',
              );

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // Device Info Header Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "HARDWARE SAFETY NODE",
                          style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w700),
                        ),
                        Text(
                          t.deviceId,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withAlpha(38),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.speed_rounded, color: Color(0xFF10B981), size: 14),
                          const SizedBox(width: 4),
                          Text("2.0 Hz Rate", style: TextStyle(color: const Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

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
                    value: "${t.heartRate}",
                    unit: "BPM",
                    icon: Icons.favorite_rounded,
                    accentColor: t.heartRate > 110 ? const Color(0xFFEF4444) : const Color(0xFFF43F5E),
                    statusLabel: t.heartRate > 110 ? "ELEVATED" : "NORMAL",
                    progressPercent: (t.heartRate - 40) / 120,
                  ),
                  TelemetryCard(
                    title: "SpO2 Oxygen",
                    value: "${t.spo2}",
                    unit: "%",
                    icon: Icons.water_drop_rounded,
                    accentColor: t.spo2 < 92 ? const Color(0xFFEF4444) : const Color(0xFF06B6D4),
                    statusLabel: t.spo2 < 92 ? "LOW O2" : "OPTIMAL",
                    progressPercent: (t.spo2 - 70) / 30,
                  ),
                  TelemetryCard(
                    title: "Body Temp",
                    value: t.temperature.toStringAsFixed(1),
                    unit: "°C",
                    icon: Icons.thermostat_rounded,
                    accentColor: t.temperature > 37.5 ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                    statusLabel: t.temperature > 37.5 ? "FEVER RISK" : "NORMAL",
                    progressPercent: (t.temperature - 34.0) / 8.0,
                  ),
                  TelemetryCard(
                    title: "Toxic Gas PPM",
                    value: "${t.gasLevel}",
                    unit: "PPM",
                    icon: Icons.air_rounded,
                    accentColor: t.gasLevel > 300 ? const Color(0xFFEF4444) : const Color(0xFFEAB308),
                    statusLabel: t.gasLevel > 300 ? "HAZARDOUS" : "SAFE",
                    progressPercent: t.gasLevel / 500,
                  ),
                  TelemetryCard(
                    title: "Humidity",
                    value: t.humidity.toStringAsFixed(1),
                    unit: "% RH",
                    icon: Icons.cloud_outlined,
                    accentColor: const Color(0xFF38BDF8),
                    statusLabel: t.humidity > 70 ? "HIGH" : "NORMAL",
                    progressPercent: t.humidity / 100,
                  ),
                  TelemetryCard(
                    title: "Battery Level",
                    value: "${t.battery}",
                    unit: "%",
                    icon: Icons.battery_charging_full_rounded,
                    accentColor: t.battery < 20 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    statusLabel: t.battery < 20 ? "LOW" : "NOMINAL",
                    progressPercent: t.battery / 100,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Posture & Kinetic Safety Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "KINETIC POSTURE & FALL ANALYSIS",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatusTile(
                          icon: Icons.directions_walk_rounded,
                          label: "Motion State",
                          value: t.motionStatus,
                          color: const Color(0xFF06B6D4),
                        ),
                        _buildStatusTile(
                          icon: Icons.personal_injury_rounded,
                          label: "Fall Detection",
                          value: t.fallDetected ? "FALL CONFIRMED" : "CLEAR",
                          color: t.fallDetected ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                        ),
                        _buildStatusTile(
                          icon: Icons.sos_rounded,
                          label: "SOS Switch",
                          value: t.sos ? "TRIGGERED" : "OFF",
                          color: t.sos ? const Color(0xFFDC2626) : const Color(0xFF10B981),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withAlpha(38),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }
}
