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
          final t = snapshot.data;
          final hasData = t != null;
          final deviceId = BleService.instance.connectedDeviceId ?? (hasData ? t.deviceId : 'ESP32_NOT_CONNECTED');

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // Device Info Header Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF172138), Color(0xFF0E1526)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF243350), width: 1.2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "HARDWARE SAFETY NODE",
                          style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w800, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          deviceId,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: (hasData ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: (hasData ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withAlpha(60)),
                      ),
                      child: Row(
                        children: [
                          Icon(hasData ? Icons.speed_rounded : Icons.bluetooth_searching_rounded, color: hasData ? const Color(0xFF10B981) : const Color(0xFFF59E0B), size: 14),
                          const SizedBox(width: 4),
                          Text(hasData ? "2.0 Hz Live" : "Waiting BLE", style: TextStyle(color: hasData ? const Color(0xFF10B981) : const Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.w800)),
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
                    value: hasData && t.heartRate > 0 ? "${t.heartRate}" : (hasData ? "${t.heartRate}" : "--"),
                    unit: "BPM",
                    icon: Icons.favorite_rounded,
                    accentColor: hasData && (t.heartRate > 110 || t.heartRate < 50)
                        ? const Color(0xFFEF4444)
                        : (hasData && (t.heartRate > 100 || t.heartRate < 58)
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFFEF4444)),
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
                    value: hasData && t.spo2 > 0 ? "${t.spo2}" : (hasData ? "${t.spo2}" : "--"),
                    unit: "%",
                    icon: Icons.water_drop_rounded,
                    accentColor: hasData && t.spo2 < 90
                        ? const Color(0xFFEF4444)
                        : (hasData && t.spo2 < 95
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF06B6D4)),
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
                    value: hasData && t.temperature > 0 ? t.temperature.toStringAsFixed(1) : "--",
                    unit: "°C",
                    icon: Icons.thermostat_rounded,
                    accentColor: hasData && t.temperature > 37.5 ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                    statusLabel: hasData ? (t.temperature > 0 ? (t.temperature > 37.5 ? "HIGH HEAT" : "REAL DHT") : "NO SENSOR") : "WAITING",
                    progressPercent: hasData && t.temperature > 0 ? ((t.temperature - 15.0) / 30.0).clamp(0.0, 1.0) : 0.0,
                  ),
                  TelemetryCard(
                    title: "Toxic Gas PPM",
                    value: hasData ? "${t.gasLevel}" : "--",
                    unit: "PPM",
                    icon: Icons.air_rounded,
                    accentColor: hasData && t.gasLevel > 300
                        ? const Color(0xFFEF4444)
                        : (hasData && t.gasLevel > 180
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF10B981)),
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
                    value: hasData && t.humidity > 0 ? t.humidity.toStringAsFixed(1) : "--",
                    unit: "% RH",
                    icon: Icons.cloud_outlined,
                    accentColor: const Color(0xFF38BDF8),
                    statusLabel: hasData ? (t.humidity > 0 ? (t.humidity > 70 ? "HIGH" : "REAL DHT") : "NO SENSOR") : "WAITING",
                    progressPercent: hasData && t.humidity > 0 ? (t.humidity / 100).clamp(0.0, 1.0) : 0.0,
                  ),
                  TelemetryCard(
                    title: "Battery Level",
                    value: hasData ? "${t.battery}" : "--",
                    unit: "%",
                    icon: Icons.battery_charging_full_rounded,
                    accentColor: hasData && t.battery < 20 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    statusLabel: hasData ? (t.battery < 20 ? "LOW" : "ACTIVE") : "WAITING",
                    progressPercent: hasData ? (t.battery / 100).clamp(0.0, 1.0) : 0.0,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Posture & Kinetic Safety Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF172138), Color(0xFF0E1526)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF243350), width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "KINETIC POSTURE & FALL ANALYSIS",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatusTile(
                          icon: Icons.directions_walk_rounded,
                          label: "Motion State",
                          value: hasData ? t.motionStatus : "WAITING",
                          color: const Color(0xFF38BDF8),
                        ),
                        Container(width: 1, height: 36, color: const Color(0xFF243350)),
                        _buildStatusTile(
                          icon: Icons.personal_injury_rounded,
                          label: "Fall Detection",
                          value: hasData ? (t.fallDetected ? "FALL CONFIRMED" : "CLEAR") : "--",
                          color: hasData && t.fallDetected ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                        ),
                        Container(width: 1, height: 36, color: const Color(0xFF243350)),
                        _buildStatusTile(
                          icon: Icons.sos_rounded,
                          label: "SOS Switch",
                          value: hasData ? (t.sos ? "TRIGGERED" : "OFF") : "--",
                          color: hasData && t.sos ? const Color(0xFFF43F5E) : const Color(0xFF10B981),
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
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            shape: BoxShape.circle,
            border: Border.all(color: color.withAlpha(60), width: 1),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 0.2,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
