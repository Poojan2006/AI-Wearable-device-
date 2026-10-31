import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../repositories/supervisor_repository.dart';
import '../../models/telemetry_model.dart';
import '../../models/prediction_result.dart';
import '../../widgets/safety_status_widget.dart';
import '../../widgets/telemetry_card.dart';
import '../../widgets/battery_indicator.dart';
import '../../widgets/trend_chart.dart';
import '../../core/theme/app_theme.dart';
import '../../database/local_database.dart';

class WorkerDetailsScreen extends StatefulWidget {
  final FleetWorker worker;

  const WorkerDetailsScreen({super.key, required this.worker});

  @override
  State<WorkerDetailsScreen> createState() => _WorkerDetailsScreenState();
}

class _WorkerDetailsScreenState extends State<WorkerDetailsScreen> {
  List<Telemetry> _workerHistory = [];

  @override
  void initState() {
    super.initState();
    _loadWorkerHistory();
  }

  Future<void> _loadWorkerHistory() async {
    try {
      final records = await LocalDatabase.instance.getTelemetryHistory(
        widget.worker.workerId,
        limit: 20,
      );
      if (mounted) setState(() => _workerHistory = records);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final status = SafetyStatus.fromString(widget.worker.status);
    final timeStr = DateFormat('MMM d, hh:mm:ss a')
        .format(DateTime.fromMillisecondsSinceEpoch(widget.worker.lastUpdated));

    final isDark = AppTheme.isDark(context);
    final cardBg = AppTheme.cardBg(context);
    final borderColor = AppTheme.border(context);
    final textPrimary = AppTheme.textPrimary(context);
    final textSub = AppTheme.textSub(context);

    final hrPoints = _workerHistory
        .where((t) => t.heartRate > 0)
        .map((t) => t.heartRate.toDouble())
        .toList()
        .reversed
        .toList();

    final tempPoints = _workerHistory
        .where((t) => t.temperature > 0)
        .map((t) => t.temperature)
        .toList()
        .reversed
        .toList();

    final gasPoints = _workerHistory
        .where((t) => t.gasLevel > 0)
        .map((t) => t.gasLevel.toDouble())
        .toList()
        .reversed
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
      appBar: AppBar(
        title: Text(widget.worker.name),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(child: SafetyStatusWidget(status: status)),
          ),
        ],
      ),
      body: StreamBuilder<Telemetry?>(
        stream: SupervisorRepository.instance.getWorkerTelemetryStream(
          widget.worker.workerId,
        ),
        builder: (context, snapshot) {
          final t =
              snapshot.data ??
              Telemetry(
                workerId: widget.worker.workerId,
                deviceId: widget.worker.deviceId,
                latitude: widget.worker.latitude,
                longitude: widget.worker.longitude,
                battery: widget.worker.battery,
                aiStatus: widget.worker.status,
              );

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // Identification Banner
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
                        blurRadius: 10,
                        offset: const Offset(0, 2),
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
                                widget.worker.name,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                "ID: ${widget.worker.workerId}  •  Node: ${widget.worker.deviceId}",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: textSub,
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
                    Divider(color: borderColor, height: 1),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 14,
                          color: AppTheme.infoBlue,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            "GPS: ${t.latitude.toStringAsFixed(4)}, ${t.longitude.toStringAsFixed(4)}",
                            style: TextStyle(
                              fontSize: 11,
                              color: textSub,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: textSub,
                            fontWeight: FontWeight.w500,
                          ),
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
                  Text(
                    "REAL-TIME SENSOR TELEMETRY",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: textSub,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.safeGreen.withAlpha(isDark ? 30 : 20),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      "LIVE 2Hz",
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.safeGreen,
                      ),
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
                    accentColor: const Color(0xFFE11D48),
                    statusLabel: t.heartRate > 100 ? "ELEVATED" : "NORMAL",
                    progressPercent: (t.heartRate - 40) / 120,
                  ),
                  TelemetryCard(
                    title: "SpO2 Oxygen",
                    value: "${t.spo2}",
                    unit: "%",
                    icon: Icons.water_drop_rounded,
                    accentColor: const Color(0xFF0284C7),
                    statusLabel: t.spo2 < 92 ? "LOW O2" : "OPTIMAL",
                    progressPercent: (t.spo2 - 70) / 30,
                  ),
                  TelemetryCard(
                    title: "Gas Level",
                    value: "${t.gasLevel}",
                    unit: "PPM",
                    icon: Icons.air_rounded,
                    accentColor: t.gasLevel > 300
                        ? AppTheme.dangerRed
                        : AppTheme.warningAmber,
                    statusLabel: t.gasLevel > 300 ? "HAZARDOUS" : "SAFE",
                    progressPercent: t.gasLevel / 500,
                  ),
                  TelemetryCard(
                    title: "Temperature",
                    value: t.temperature.toStringAsFixed(1),
                    unit: "°C",
                    icon: Icons.thermostat_rounded,
                    accentColor: t.temperature > 37.5
                        ? AppTheme.warningAmber
                        : AppTheme.safeGreen,
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
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildKineticTile(
                      icon: Icons.directions_walk_rounded,
                      label: "Motion",
                      value: t.motionStatus,
                      color: AppTheme.infoBlue,
                    ),
                    Container(width: 1, height: 36, color: borderColor),
                    _buildKineticTile(
                      icon: Icons.personal_injury_rounded,
                      label: "Fall Sensor",
                      value: t.fallDetected ? "DETECTED" : "CLEAR",
                      color: t.fallDetected
                          ? AppTheme.dangerRed
                          : AppTheme.safeGreen,
                    ),
                    Container(width: 1, height: 36, color: borderColor),
                    _buildKineticTile(
                      icon: Icons.sos_rounded,
                      label: "Hardware SOS",
                      value: t.sos ? "ACTIVE" : "OFF",
                      color: t.sos ? AppTheme.dangerRed : AppTheme.safeGreen,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Historical Trends Section
              Text(
                "HISTORICAL SENSOR TRENDS",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: textSub,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),

              TrendChartCard(
                title: "Heart Rate Trend",
                unit: "BPM",
                dataPoints: hrPoints,
                accentColor: const Color(0xFFE11D48),
                subtitle: "Sensor history from SQLite buffer",
              ),
              const SizedBox(height: 12),

              TrendChartCard(
                title: "Ambient Temperature Trend",
                unit: "°C",
                dataPoints: tempPoints,
                accentColor: AppTheme.safeGreen,
                subtitle: "DHT22 readings over time",
              ),
              const SizedBox(height: 12),

              TrendChartCard(
                title: "Toxic Gas Concentration",
                unit: "PPM",
                dataPoints: gasPoints,
                accentColor: AppTheme.warningAmber,
                subtitle: "MQ Gas telemetry over time",
              ),
              const SizedBox(height: 20),
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
    final isDark = AppTheme.isDark(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withAlpha(isDark ? 30 : 20),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: color,
            fontSize: 11.5,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: AppTheme.textSub(context),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
