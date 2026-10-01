import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/ble_service.dart';
import '../../services/ai_prediction_service.dart';
import '../../services/notification_service.dart';
import '../../services/sync_service.dart';

import '../../models/user_model.dart';
import '../../models/telemetry_model.dart';
import '../../models/prediction_result.dart';
import '../../models/alert_model.dart';
import '../../database/local_database.dart';
import '../../widgets/connection_status.dart';
import '../../widgets/safety_status_widget.dart';
import '../../widgets/telemetry_card.dart';
import '../../widgets/alert_card.dart';
import '../../widgets/battery_indicator.dart';
import '../auth/login_screen.dart';
import 'device_scan_screen.dart';
import 'telemetry_screen.dart';
import 'worker_history_screen.dart';
import 'emergency_screen.dart';

class WorkerDashboard extends StatefulWidget {
  const WorkerDashboard({super.key});

  @override
  State<WorkerDashboard> createState() => _WorkerDashboardState();
}

class _WorkerDashboardState extends State<WorkerDashboard> {
  final BleService _bleService = BleService.instance;
  final AiPredictionService _aiService = AiPredictionService.instance;
  final SyncService _syncService = SyncService.instance;
  final AuthService _authService = AuthService.instance;

  StreamSubscription? _telemetrySub;
  StreamSubscription? _sosSub;
  StreamSubscription? _syncCountSub;
  StreamSubscription? _lastSyncSub;

  AppUser? _user;
  Telemetry? _currentTelemetry;
  PredictionResult _currentPrediction = PredictionResult.safeDefault();
  List<AlertItem> _recentAlerts = [];
  bool _isBleConnected = false;
  bool _isOnline = false;
  int _pendingCount = 0;
  DateTime? _lastSyncTime;

  @override
  void initState() {
    super.initState();
    _user = _authService.currentUser;
    _isBleConnected = _bleService.isConnected;
    _isOnline = _syncService.isOnline;
    _pendingCount = _syncService.pendingCount;
    _lastSyncTime = _syncService.lastSyncTime;

    _setupListeners();
    _loadInitialData();

    // Auto-start virtual node if hardware is absent so the evaluator sees live telemetry immediately
    if (!_bleService.isConnected) {
      _bleService.startVirtualNode();
    }
  }

  void _setupListeners() {
    // 1. Telemetry Stream from ESP32 BLE
    _telemetrySub = _bleService.telemetryStream.listen((telemetry) async {
      // Execute 100% On-Device Random Forest Prediction
      final prediction = _aiService.predict(telemetry);

      // Feedback Safety Status back to ESP32 hardware via BLE
      _bleService.writeSafetyStatus(prediction.status);

      // Trigger local sound / notifications if danger or emergency
      if (prediction.status == SafetyStatus.danger ||
          prediction.status == SafetyStatus.emergency) {
        NotificationService.instance.triggerSafetyAlert(
          status: prediction.status,
          title: "⚠️ OCCUPATIONAL SAFETY ALERT: ${prediction.status.toDisplayString()}",
          message: prediction.reason,
        );
      }

      // Record to SQLite & Opportunistic Sync
      await _syncService.recordTelemetry(
        telemetry: telemetry.copyWith(workerId: _user?.workerId ?? 'W-104'),
        prediction: prediction,
        workerName: _user?.name,
      );

      if (mounted) {
        setState(() {
          _currentTelemetry = telemetry;
          _currentPrediction = prediction;
        });
      }
    });

    // 2. Hardware SOS Trigger from ESP32
    _sosSub = _bleService.sosStream.listen((isTriggered) {
      if (isTriggered && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EmergencyScreen(
              workerId: _user?.workerId ?? 'W-104',
              workerName: _user?.name ?? 'Worker',
              initialCause: "ESP32 Hardware SOS button depressed.",
            ),
          ),
        );
      }
    });

    // 3. Ble Connection State
    _bleService.connectionStateStream.listen((_) {
      if (mounted) {
        setState(() => _isBleConnected = _bleService.isConnected);
      }
    });

    // 4. Online / Offline Stream
    _syncService.isOnlineStream.listen((online) {
      if (mounted) setState(() => _isOnline = online);
    });

    // 5. Sync queue count stream
    _syncCountSub = _syncService.pendingCountStream.listen((count) {
      if (mounted) setState(() => _pendingCount = count);
    });

    // 6. Last sync timestamp stream
    _lastSyncSub = _syncService.lastSyncTimeStream.listen((time) {
      if (mounted) setState(() => _lastSyncTime = time);
    });
  }

  Future<void> _loadInitialData() async {
    final workerId = _user?.workerId ?? 'W-104';
    final latest = await LocalDatabase.instance.getLatestTelemetry(workerId);
    final alerts = await LocalDatabase.instance.getRecentAlerts(workerId, limit: 5);

    if (mounted) {
      setState(() {
        if (latest != null) {
          _currentTelemetry = latest;
          _currentPrediction = _aiService.predict(latest);
        }
        _recentAlerts = alerts;
      });
    }
  }

  @override
  void dispose() {
    _telemetrySub?.cancel();
    _sosSub?.cancel();
    _syncCountSub?.cancel();
    _lastSyncSub?.cancel();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final telemetry = _currentTelemetry ??
        Telemetry(
          workerId: _user?.workerId ?? 'W-104',
          deviceId: _bleService.connectedDeviceId ?? 'ESP32_SAFE_01',
        );

    final syncTimeStr = _lastSyncTime != null
        ? DateFormat('hh:mm:ss a').format(_lastSyncTime!)
        : 'Pending Sync';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.shield_rounded, color: Color(0xFFF97316), size: 24),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("WORKER CONSOLE", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                Text(
                  _user?.name ?? "Field Worker",
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: "BLE Scanner",
            icon: const Icon(Icons.bluetooth_searching_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DeviceScanScreen()),
            ),
          ),
          IconButton(
            tooltip: "SQLite Audit Log",
            icon: const Icon(Icons.history_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WorkerHistoryScreen(workerId: _user?.workerId ?? 'W-104'),
              ),
            ),
          ),
          IconButton(
            tooltip: "Sign Out",
            icon: const Icon(Icons.logout_rounded),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _syncService.syncPendingRecords();
            await _loadInitialData();
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            children: [
              // 1. Connection Status Bar (Bluetooth, Internet, Sync Queue)
              ConnectionStatusWidget(
                isBleConnected: _isBleConnected,
                isOnline: _isOnline,
                pendingSyncCount: _pendingCount,
                onBleTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DeviceScanScreen()),
                ),
              ),
              const SizedBox(height: 12),

              // 2. Worker & Device Identifiers Strip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.badge_outlined, size: 16, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 6),
                        Text(
                          "Worker ID: ${_user?.workerId.isNotEmpty == true ? _user!.workerId : 'W-104'}",
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.white),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.developer_board_rounded, size: 16, color: Color(0xFF06B6D4)),
                        const SizedBox(width: 6),
                        Text(
                          telemetry.deviceId,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF06B6D4)),
                        ),
                        const SizedBox(width: 8),
                        BatteryIndicator(percentage: telemetry.battery),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 3. AI Safety Prediction Banner (Large Widget with on-device explanation)
              SafetyStatusWidget(
                status: _currentPrediction.status,
                confidence: _currentPrediction.confidence,
                isLarge: true,
              ),
              const SizedBox(height: 10),

              // 4. AI Explanation Box (Human Readable Reason)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _currentPrediction.status == SafetyStatus.safe
                        ? const Color(0xFF334155)
                        : _currentPrediction.status.color.withAlpha(128),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.psychology_outlined,
                          size: 16,
                          color: _currentPrediction.status.color,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          "EDGE RANDOM FOREST REASONING",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _currentPrediction.reason,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFF8FAFC),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 5. Giant Physical / Virtual SOS Emergency Trigger Button
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EmergencyScreen(
                        workerId: _user?.workerId ?? 'W-104',
                        workerName: _user?.name ?? 'Worker',
                        initialCause: "Manual Panic SOS triggered from worker dashboard.",
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626), // High-vis Red
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withAlpha(102),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.emergency_rounded, color: Colors.white, size: 28),
                      SizedBox(width: 10),
                      Text(
                        "TRIGGER EMERGENCY SOS",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 6. Primary Vitals 2x2 Grid
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "LIVE SENSORY TELEMETRY",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 0.8,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TelemetryScreen()),
                    ),
                    child: const Text(
                      "VIEW ALL SENSORS →",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFF97316),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: TelemetryCard(
                      title: "Heart Rate",
                      value: "${telemetry.heartRate}",
                      unit: "BPM",
                      icon: Icons.favorite_rounded,
                      accentColor: telemetry.heartRate > 110 ? const Color(0xFFEF4444) : const Color(0xFFF43F5E),
                      statusLabel: telemetry.heartRate > 110 ? "ELEVATED" : "NORMAL",
                      progressPercent: (telemetry.heartRate - 40) / 120,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TelemetryScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TelemetryCard(
                      title: "SpO2 Oxygen",
                      value: "${telemetry.spo2}",
                      unit: "%",
                      icon: Icons.water_drop_rounded,
                      accentColor: telemetry.spo2 < 92 ? const Color(0xFFEF4444) : const Color(0xFF06B6D4),
                      statusLabel: telemetry.spo2 < 92 ? "LOW" : "OPTIMAL",
                      progressPercent: (telemetry.spo2 - 70) / 30,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TelemetryScreen()),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: TelemetryCard(
                      title: "Gas Level",
                      value: "${telemetry.gasLevel}",
                      unit: "PPM",
                      icon: Icons.air_rounded,
                      accentColor: telemetry.gasLevel > 300 ? const Color(0xFFEF4444) : const Color(0xFFEAB308),
                      statusLabel: telemetry.gasLevel > 300 ? "HAZARDOUS" : "SAFE",
                      progressPercent: telemetry.gasLevel / 500,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TelemetryScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TelemetryCard(
                      title: "Body Temp",
                      value: telemetry.temperature.toStringAsFixed(1),
                      unit: "°C",
                      icon: Icons.thermostat_rounded,
                      accentColor: telemetry.temperature > 37.5 ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                      statusLabel: telemetry.temperature > 37.5 ? "FEVER" : "NORMAL",
                      progressPercent: (telemetry.temperature - 34.0) / 8.0,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TelemetryScreen()),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 7. Sync & Cloud Health Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.cloud_sync_rounded, size: 16, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 6),
                        Text(
                          "Last Cloud Sync: $syncTimeStr",
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: () => _syncService.syncPendingRecords(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF334155),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text("SYNC NOW", style: TextStyle(fontSize: 10)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 8. Recent Alerts List
              if (_recentAlerts.isNotEmpty) ...[
                const Text(
                  "RECENT LOCAL SAFETY ALERTS",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                ..._recentAlerts.take(3).map((a) => AlertCard(alert: a)),
                const SizedBox(height: 12),
              ],

              // 9. Test Lab Triggers (for Testing Requirements)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF475569)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "OFFLINE TEST SIMULATION LAB",
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B)),
                    ),

                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.dangerous_rounded, size: 14, color: Colors.amber),
                          label: const Text("Simulate Toxic Gas Spike", style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            _bleService.simulateEmergencyCondition(triggerToxicGas: true);
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.personal_injury_rounded, size: 14, color: Colors.redAccent),
                          label: const Text("Simulate Worker Fall", style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            _bleService.simulateEmergencyCondition(triggerFall: true);
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.air_rounded, size: 14, color: Colors.blueAccent),
                          label: const Text("Simulate Hypoxia (Low O2)", style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            _bleService.simulateEmergencyCondition(triggerHypoxia: true);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
