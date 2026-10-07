import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/ble_service.dart';
import '../../services/ai_prediction_service.dart';
import '../../services/notification_service.dart';
import '../../services/sync_service.dart';
import '../../services/sms_service.dart';

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
  final SmsService _smsService = SmsService.instance;

  StreamSubscription? _telemetrySub;
  StreamSubscription? _sosSub;
  StreamSubscription? _syncCountSub;
  StreamSubscription? _lastSyncSub;
  StreamSubscription? _smsSub;

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
  }

  void _setupListeners() {
    // 1. Telemetry Stream from ESP32 BLE
    _telemetrySub = _bleService.telemetryStream.listen((telemetry) async {
      debugPrint("[WorkerDashboard] Live BLE packet: HR=${telemetry.heartRate}, SpO2=${telemetry.spo2}, Temp=${telemetry.temperature}, Gas=${telemetry.gasLevel}");

      if (_currentTelemetry == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ Live BLE telemetry streaming from ${telemetry.deviceId}"),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Execute 100% On-Device Random Forest Prediction
      final prediction = _aiService.predict(telemetry);

      // Feedback Safety Status back to ESP32 hardware via BLE
      _bleService.writeSafetyStatus(prediction.status);

      // Trigger local sound / notifications and automatic distress SMS if danger, fall or emergency
      if (prediction.status == SafetyStatus.danger ||
          prediction.status == SafetyStatus.emergency ||
          telemetry.fallDetected ||
          telemetry.sos) {
        NotificationService.instance.triggerSafetyAlert(
          status: prediction.status,
          title: "⚠️ OCCUPATIONAL SAFETY ALERT: ${prediction.status.toDisplayString()}",
          message: prediction.reason,
        );

        // Automatic cellular SMS to registered supervisor
        _smsService.sendDistressSms(
          workerId: _user?.workerId ?? 'W-104',
          workerName: _user?.name ?? 'Worker',
          condition: telemetry.sos
              ? "EMERGENCY SOS BUTTON ACTIVATED"
              : telemetry.fallDetected
                  ? "WORKER FALL DETECTED (ACCELEROMETER SPIKE)"
                  : prediction.reason,
          telemetry: telemetry,
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
          _isBleConnected = true;
        });
      }
    });

    _bleService.connectionStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isBleConnected = state == BluetoothConnectionState.connected;
          if (!_isBleConnected) {
            _currentTelemetry = null;
          }
        });
      }
    });

    // 2. Hardware SOS Trigger from ESP32
    _sosSub = _bleService.sosStream.listen((isTriggered) {
      if (isTriggered && mounted) {
        _smsService.sendDistressSms(
          workerId: _user?.workerId ?? 'W-104',
          workerName: _user?.name ?? 'Worker',
          condition: "ESP32 Hardware SOS button depressed",
          telemetry: _currentTelemetry,
          force: true,
        );

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

    // 7. SMS dispatch result stream notification
    _smsSub = _smsService.dispatchStream.listen((result) {
      if (mounted && result.success && result.mode != 'SKIPPED_COOLDOWN') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("🚨 Distress SMS sent to Supervisor (${result.recipient})"),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });
  }

  Future<void> _loadInitialData() async {
    final workerId = _user?.workerId ?? 'W-104';
    final alerts = await LocalDatabase.instance.getRecentAlerts(workerId, limit: 5);

    if (mounted) {
      setState(() {
        _recentAlerts = alerts;
        // Telemetry strictly comes from live ESP32 BLE stream, zero past/cached data
      });
    }
  }

  @override
  void dispose() {
    _telemetrySub?.cancel();
    _sosSub?.cancel();
    _syncCountSub?.cancel();
    _lastSyncSub?.cancel();
    _smsSub?.cancel();
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
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withAlpha(24),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF10B981).withAlpha(60)),
              ),
              child: const Icon(Icons.shield_rounded, color: Color(0xFF10B981), size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("SAFEGUARD", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.6), overflow: TextOverflow.ellipsis),
                  Text(
                    "${_user?.workerId ?? 'W-104'} • ${_user?.name ?? 'Worker'}",
                    style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: "BLE Scanner",
            icon: const Icon(Icons.bluetooth_searching_rounded, size: 20),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DeviceScanScreen()),
            ),
          ),
          IconButton(
            tooltip: "SQLite Audit Log",
            icon: const Icon(Icons.history_rounded, size: 20),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WorkerHistoryScreen(workerId: _user?.workerId ?? 'W-104'),
              ),
            ),
          ),
          IconButton(
            tooltip: "Sign Out",
            icon: const Icon(Icons.logout_rounded, size: 20),
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
              const SizedBox(height: 10),

              // 2. Worker & Device Identifiers Strip
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DeviceScanScreen()),
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131D33),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isBleConnected
                            ? const Color(0xFF10B981).withAlpha(120)
                            : const Color(0xFFF59E0B).withAlpha(120),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 4),
                            Text(
                              _user?.workerId.isNotEmpty == true ? _user!.workerId : 'W-104',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.white),
                            ),
                          ],
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                _isBleConnected ? Icons.bluetooth_connected_rounded : Icons.bluetooth_searching_rounded,
                                size: 13,
                                color: _isBleConnected ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  _isBleConnected
                                      ? (_bleService.connectedDeviceId ?? "ESP32_SAFE_01")
                                      : "NO ESP32 CONNECTED • TAP TO SCAN",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10.5,
                                    color: _isBleConnected ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_isBleConnected && _currentTelemetry != null) ...[
                          const SizedBox(width: 6),
                          BatteryIndicator(percentage: _currentTelemetry!.battery),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              // 2b. Registered Supervisor Emergency Contact Strip
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _showEditSupervisorPhoneDialog,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131D33),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF243350), width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.phone_forwarded_rounded, size: 14, color: Color(0xFF10B981)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            "Supervisor SMS: ${_smsService.supervisorPhone}",
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withAlpha(30),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF6366F1).withAlpha(80)),
                          ),
                          child: const Text(
                            "CONFIG",
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF818CF8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // 3. AI Safety Prediction Banner (Large Widget with on-device explanation)
              SafetyStatusWidget(
                status: _currentPrediction.status,
                confidence: _currentPrediction.confidence,
                isLarge: true,
              ),
              const SizedBox(height: 10),

              // 4. AI Explanation Box (Human Readable Reason)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D131F),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _currentPrediction.status == SafetyStatus.safe
                        ? const Color(0xFF1E2B3E)
                        : _currentPrediction.status.color.withAlpha(100),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: 14,
                          color: _currentPrediction.status.color,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          "ON-DEVICE INFERENCE ENGINE",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: Color(0xFF8B98AD),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _currentTelemetry == null
                          ? "Waiting for live BLE telemetry stream from ESP32..."
                          : _currentPrediction.reason,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFCBD5E1),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

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
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF385C), Color(0xFFDC143C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFF6B81).withAlpha(120), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF385C).withAlpha(90),
                        blurRadius: 18,
                        spreadRadius: -2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sos_rounded, color: Colors.white, size: 24),
                      SizedBox(width: 8),
                      Text(
                        "TRIGGER EMERGENCY SOS",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // 5b. Hardware Buzzer Diagnostic Test Button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    if (!_isBleConnected) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("⚠️ ESP32 is not connected! Tap connection strip to connect first."),
                          backgroundColor: Color(0xFFF59E0B),
                        ),
                      );
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("🔊 Triggering ESP32 buzzer test on GPIO 18..."),
                        backgroundColor: Color(0xFF6366F1),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    await _bleService.testBuzzer();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF475569), width: 1),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.volume_up_rounded, color: Color(0xFF38BDF8), size: 18),
                        SizedBox(width: 8),
                        Text(
                          "TEST ESP32 BUZZER (GPIO 18)",
                          style: TextStyle(
                            color: Color(0xFFF1F5F9),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 6. Primary Vitals 2x2 Grid
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "LIVE SENSORY TELEMETRY",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF8B98AD),
                      letterSpacing: 0.8,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TelemetryScreen()),
                    ),
                    child: const Text(
                      "ALL SENSORS →",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF38BDF8),
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
                      title: "Temperature (DHT)",
                      value: (_currentTelemetry != null && telemetry.temperature > 0)
                          ? telemetry.temperature.toStringAsFixed(1)
                          : "--",
                      unit: "°C",
                      icon: Icons.thermostat_rounded,
                      accentColor: (_currentTelemetry != null && telemetry.temperature > 37.5)
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF10B981),
                      statusLabel: (_currentTelemetry != null && telemetry.temperature > 0)
                          ? (telemetry.temperature > 37.5 ? "HIGH HEAT" : "REAL DHT")
                          : "WAITING",
                      progressPercent: (_currentTelemetry != null && telemetry.temperature > 0)
                          ? ((telemetry.temperature - 15.0) / 30.0).clamp(0.0, 1.0)
                          : 0.0,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TelemetryScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TelemetryCard(
                      title: "Humidity (DHT)",
                      value: (_currentTelemetry != null && telemetry.humidity > 0)
                          ? telemetry.humidity.toStringAsFixed(1)
                          : "--",
                      unit: "% RH",
                      icon: Icons.water_drop_rounded,
                      accentColor: const Color(0xFF06B6D4),
                      statusLabel: (_currentTelemetry != null && telemetry.humidity > 0)
                          ? (telemetry.humidity > 75 ? "HUMID" : "REAL DHT")
                          : "WAITING",
                      progressPercent: (_currentTelemetry != null && telemetry.humidity > 0)
                          ? (telemetry.humidity / 100.0).clamp(0.0, 1.0)
                          : 0.0,
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
                      title: "Kinetic Motion (MPU)",
                      value: _currentTelemetry != null ? telemetry.motionStatus : "--",
                      unit: _currentTelemetry != null ? "${telemetry.totalG.toStringAsFixed(2)}G" : "",
                      icon: Icons.directions_walk_rounded,
                      accentColor: _currentTelemetry != null && telemetry.fallDetected
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF38BDF8),
                      statusLabel: _currentTelemetry != null
                          ? (telemetry.fallDetected ? "FALL SHOCK" : "REAL MPU6050")
                          : "WAITING",
                      progressPercent: _currentTelemetry != null ? (telemetry.totalG / 3.0).clamp(0.0, 1.0) : 0.0,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TelemetryScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TelemetryCard(
                      title: "Heart Rate",
                      value: (_currentTelemetry != null && telemetry.heartRate > 0)
                          ? "${telemetry.heartRate}"
                          : "--",
                      unit: "BPM",
                      icon: Icons.favorite_rounded,
                      accentColor: const Color(0xFF64748B),
                      statusLabel: (_currentTelemetry != null && telemetry.heartRate > 0)
                          ? "NORMAL"
                          : (_currentTelemetry != null ? "NOT CONNECTED" : "WAITING"),
                      progressPercent: 0.0,
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D131F),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF1E2B3E)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.sync_rounded, size: 14, color: Color(0xFF8B98AD)),
                        const SizedBox(width: 6),
                        Text(
                          "Last Sync: $syncTimeStr",
                          style: const TextStyle(color: Color(0xFF8B98AD), fontSize: 11),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: () => _syncService.syncPendingRecords(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF182335),
                        foregroundColor: const Color(0xFF38BDF8),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text("SYNC NOW", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 8. Recent Alerts List
              if (_recentAlerts.isNotEmpty) ...[
                const Text(
                  "RECENT LOCAL SAFETY ALERTS",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF8B98AD),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                ..._recentAlerts.take(3).map((a) => AlertCard(alert: a)),
                const SizedBox(height: 10),
              ],

              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditSupervisorPhoneDialog() {
    final controller = TextEditingController(text: _smsService.supervisorPhone);
    bool autoSms = _smsService.autoSmsEnabled;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF10172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFF243350), width: 1.2),
          ),
          title: const Row(
            children: [
              Icon(Icons.phone_forwarded_rounded, color: Color(0xFF10B981), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Supervisor Contact",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "When distress (SOS, fall, or danger) is detected, the phone automatically transmits a distress SMS to this phone number via cellular tower (100% offline from internet).",
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(
                    labelText: "Supervisor Phone Number",
                    prefixIcon: Icon(Icons.phone_rounded, size: 18),
                    hintText: "+919876543210",
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    "Auto-SMS on Distress",
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    "Send SMS on SOS, Fall, Toxic Gas & Hypoxia",
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                  ),
                  value: autoSms,
                  activeThumbColor: const Color(0xFF10B981),
                  onChanged: (val) => setDlgState(() => autoSms = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("CANCEL", style: TextStyle(color: Color(0xFF94A3B8))),
            ),
            ElevatedButton(
              onPressed: () async {
                final phone = controller.text.trim();
                if (phone.isNotEmpty) {
                  await _smsService.setSupervisorPhone(phone);
                  await _smsService.setAutoSmsEnabled(autoSms);
                  setState(() {});
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Supervisor SMS contact set to $phone"),
                        backgroundColor: const Color(0xFF10B981),
                      ),
                    );
                  }
                }
              },
              child: const Text("SAVE NUMBER"),
            ),
          ],
        ),
      ),
    );
  }
}
