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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            children: [
              // Identification Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF172138), Color(0xFF0E1526)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF243350), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(50),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                worker.name,
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                "ID: ${worker.workerId}  •  Node: ${worker.deviceId}",
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF94A3B8),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        BatteryIndicator(percentage: t.battery),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFF243350), height: 1),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFF38BDF8)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            "GPS: ${t.latitude.toStringAsFixed(4)}, ${t.longitude.toStringAsFixed(4)}",
                            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          timeStr,
                          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Live Telemetry Grid Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "REAL-TIME SENSOR TELEMETRY",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 0.8,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withAlpha(25),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF10B981).withAlpha(60)),
                    ),
                    child: const Text(
                      "LIVE 2Hz",
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF10B981)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

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
                    accentColor: t.spo2 < 92 ? const Color(0xFFEF4444) : const Color(0xFF38BDF8),
                    statusLabel: t.spo2 < 92 ? "LOW O2" : "OPTIMAL",
                    progressPercent: (t.spo2 - 70) / 30,
                  ),
                  TelemetryCard(
                    title: "Gas Level",
                    value: "${t.gasLevel}",
                    unit: "PPM",
                    icon: Icons.air_rounded,
                    accentColor: t.gasLevel > 300 ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                    statusLabel: t.gasLevel > 300 ? "HAZARDOUS" : "SAFE",
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildKineticTile(
                      icon: Icons.directions_walk_rounded,
                      label: "Motion",
                      value: t.motionStatus,
                      color: const Color(0xFF38BDF8),
                    ),
                    Container(width: 1, height: 36, color: const Color(0xFF243350)),
                    _buildKineticTile(
                      icon: Icons.personal_injury_rounded,
                      label: "Fall Sensor",
                      value: t.fallDetected ? "DETECTED" : "CLEAR",
                      color: t.fallDetected ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    ),
                    Container(width: 1, height: 36, color: const Color(0xFF243350)),
                    _buildKineticTile(
                      icon: Icons.sos_rounded,
                      label: "SOS Panic",
                      value: t.sos ? "ACTIVE" : "OFF",
                      color: t.sos ? const Color(0xFFF43F5E) : const Color(0xFF10B981),
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

  Widget _buildKineticTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            shape: BoxShape.circle,
            border: Border.all(color: color.withAlpha(60), width: 1),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: color,
            fontSize: 11,
            letterSpacing: 0.3,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
