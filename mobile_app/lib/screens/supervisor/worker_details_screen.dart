import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../repositories/supervisor_repository.dart';
import '../../models/telemetry_model.dart';
import '../../models/prediction_result.dart';
import '../../widgets/safety_status_widget.dart';
import '../../widgets/telemetry_card.dart';
import '../../widgets/battery_indicator.dart';

class WorkerDetailsScreen extends StatelessWidget {
  final FleetWorker worker;

  const WorkerDetailsScreen({super.key, required this.worker});

  @override
  Widget build(BuildContext context) {
    final status = SafetyStatus.fromString(worker.status);
    final timeStr = DateFormat('MMM d, hh:mm:ss a').format(
      DateTime.fromMillisecondsSinceEpoch(worker.lastUpdated),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(worker.name),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(child: SafetyStatusWidget(status: status)),
          ),
        ],
      ),
      body: StreamBuilder<Telemetry?>(
        stream: SupervisorRepository.instance.getWorkerTelemetryStream(worker.workerId),
        builder: (context, snapshot) {
          final t = snapshot.data ??
              Telemetry(
                workerId: worker.workerId,
                deviceId: worker.deviceId,
                latitude: worker.latitude,
                longitude: worker.longitude,
                battery: worker.battery,
                aiStatus: worker.status,
              );

          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              // Identification Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              worker.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Worker ID: ${worker.workerId}  •  Device: ${worker.deviceId}",
                              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                        BatteryIndicator(percentage: t.battery),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFF334155), height: 1),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFF06B6D4)),
                            const SizedBox(width: 4),
                            Text(
                              "GPS: ${t.latitude.toStringAsFixed(4)}, ${t.longitude.toStringAsFixed(4)}",
                              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                        Text(
                          "Last Broadcast: $timeStr",
                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Live Telemetry Grid
              const Text(
                "FIELD SENSOR TELEMETRY STREAM",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),

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
                    title: "Gas Concentration",
                    value: "${t.gasLevel}",
                    unit: "PPM",
                    icon: Icons.air_rounded,
                    accentColor: t.gasLevel > 300 ? const Color(0xFFEF4444) : const Color(0xFFEAB308),
                    statusLabel: t.gasLevel > 300 ? "HAZARDOUS" : "NORMAL",
                    progressPercent: t.gasLevel / 500,
                  ),
                  TelemetryCard(
                    title: "Body Temp",
                    value: t.temperature.toStringAsFixed(1),
                    unit: "°C",
                    icon: Icons.thermostat_rounded,
                    accentColor: t.temperature > 37.5 ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                    statusLabel: t.temperature > 37.5 ? "FEVER" : "NORMAL",
                    progressPercent: (t.temperature - 34.0) / 8.0,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Motion & Fall Detection
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Icon(Icons.directions_walk_rounded, color: Color(0xFF06B6D4), size: 24),
                        const SizedBox(height: 4),
                        Text(
                          t.motionStatus,
                          style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 13),
                        ),
                        const Text("Motion", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                      ],
                    ),
                    Column(
                      children: [
                        Icon(
                          Icons.personal_injury_rounded,
                          color: t.fallDetected ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t.fallDetected ? "FALL REPORTED" : "CLEAR",
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: t.fallDetected ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                            fontSize: 13,
                          ),
                        ),
                        const Text("Fall Sensor", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                      ],
                    ),
                    Column(
                      children: [
                        Icon(
                          Icons.sos_rounded,
                          color: t.sos ? const Color(0xFFDC2626) : const Color(0xFF10B981),
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t.sos ? "ACTIVE" : "OFF",
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: t.sos ? const Color(0xFFDC2626) : const Color(0xFF10B981),
                            fontSize: 13,
                          ),
                        ),
                        const Text("SOS Switch", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
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
}
